#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
JIRA_HELPER="${ROOT_DIR}/skills/jira-acli/scripts/jira_acli_exec.sh"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --key KEY [--template implementation|qa|release] [--output FILE]
  $(basename "$0") --issue-json FILE [--template implementation|qa|release] [--output FILE]
EOF
}

template="implementation"
key=""
issue_json_file=""
output_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)
      key="$2"
      shift 2
      ;;
    --issue-json)
      issue_json_file="$2"
      shift 2
      ;;
    --template)
      template="$2"
      shift 2
      ;;
    --output)
      output_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$key" && -z "$issue_json_file" ]]; then
  printf 'Provide --key or --issue-json.\n' >&2
  exit 1
fi

if [[ -n "$issue_json_file" ]]; then
  raw_issue="$(cat "$issue_json_file")"
else
  helper_output="$("$JIRA_HELPER" view --key "$key")"
  raw_issue="$(printf '%s' "$helper_output" | jq -c '.result')"
fi

key_value="$(printf '%s' "$raw_issue" | jq -r '.key // .id // "UNKNOWN-KEY"' 2>/dev/null || printf 'UNKNOWN-KEY')"
summary_value="$(printf '%s' "$raw_issue" | jq -r '.fields.summary // .summary // "Untitled issue"' 2>/dev/null || printf 'Untitled issue')"
status_value="$(printf '%s' "$raw_issue" | jq -r '.fields.status.name // .status.name // .status // "Unknown"' 2>/dev/null || printf 'Unknown')"
type_value="$(printf '%s' "$raw_issue" | jq -r '.fields.issuetype.name // .issuetype.name // .issuetype // "Unknown"' 2>/dev/null || printf 'Unknown')"
assignee_value="$(printf '%s' "$raw_issue" | jq -r '.fields.assignee.displayName // .assignee.displayName // .assignee.emailAddress // "Unassigned"' 2>/dev/null || printf 'Unassigned')"

case "$template" in
  implementation)
    checklist_content="$(cat <<EOF
# ${key_value} ${summary_value}

- Type: ${type_value}
- Status: ${status_value}
- Assignee: ${assignee_value}

## Implementation Checklist

- [ ] Reproduce or restate the issue scope from Jira.
- [ ] Identify the affected code path and likely side effects.
- [ ] Confirm acceptance criteria or expected output before coding.
- [ ] Implement the smallest coherent change.
- [ ] Verify the primary success path.
- [ ] Verify one likely regression or edge case.
- [ ] Prepare a concise Jira update describing what changed.
EOF
)"
    ;;
  qa)
    checklist_content="$(cat <<EOF
# ${key_value} ${summary_value}

- Type: ${type_value}
- Status: ${status_value}
- Assignee: ${assignee_value}

## QA Checklist

- [ ] Confirm the issue intent and expected outcome.
- [ ] Validate the happy path in the target environment.
- [ ] Validate one error path or edge case.
- [ ] Check for regressions in adjacent flows.
- [ ] Confirm UI copy, data changes, and logs where relevant.
- [ ] Record test evidence or notes for the Jira update.
EOF
)"
    ;;
  release)
    checklist_content="$(cat <<EOF
# ${key_value} ${summary_value}

- Type: ${type_value}
- Status: ${status_value}
- Assignee: ${assignee_value}

## Release Checklist

- [ ] Confirm the issue is in the correct final workflow state.
- [ ] Verify linked code changes or deployment references are complete.
- [ ] Confirm test coverage or validation notes are attached.
- [ ] Check for any release note or stakeholder communication need.
- [ ] Post the release summary back to Jira if required.
EOF
)"
    ;;
  *)
    printf 'Unsupported template: %s\n' "$template" >&2
    exit 1
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s\n' "$checklist_content" >"$output_file"
else
  printf '%s\n' "$checklist_content"
fi
