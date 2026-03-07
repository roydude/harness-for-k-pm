# NOTICE

Korean version: [NOTICE.ko.md](NOTICE.ko.md)

This repository is a public installer bundle for non-system Codex skills.

It does not rehost upstream third-party skill folders unless a skill is explicitly vendored under `vendor/skills/`. Most skills are installed from their original GitHub repositories using pinned commit SHAs listed in `manifest/skills.yaml`.

## Upstream Sources

### OpenAI Skills

- Source repository: `openai/skills`
- Installed skills:
  - `doc`
  - `figma`
  - `figma-implement-design`
  - `openai-docs`
  - `pdf`
  - `playwright`
- Installation mode: upstream GitHub path install
- License: see upstream repository and any license files contained in the installed skill directories

### UI / UX Pro Max

- Source repository: `nextlevelbuilder/ui-ux-pro-max-skill`
- Installed skill: `ui-ux-pro-max`
- Installation mode: upstream GitHub path install
- License: see upstream repository

### PM Skills Marketplace

- Source repository: `phuryn/pm-skills`
- Installed skills: all Codex-compatible `skills/*/SKILL.md` entries listed in `manifest/skills.yaml`
- Installation mode: upstream GitHub path install
- Declared upstream license: MIT

### Vendored Local Skill

- Vendored path: `vendor/skills/korean-humanizer`
- Installed skill: `korean-humanizer`
- Installation mode: copied from this repository
- Origin: local custom skill maintained in this bundle repository

## Redistribution Notes

- This repository stores only one vendored local skill by default.
- Upstream skills remain attributable to their original repositories.
- If you add more vendored skills later, update both this file and `manifest/skills.yaml`.
