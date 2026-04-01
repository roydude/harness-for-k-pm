# Jira ACLI Command Map

Confirmed against Atlassian ACLI reference pages current to April 1, 2026.

## Read actions

| Intent | ACLI command |
| --- | --- |
| View a work item | `acli jira workitem view KEY-123 --json` |
| View selected fields | `acli jira workitem view KEY-123 --json --fields "summary,description,status"` |
| Search by JQL | `acli jira workitem search --jql "project = TEAM" --limit 20 --json` |
| View a project | `acli jira project view --key "TEAM" --json` |
| Check auth status | `acli jira auth status` |

## Write actions

| Intent | ACLI command |
| --- | --- |
| Create work item | `acli jira workitem create --project "TEAM" --type "Task" --summary "New Task" --json` |
| Edit work item | `acli jira workitem edit --key "TEAM-1" --summary "Updated summary" --yes --json` |
| Transition work item | `acli jira workitem transition --key "TEAM-1" --status "In Progress" --yes --json` |
| Create comment | `acli jira workitem comment create --key "TEAM-1" --body "Planned fix" --json` |

## Authentication

| Intent | ACLI command |
| --- | --- |
| Browser login | `acli jira auth login --web` |
| Token login | `echo "$TOKEN" \| acli jira auth login --site "your-domain.atlassian.net" --email "you@example.com" --token` |

## Agent-side usage rule

- Never run write actions directly as the first step.
- First generate a preview through `jira_acli_exec.sh` without `--confirm`.
- Only run the same command again with `--confirm` after explicit user approval.
- Use `view --json` after successful writes to verify the final state.

## Known limits

- ACLI covers core work item actions cleanly.
- Organization-specific mutations for custom fields, sprint placement, fixVersion, and epic linkage may still need REST fallback depending on site configuration.
- Treat comment ADF payloads cautiously; plain text is the safer default unless the richer format is required.
