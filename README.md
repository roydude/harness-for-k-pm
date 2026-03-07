# Harness for K-PM

Korean version: [README.ko.md](README.ko.md)

K-PM Agent Harness

Product managers in Korea often work with a broader scope than their counterparts in many other markets.

Beyond owning business strategy and organizational KPIs, they are often expected to write planning documents, analyze data, design screens, communicate with clients, manage schedules, handle QA, report bugs, support operational customer service, and sometimes even step into marketing.

This repository is built for those K-PMs. It provides an agent harness that product managers across very different environments, from startups to large enterprises, can adopt based on their actual workflows and needs.

The goal is simple: reduce repetitive operational load so PMs can spend more time on higher-value judgment, coordination, and problem-solving.

At the moment, this repository serves as a public installer bundle for non-system Codex skills.

This repository keeps a single manifest for reusable Codex skills and installs them into `${CODEX_HOME:-$HOME/.codex}/skills` for both Codex CLI and Codex App. Upstream skills stay in their original GitHub repositories and are pinned by commit SHA. Local-only skills are vendored under `vendor/skills/`.

## Repository Layout

- `manifest/skills.yaml`: source-of-truth for installable skills
- `scripts/install_codex_skills.py`: installer with dry-run, category, and single-skill modes
- `scripts/check_updates.py`: upstream update checker for pinned GitHub refs
- `vendor/skills/`: vendored local-only skills
- `NOTICE.md`: upstream source and licensing notes

## Quick Start

macOS and Linux use the same commands.

```bash
git clone <your-public-repo-url> harness-for-k-pm
cd harness-for-k-pm
python3 scripts/install_codex_skills.py --all
```

Install into a custom Codex home:

```bash
CODEX_HOME=/tmp/codex-home python3 scripts/install_codex_skills.py --all
```

Preview the plan without changing anything:

```bash
python3 scripts/install_codex_skills.py --all --dry-run
```

Install only one category:

```bash
python3 scripts/install_codex_skills.py --category "PM 전략"
```

Install only one skill:

```bash
python3 scripts/install_codex_skills.py --skill korean-humanizer
```

Force reinstall existing skills:

```bash
python3 scripts/install_codex_skills.py --all --force
```

## Categories

The manifest categories are aligned so they can later be reused in `AGENTS.md`.

- `기본 생산성 / 문서 / 디자인`
- `PM 데이터 분석`
- `PM 제품 탐색`
- `PM 전략`
- `PM 실행 / 기획 운영`
- `시장 조사 / GTM / 성장`
- `실무 툴킷 / 문서 보조`

## Update Workflow

Check whether upstream default branches moved ahead of the pinned SHAs:

```bash
python3 scripts/check_updates.py
```

Recommended maintenance flow:

1. Run `python3 scripts/check_updates.py`.
2. Review the upstream changes you actually want.
3. Update `manifest/skills.yaml` refs from old SHA to new SHA.
4. Re-run a test install into a temporary `CODEX_HOME`.
5. Commit the manifest change.

The installer does not auto-merge upstream updates. The manifest remains the explicit review point.

## Manifest Schema

Each entry in `manifest/skills.yaml` uses these fields:

- `name`: manifest identifier
- `category`: human-facing grouping
- `source_type`: `github_path` or `vendored`
- `repo`: `owner/repo` for upstream GitHub skills
- `ref`: pinned commit SHA
- `path`: repo-relative skill path or vendored path
- `dest_name`: destination folder under `~/.codex/skills`
- `license`: SPDX-ish label or `see upstream`
- `notes`: optional installation note

## Installation Notes

- `.system` skills are intentionally excluded.
- The installer skips existing skill directories by default.
- If Codex's built-in `install-skill-from-github.py` exists, the installer reuses it when practical.
- If that helper is not available, the installer falls back to a native zip-download implementation using Python standard library only.
