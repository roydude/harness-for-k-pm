---
name: "jira-checklist"
description: "Use when the task is to generate an implementation, QA, or release checklist from a Jira issue, reusing jira-acli for issue retrieval."
---

# Jira Checklist Skill

Generate a checklist from a Jira issue while reusing `jira-acli` for all Jira reads. This skill should focus on checklist composition, not direct Jira API or ACLI orchestration.

## When to use

- The user wants an implementation checklist from a Jira ticket.
- The user wants a QA or release checklist tied to a Jira issue.
- The user wants a checklist drafted first, then optionally posted back to Jira as a comment.

## Workflow

1. Fetch the issue through the shared wrapper:

```bash
/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh view --key "NMRS-123"
```

2. Or generate the checklist directly:

```bash
/Users/ago0528/.codex/skills/jira-checklist/scripts/build_checklist.sh --key "NMRS-123"
```

3. Review the generated checklist with the user.

4. If the user wants the checklist posted back to Jira, use `jira-acli` preview first, then execute the comment with `--confirm`.

## Templates

Supported checklist templates:

- `implementation`
- `qa`
- `release`

## Files

- Checklist builder: `scripts/build_checklist.sh`
- Jira retrieval helper: `/Users/ago0528/.codex/skills/jira-acli/scripts/jira_acli_exec.sh`

## Rules

- Do not fetch Jira data via `curl`.
- Do not write comments directly from this skill.
- Keep checklist output concise and actionable.
