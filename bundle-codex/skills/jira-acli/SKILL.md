---
name: "jira-acli"
description: "Use when the task is Jira Cloud ticket management through Atlassian CLI: view, search, create, edit, transition, comment, or project lookup with preview-before-write safety."
---

# Jira ACLI Skill

Use Atlassian CLI as the execution layer for Jira Cloud work item operations. The agent should own intent interpretation and safety checks; this skill should own command execution, normalized output, and verification.

## When to use

- Search or view Jira Cloud work items.
- Create, edit, transition, or comment on work items.
- Resolve the default Jira project from local credentials.
- Validate that ACLI is installed and authenticated before operating.

## Credentials source

Read `/Users/ago0528/.codex/credentials.md` first. The parser expects this exact marker block:

```md
<!-- jira-acli:credentials:start -->
site=your-domain.atlassian.net
email=you@example.com
token=replace-me
projects=NMRS,HDX,JDA
default_project=NMRS
<!-- jira-acli:credentials:end -->
```

Do not place secrets in this `SKILL.md`, references, or scripts.

## Workflow

1. Run the prerequisite check:

```bash
/Users/ago0528/.codex/skills/jira-acli/scripts/ensure_acli.sh --json
```

2. For read operations, call the wrapper directly:

```bash
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh project --project "NMRS"
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh search --project "NMRS" --limit 20
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh view --key "NMRS-123"
```

3. For write operations, preview first. Do not skip this step:

```bash
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh create \
  --project "NMRS" \
  --type "Task" \
  --summary "검색 필터 초기화 동작 수정"
```

4. Only after user confirmation, rerun with `--confirm`:

```bash
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh create \
  --project "NMRS" \
  --type "Task" \
  --summary "검색 필터 초기화 동작 수정" \
  --confirm
```

5. Use the wrapper's `verify` object as the authoritative post-write state.

## Safety contract

- `create`, `edit`, `transition`, and `comment` are preview-only unless `--confirm` is present.
- Always show the preview to the user before write execution.
- If custom fields, sprint, fixVersion, epic linkage, or workflow-specific requirements are unresolved, stop at preview and ask for the missing value.
- Prefer ACLI first. If the task cannot be expressed with current ACLI commands, explicitly call out that a REST fallback is needed.

## Output contract

`jira_acli_exec.sh` returns normalized JSON with this general shape:

```json
{
  "ok": true,
  "action": "create",
  "executed": false,
  "project": "NMRS",
  "preview": {},
  "command": [],
  "result": null,
  "verify": null,
  "warnings": []
}
```

For write executions with `--confirm`, `result` contains the direct ACLI response and `verify` contains the post-write `view` response when available.

## Files

- Command patterns: `references/command-map.md`
- Dynamic project and field rules: `references/field-policy.md`
- Prerequisite checker: `scripts/ensure_acli.sh`
- Unified wrapper: `scripts/jira_acli_exec.sh`

## Notes

- `jq` is required because normalized output is assembled with JSON transforms.
- The wrapper defaults to the `default_project` in `credentials.md`, then the first project in `projects`, when no project is passed.
- Current wrapper coverage is intentionally narrow: project lookup, view, search, create, edit, transition, and comment create.
