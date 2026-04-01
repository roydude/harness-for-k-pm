# Harness for K-PM

Korean version: [README.ko.md](README.ko.md)

A planner-oriented bundle for product managers who use Codex or Claude Code and want to set up agent workflows quickly.

This repository packages a practical default for PM work:

- PM-first routing rules
- explicit delegation policy
- clear separation between planning, design, implementation, review, and QA
- reusable skills for specs, research, synthesis, docs, slides, Figma, Jira, and browser tasks

This is not an installer framework. It is the bundle payload itself.

## What's Inside

### `bundle-codex/`

- `AGENTS.md`
- `agents/*.toml` for 16 roles
- `skills/*` for 26 reusable skills

### `bundle-claude/`

- `CLAUDE.md`
- `agents/*.md` for 16 roles
- `skills/*` for 27 reusable skills
- includes `refresh-planning-subagents` for Claude-side cleanup

Notable roles:
`product-manager`, `business-analyst`, `project-manager`, `ui-designer`, `api-designer`, `architect-reviewer`, `frontend-developer`, `backend-developer`, `code-reviewer`, `qa-expert`

Notable skills:
`create-prd`, `user-stories`, `summarize-meeting`, `summarize-interview`, `analyze-feature-requests`, `brainstorm-ideas-existing`, `jira-checklist`, `korean-humanizer`, `slides`, `figma`, `openai-docs`

## Quick Install

Codex CLI / Codex App:

```bash
mkdir -p ~/.codex
rsync -a bundle-codex/ ~/.codex/
```

Claude Code:

```bash
mkdir -p ~/.claude/agents
mkdir -p ~/.claude/plugins/marketplaces/ai-harness/skills
cp bundle-claude/CLAUDE.md ~/.claude/CLAUDE.md
rsync -a bundle-claude/agents/ ~/.claude/agents/
rsync -a bundle-claude/skills/ ~/.claude/plugins/marketplaces/ai-harness/skills/
```

If you already have `~/.codex/AGENTS.md` or `~/.claude/CLAUDE.md`, merge carefully instead of blindly overwriting. If you only want part of the bundle, copy only the agents or skills you need.

## Default Operating Model

- Do not spawn subagents by default.
- Use delegation only when the user explicitly asks for it.
- Prefer the smallest competent agent set.
- Keep planning, design, implementation, review, and QA logically separated.
- Avoid broad refactors unless explicitly requested.

## Customize

- Edit the global routing rules in `bundle-codex/AGENTS.md` or `bundle-claude/CLAUDE.md`.
- Adjust individual agent behavior under `bundle-*/agents/`.
- Add or remove skills under `bundle-*/skills/`.
- Keep the Codex and Claude variants aligned if you want similar behavior across both runtimes.

## Who This Is For

This bundle is aimed at planners and product managers who use agents for:

- PRDs and specs
- discovery and idea generation
- interview and meeting synthesis
- Jira and execution support
- design review and Figma handoff
- document, slide, and browser-assisted work

Treat this as a strong starting point, not a universal standard. The intended workflow is to install it fast, then trim and adapt it to the way your team actually works.
