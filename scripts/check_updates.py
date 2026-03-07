#!/usr/bin/env python3
"""Check whether pinned upstream SHAs lag behind GitHub default branches."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import urllib.error
import urllib.request


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


def load_manifest(path: Path) -> list[dict[str, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    items: list[dict[str, str]] = []
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
            items.append(current)
            continue
        if current is None:
            raise ValueError(f"Property without list item on line {line_no}")
        key, value = _split_key_value(stripped, line_no)
        current[key] = _parse_scalar(value)
    return items


def _github_get(url: str) -> dict[str, object]:
    request = urllib.request.Request(url, headers={"User-Agent": "codex-skill-bundle-updater"})
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode("utf-8"))


def _default_branch_head(repo: str) -> tuple[str, str]:
    repo_meta = _github_get(f"https://api.github.com/repos/{repo}")
    branch = repo_meta["default_branch"]
    commit_meta = _github_get(f"https://api.github.com/repos/{repo}/commits/{branch}")
    return str(branch), str(commit_meta["sha"])


def main() -> int:
    manifest = load_manifest(Path(__file__).resolve().parents[1] / "manifest" / "skills.yaml")
    repos: dict[str, dict[str, object]] = {}

    for item in manifest:
        if item.get("source_type") != "github_path":
            continue
        repo = item["repo"]
        repos.setdefault(repo, {"refs": set(), "skills": []})
        repos[repo]["refs"].add(item["ref"])
        repos[repo]["skills"].append(item["name"])

    if not repos:
        print("No github_path skills found.")
        return 0

    updates_found = False
    errors = False

    for repo in sorted(repos):
        current_refs = sorted(repos[repo]["refs"])
        skills = sorted(repos[repo]["skills"])
        try:
            branch, latest_sha = _default_branch_head(repo)
        except urllib.error.URLError as exc:
            errors = True
            print(f"ERROR  {repo}: {exc}", file=sys.stderr)
            continue

        if latest_sha in current_refs:
            print(f"OK     {repo} default={branch} pinned={latest_sha} skills={', '.join(skills)}")
            continue

        updates_found = True
        print(f"UPDATE {repo}")
        print(f"  default branch: {branch}")
        print(f"  pinned refs: {', '.join(current_refs)}")
        print(f"  latest head: {latest_sha}")
        print(f"  skills: {', '.join(skills)}")

    if not updates_found and not errors:
        print("No upstream updates found.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
