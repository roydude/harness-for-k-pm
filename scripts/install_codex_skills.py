#!/usr/bin/env python3
"""Install Codex skills from a manifest into ${CODEX_HOME}/skills."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import zipfile


@dataclass(frozen=True)
class SkillSpec:
    name: str
    category: str
    source_type: str
    repo: str | None
    ref: str
    path: str
    dest_name: str
    license: str
    notes: str = ""


@dataclass(frozen=True)
class PlannedSkill:
    spec: SkillSpec
    destination: Path


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _default_dest() -> Path:
    codex_home = os.environ.get("CODEX_HOME")
    if codex_home:
        return Path(codex_home).expanduser() / "skills"
    return Path.home() / ".codex" / "skills"


def _split_key_value(text: str, line_no: int) -> tuple[str, str]:
    if ":" not in text:
        raise ValueError(f"Invalid manifest entry on line {line_no}: {text}")
    key, value = text.split(":", 1)
    return key.strip(), value.strip()


def _parse_scalar(value: str) -> str:
    if not value:
        return ""
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value


def load_manifest(path: Path) -> list[SkillSpec]:
    lines = path.read_text(encoding="utf-8").splitlines()
    skills: list[dict[str, str]] = []
    current: dict[str, str] | None = None
    in_skills_block = False

    for line_no, raw_line in enumerate(lines, start=1):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        stripped = raw_line.strip()
        if stripped == "skills:":
            in_skills_block = True
            continue
        if not in_skills_block:
            raise ValueError(f"Unexpected content before skills block on line {line_no}")
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        if stripped.startswith("- "):
            if indent != 2:
                raise ValueError(f"Unexpected list indentation on line {line_no}")
            key, value = _split_key_value(stripped[2:], line_no)
            current = {key: _parse_scalar(value)}
            skills.append(current)
            continue
        if current is None:
            raise ValueError(f"Property without list item on line {line_no}")
        if indent < 4:
            raise ValueError(f"Unexpected indentation on line {line_no}")
        key, value = _split_key_value(stripped, line_no)
        current[key] = _parse_scalar(value)

    required = ("name", "category", "source_type", "ref", "path", "dest_name", "license")
    parsed: list[SkillSpec] = []
    for item in skills:
        missing = [field for field in required if not item.get(field)]
        if missing:
            raise ValueError(f"Manifest entry {item.get('name', '<unknown>')} missing {', '.join(missing)}")
        if item["source_type"] == "github_path" and not item.get("repo"):
            raise ValueError(f"Manifest entry {item['name']} requires repo for github_path")
        parsed.append(
            SkillSpec(
                name=item["name"],
                category=item["category"],
                source_type=item["source_type"],
                repo=item.get("repo"),
                ref=item["ref"],
                path=item["path"],
                dest_name=item["dest_name"],
                license=item["license"],
                notes=item.get("notes", ""),
            )
        )
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Install Codex skills from manifest/skills.yaml")
    parser.add_argument("--all", action="store_true", help="Install all manifest entries")
    parser.add_argument("--category", action="append", default=[], help="Install all skills from a category")
    parser.add_argument("--skill", action="append", default=[], help="Install one named skill")
    parser.add_argument("--dest", type=Path, default=_default_dest(), help="Destination skill directory root")
    parser.add_argument("--dry-run", action="store_true", help="Print install plan without changing files")
    parser.add_argument("--force", action="store_true", help="Reinstall by removing existing skill directories first")
    return parser.parse_args()


def select_skills(skills: list[SkillSpec], categories: list[str], names: list[str], select_all: bool) -> list[SkillSpec]:
    if not (select_all or categories or names):
        return skills
    chosen: list[SkillSpec] = []
    seen: set[str] = set()
    for skill in skills:
        if skill.name in seen:
            continue
        if select_all or skill.category in categories or skill.name in names:
            chosen.append(skill)
            seen.add(skill.name)
    return chosen


def _find_helper() -> Path | None:
    candidate_homes = []
    env_home = os.environ.get("CODEX_HOME")
    if env_home:
        candidate_homes.append(Path(env_home).expanduser())
    candidate_homes.append(Path.home() / ".codex")
    seen: set[Path] = set()
    for codex_home in candidate_homes:
        if codex_home in seen:
            continue
        seen.add(codex_home)
        helper = codex_home / "skills" / ".system" / "skill-installer" / "scripts" / "install-skill-from-github.py"
        if helper.is_file():
            return helper
    return None


def _remove_path(path: Path) -> None:
    if not path.exists():
        return
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def _safe_extract_zip(zip_file: zipfile.ZipFile, dest_dir: Path) -> None:
    dest_root = dest_dir.resolve()
    for member in zip_file.infolist():
        candidate = (dest_dir / member.filename).resolve()
        if candidate == dest_root or str(candidate).startswith(str(dest_root) + os.sep):
            continue
        raise RuntimeError("Archive contains files outside destination")
    zip_file.extractall(dest_dir)


def _download_repo(repo: str, ref: str, cache_root: Path) -> Path:
    owner, repo_name = repo.split("/", 1)
    slug = f"{owner}-{repo_name}-{ref}"
    target_dir = cache_root / slug
    if target_dir.exists():
        return next(target_dir.iterdir())
    target_dir.mkdir(parents=True, exist_ok=True)
    zip_path = target_dir / "repo.zip"
    url = f"https://codeload.github.com/{owner}/{repo_name}/zip/{ref}"
    request = urllib.request.Request(url, headers={"User-Agent": "codex-skill-bundle-installer"})
    try:
        with urllib.request.urlopen(request) as response:
            zip_path.write_bytes(response.read())
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Download failed for {repo}@{ref}: {exc}") from exc
    with zipfile.ZipFile(zip_path, "r") as zip_file:
        _safe_extract_zip(zip_file, target_dir)
    extracted = [path for path in target_dir.iterdir() if path.is_dir()]
    if len(extracted) != 1:
        raise RuntimeError(f"Unexpected archive layout for {repo}@{ref}")
    return extracted[0]


def _validate_skill_dir(path: Path) -> None:
    if not path.is_dir():
        raise RuntimeError(f"Skill directory not found: {path}")
    if not (path / "SKILL.md").is_file():
        raise RuntimeError(f"SKILL.md not found: {path / 'SKILL.md'}")


def _install_native_group(group: list[PlannedSkill], repo_cache_root: Path) -> None:
    if not group:
        return
    repo = group[0].spec.repo
    ref = group[0].spec.ref
    assert repo is not None
    repo_root = _download_repo(repo, ref, repo_cache_root)
    for planned in group:
        source = repo_root / planned.spec.path
        _validate_skill_dir(source)
        shutil.copytree(source, planned.destination)


def _install_native_vendored(planned: PlannedSkill) -> None:
    source = _repo_root() / planned.spec.path
    _validate_skill_dir(source)
    shutil.copytree(source, planned.destination)


def _run_helper(helper: Path, group: list[PlannedSkill], dest_root: Path) -> tuple[bool, str]:
    if not group:
        return True, ""
    command = [
        sys.executable,
        str(helper),
        "--repo",
        group[0].spec.repo or "",
        "--ref",
        group[0].spec.ref,
        "--dest",
        str(dest_root),
        "--path",
    ]
    command.extend(planned.spec.path for planned in group)
    result = subprocess.run(command, capture_output=True, text=True)
    output = "\n".join(part for part in (result.stdout.strip(), result.stderr.strip()) if part)
    return result.returncode == 0, output


def _summarize(kind: str, items: list[str]) -> None:
    print(f"{kind}: {len(items)}")
    if items:
        for item in items:
            print(f"  - {item}")


def main() -> int:
    args = parse_args()
    repo_root = _repo_root()
    manifest_path = repo_root / "manifest" / "skills.yaml"
    skills = load_manifest(manifest_path)
    selected = select_skills(skills, args.category, args.skill, args.all)
    if not selected:
        print("No skills matched the requested selectors.", file=sys.stderr)
        return 1

    args.dest.mkdir(parents=True, exist_ok=True)
    helper = _find_helper()
    planned_to_install: list[PlannedSkill] = []
    skipped: list[str] = []
    failed: list[str] = []

    for spec in selected:
        destination = args.dest / spec.dest_name
        if destination.exists() and not args.force:
            skipped.append(spec.name)
            action = "SKIP"
        else:
            if not args.dry_run and args.force:
                _remove_path(destination)
            action = "PLAN" if args.dry_run else "INSTALL"
            planned_to_install.append(PlannedSkill(spec=spec, destination=destination))
        print(f"{action:<7} {spec.name:<28} -> {destination}")

    if args.dry_run:
        _summarize("planned", [planned.spec.name for planned in planned_to_install])
        _summarize("skipped", skipped)
        _summarize("failed", failed)
        return 0

    installed: list[str] = []
    repo_cache_root = Path(tempfile.mkdtemp(prefix="codex-skill-bundle-"))

    try:
        vendored = [planned for planned in planned_to_install if planned.spec.source_type == "vendored"]
        for planned in vendored:
            try:
                _install_native_vendored(planned)
                installed.append(planned.spec.name)
            except Exception as exc:  # noqa: BLE001
                failed.append(f"{planned.spec.name}: {exc}")

        github_groups: dict[tuple[str, str], list[PlannedSkill]] = {}
        for planned in planned_to_install:
            if planned.spec.source_type != "github_path":
                continue
            key = (planned.spec.repo or "", planned.spec.ref)
            github_groups.setdefault(key, []).append(planned)

        for (_, _), group in github_groups.items():
            if helper and all(Path(item.spec.path).name == item.spec.dest_name for item in group):
                ok, output = _run_helper(helper, group, args.dest)
                if ok:
                    installed.extend(item.spec.name for item in group)
                    continue
                print(f"Helper install failed for {group[0].spec.repo}@{group[0].spec.ref}. Falling back to native installer.", file=sys.stderr)
                if output:
                    print(output, file=sys.stderr)
            try:
                _install_native_group(group, repo_cache_root)
                installed.extend(item.spec.name for item in group)
            except Exception as exc:  # noqa: BLE001
                for item in group:
                    failed.append(f"{item.spec.name}: {exc}")
    finally:
        shutil.rmtree(repo_cache_root, ignore_errors=True)

    _summarize("installed", installed)
    _summarize("skipped", skipped)
    _summarize("failed", failed)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
