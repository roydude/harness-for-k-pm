#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ENSURE_SCRIPT="${SCRIPT_DIR}/ensure_acli.sh"

# shellcheck source=/dev/null
source "$ENSURE_SCRIPT"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  ACTION="help"
else
  shift || true
fi

usage() {
  cat <<EOF
Usage:
  $(basename "$0") project [--project KEY] [--credentials FILE]
  $(basename "$0") search [--project KEY] [--jql QUERY] [--limit N] [--credentials FILE]
  $(basename "$0") view --key KEY [--fields CSV] [--credentials FILE]
  $(basename "$0") create --project KEY --type TYPE --summary TEXT [--description TEXT | --description-file FILE] [--assignee EMAIL] [--label CSV] [--parent ID] [--confirm] [--credentials FILE]
  $(basename "$0") edit --key KEY [--summary TEXT] [--description TEXT | --description-file FILE] [--assignee EMAIL] [--label CSV] [--confirm] [--credentials FILE]
  $(basename "$0") transition --key KEY --status TEXT [--confirm] [--credentials FILE]
  $(basename "$0") comment --key KEY [--body TEXT | --body-file FILE] [--confirm] [--credentials FILE]

Read actions execute immediately.
Write actions return preview only unless --confirm is present.
EOF
}

command_json() {
  printf '%s\n' "$@" | jq -R . | jq -s .
}

string_or_json() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    printf 'null'
  elif printf '%s' "$raw" | jq -e . >/dev/null 2>&1; then
    printf '%s' "$raw"
  else
    jq -Rn --arg text "$raw" '$text'
  fi
}

csv_to_json() {
  local raw="${1:-}"
  jq -Rn --arg raw "$raw" '
    ($raw
      | split(",")
      | map(gsub("^\\s+|\\s+$"; ""))
      | map(select(length > 0)))
  '
}

ensure_ready() {
  local credentials_file="$1"
  if ! load_credentials "$credentials_file"; then
    jq -n \
      --arg action "$ACTION" \
      --arg credentials_file "$credentials_file" \
      '{
        ok: false,
        action: $action,
        error: "credentials_unavailable",
        message: "credentials.md is missing or does not contain the jira-acli marker block.",
        credentials_file: $credentials_file
      }'
    return 1
  fi

  if ! check_jq_available; then
    jq -n \
      --arg action "$ACTION" \
      '{
        ok: false,
        action: $action,
        error: "jq_missing",
        message: "jq is required for jira-acli normalized output."
      }'
    return 1
  fi

  if ! check_acli_available; then
    jq -n \
      --arg action "$ACTION" \
      '{
        ok: false,
        action: $action,
        error: "acli_missing",
        message: "acli is not installed or not available on PATH."
      }'
    return 1
  fi

  if ! check_auth_status; then
    jq -n \
      --arg action "$ACTION" \
      --arg login_hint "$(login_hint)" \
      '{
        ok: false,
        action: $action,
        error: "jira_auth_missing",
        message: "Jira authentication is not ready.",
        login_hint: $login_hint
      }'
    return 1
  fi

  return 0
}

resolve_project() {
  local requested="${1:-}"
  if [[ -n "$requested" ]]; then
    printf '%s' "$requested"
    return 0
  fi
  if [[ -n "${JIRA_ACLI_DEFAULT_PROJECT:-}" ]]; then
    printf '%s' "$JIRA_ACLI_DEFAULT_PROJECT"
    return 0
  fi
  first_project "${JIRA_ACLI_PROJECTS:-}"
}

run_capture() {
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"

  if "$@" >"$stdout_file" 2>"$stderr_file"; then
    RUN_STATUS=0
  else
    RUN_STATUS=$?
  fi

  RUN_STDOUT="$(cat "$stdout_file")"
  RUN_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

extract_issue_key() {
  local raw="${1:-}"
  printf '%s' "$raw" | jq -r '
    if type == "object" and (.key? | type == "string") then .key
    elif type == "object" and (.workItem.key? | type == "string") then .workItem.key
    elif type == "array" and length > 0 and (.[0].key? | type == "string") then .[0].key
    else empty
    end
  ' 2>/dev/null | head -n 1
}

emit_result() {
  local ok="$1"
  local action="$2"
  local executed="$3"
  local project="$4"
  local preview_json="$5"
  local command_json_value="$6"
  local result_json="$7"
  local verify_json="$8"
  local stderr_text="$9"
  local message="${10}"
  local warnings_json="${11:-[]}"

  jq -n \
    --argjson ok "$ok" \
    --arg action "$action" \
    --argjson executed "$executed" \
    --arg project "$project" \
    --argjson preview "$preview_json" \
    --argjson command "$command_json_value" \
    --argjson result "$result_json" \
    --argjson verify "$verify_json" \
    --arg stderr "$stderr_text" \
    --arg message "$message" \
    --argjson warnings "$warnings_json" \
    '{
      ok: $ok,
      action: $action,
      executed: $executed,
      project: (if $project == "" then null else $project end),
      preview: $preview,
      command: $command,
      result: $result,
      verify: $verify,
      stderr: (if $stderr == "" then null else $stderr end),
      message: (if $message == "" then null else $message end),
      warnings: $warnings
    }'
}

emit_error() {
  local action="$1"
  local project="$2"
  local preview_json="$3"
  local command_json_value="$4"
  local stderr_text="$5"
  local stdout_text="$6"
  local message="$7"

  jq -n \
    --arg action "$action" \
    --arg project "$project" \
    --argjson preview "$preview_json" \
    --argjson command "$command_json_value" \
    --arg stderr "$stderr_text" \
    --arg stdout "$stdout_text" \
    --arg message "$message" \
    '{
      ok: false,
      action: $action,
      project: (if $project == "" then null else $project end),
      preview: $preview,
      command: $command,
      stderr: (if $stderr == "" then null else $stderr end),
      stdout: (if $stdout == "" then null else $stdout end),
      message: $message
    }'
}

credentials_file="${ROOT_DIR}/credentials.md"
project=""
key=""
jql=""
limit="20"
fields=""
summary=""
type=""
description=""
description_file=""
assignee=""
labels=""
parent=""
status=""
body=""
body_file=""
confirm=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --credentials)
      credentials_file="$2"
      shift 2
      ;;
    --project)
      project="$2"
      shift 2
      ;;
    --key)
      key="$2"
      shift 2
      ;;
    --jql)
      jql="$2"
      shift 2
      ;;
    --limit)
      limit="$2"
      shift 2
      ;;
    --fields)
      fields="$2"
      shift 2
      ;;
    --summary)
      summary="$2"
      shift 2
      ;;
    --type)
      type="$2"
      shift 2
      ;;
    --description)
      description="$2"
      shift 2
      ;;
    --description-file)
      description_file="$2"
      shift 2
      ;;
    --assignee)
      assignee="$2"
      shift 2
      ;;
    --label|--labels)
      labels="$2"
      shift 2
      ;;
    --parent)
      parent="$2"
      shift 2
      ;;
    --status)
      status="$2"
      shift 2
      ;;
    --body)
      body="$2"
      shift 2
      ;;
    --body-file)
      body_file="$2"
      shift 2
      ;;
    --confirm)
      confirm=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument for %s: %s\n' "$ACTION" "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$ACTION" == "help" ]]; then
  usage
  exit 0
fi

if ! ensure_ready "$credentials_file"; then
  exit 1
fi

case "$ACTION" in
  project)
    project="$(resolve_project "$project")"
    if [[ -z "$project" ]]; then
      jq -n '{
        ok: false,
        action: "project",
        error: "project_missing",
        message: "No project was supplied and no default project is configured."
      }'
      exit 1
    fi
    cmd=(acli jira project view --key "$project" --json)
    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "project" "$project" 'null' "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Project lookup failed."
      exit 1
    fi
    emit_result true "project" true "$project" 'null' "$(command_json "${cmd[@]}")" "$(string_or_json "$RUN_STDOUT")" 'null' "$RUN_STDERR" "" '[]'
    ;;
  search)
    project="$(resolve_project "$project")"
    if [[ -z "$jql" ]]; then
      if [[ -z "$project" ]]; then
        jq -n '{
          ok: false,
          action: "search",
          error: "query_missing",
          message: "Provide --jql or configure a default project."
        }'
        exit 1
      fi
      jql="project = ${project} ORDER BY updated DESC"
    fi
    cmd=(acli jira workitem search --jql "$jql" --limit "$limit" --json)
    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "search" "$project" "$(jq -n --arg jql "$jql" --arg limit "$limit" '{jql:$jql, limit:($limit|tonumber)}')" "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Work item search failed."
      exit 1
    fi
    emit_result true "search" true "$project" "$(jq -n --arg jql "$jql" --arg limit "$limit" '{jql:$jql, limit:($limit|tonumber)}')" "$(command_json "${cmd[@]}")" "$(string_or_json "$RUN_STDOUT")" 'null' "$RUN_STDERR" "" '[]'
    ;;
  view)
    if [[ -z "$key" ]]; then
      jq -n '{
        ok: false,
        action: "view",
        error: "key_missing",
        message: "Provide --key for work item view."
      }'
      exit 1
    fi
    cmd=(acli jira workitem view "$key" --json)
    if [[ -n "$fields" ]]; then
      cmd+=(--fields "$fields")
    fi
    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "view" "$project" 'null' "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Work item view failed."
      exit 1
    fi
    emit_result true "view" true "$project" 'null' "$(command_json "${cmd[@]}")" "$(string_or_json "$RUN_STDOUT")" 'null' "$RUN_STDERR" "" '[]'
    ;;
  create)
    project="$(resolve_project "$project")"
    if [[ -z "$project" || -z "$type" || -z "$summary" ]]; then
      jq -n \
        --arg project "$project" \
        --arg type "$type" \
        --arg summary "$summary" \
        '{
          ok: false,
          action: "create",
          error: "required_fields_missing",
          message: "Create requires project, type, and summary.",
          received: {
            project: (if $project == "" then null else $project end),
            type: (if $type == "" then null else $type end),
            summary: (if $summary == "" then null else $summary end)
          }
        }'
      exit 1
    fi
    if [[ -n "$description" && -n "$description_file" ]]; then
      jq -n '{
        ok: false,
        action: "create",
        error: "description_ambiguous",
        message: "Use either --description or --description-file, not both."
      }'
      exit 1
    fi

    preview_json="$(jq -n \
      --arg project "$project" \
      --arg type "$type" \
      --arg summary "$summary" \
      --arg description "$description" \
      --arg description_file "$description_file" \
      --arg assignee "$assignee" \
      --arg parent "$parent" \
      --argjson labels "$(csv_to_json "$labels")" \
      '{
        project: $project,
        type: $type,
        summary: $summary,
        description: (if $description == "" then null else $description end),
        description_file: (if $description_file == "" then null else $description_file end),
        assignee: (if $assignee == "" then null else $assignee end),
        parent: (if $parent == "" then null else $parent end),
        labels: $labels
      }'
    )"

    cmd=(acli jira workitem create --project "$project" --type "$type" --summary "$summary" --json)
    [[ -n "$description" ]] && cmd+=(--description "$description")
    [[ -n "$description_file" ]] && cmd+=(--description-file "$description_file")
    [[ -n "$assignee" ]] && cmd+=(--assignee "$assignee")
    [[ -n "$parent" ]] && cmd+=(--parent "$parent")
    [[ -n "$labels" ]] && cmd+=(--label "$labels")

    if [[ "$confirm" -ne 1 ]]; then
      emit_result true "create" false "$project" "$preview_json" "$(command_json "${cmd[@]}")" 'null' 'null' "" "Preview only. Re-run with --confirm to execute." '[]'
      exit 0
    fi

    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "create" "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Work item creation failed."
      exit 1
    fi

    result_stdout="$RUN_STDOUT"
    result_stderr="$RUN_STDERR"
    created_key="$(extract_issue_key "$result_stdout")"
    verify_json='null'
    if [[ -n "$created_key" ]]; then
      verify_cmd=(acli jira workitem view "$created_key" --json)
      run_capture "${verify_cmd[@]}"
      if [[ "$RUN_STATUS" -eq 0 ]]; then
        verify_json="$(string_or_json "$RUN_STDOUT")"
      fi
    fi

    emit_result true "create" true "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$(string_or_json "$result_stdout")" "$verify_json" "$result_stderr" "" '[]'
    ;;
  edit)
    if [[ -z "$key" ]]; then
      jq -n '{
        ok: false,
        action: "edit",
        error: "key_missing",
        message: "Edit requires --key."
      }'
      exit 1
    fi
    if [[ -n "$description" && -n "$description_file" ]]; then
      jq -n '{
        ok: false,
        action: "edit",
        error: "description_ambiguous",
        message: "Use either --description or --description-file, not both."
      }'
      exit 1
    fi
    if [[ -z "$summary" && -z "$description" && -z "$description_file" && -z "$assignee" && -z "$labels" ]]; then
      jq -n '{
        ok: false,
        action: "edit",
        error: "changes_missing",
        message: "Edit requires at least one field change."
      }'
      exit 1
    fi

    preview_json="$(jq -n \
      --arg key "$key" \
      --arg summary "$summary" \
      --arg description "$description" \
      --arg description_file "$description_file" \
      --arg assignee "$assignee" \
      --argjson labels "$(csv_to_json "$labels")" \
      '{
        key: $key,
        summary: (if $summary == "" then null else $summary end),
        description: (if $description == "" then null else $description end),
        description_file: (if $description_file == "" then null else $description_file end),
        assignee: (if $assignee == "" then null else $assignee end),
        labels: $labels
      }'
    )"

    cmd=(acli jira workitem edit --key "$key" --yes --json)
    [[ -n "$summary" ]] && cmd+=(--summary "$summary")
    [[ -n "$description" ]] && cmd+=(--description "$description")
    [[ -n "$description_file" ]] && cmd+=(--description-file "$description_file")
    [[ -n "$assignee" ]] && cmd+=(--assignee "$assignee")
    [[ -n "$labels" ]] && cmd+=(--label "$labels")

    if [[ "$confirm" -ne 1 ]]; then
      emit_result true "edit" false "$project" "$preview_json" "$(command_json "${cmd[@]}")" 'null' 'null' "" "Preview only. Re-run with --confirm to execute." '[]'
      exit 0
    fi

    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "edit" "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Work item edit failed."
      exit 1
    fi

    result_stdout="$RUN_STDOUT"
    result_stderr="$RUN_STDERR"
    verify_cmd=(acli jira workitem view "$key" --json)
    verify_json='null'
    run_capture "${verify_cmd[@]}"
    if [[ "$RUN_STATUS" -eq 0 ]]; then
      verify_json="$(string_or_json "$RUN_STDOUT")"
    fi

    emit_result true "edit" true "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$(string_or_json "$result_stdout")" "$verify_json" "$result_stderr" "" '[]'
    ;;
  transition)
    if [[ -z "$key" || -z "$status" ]]; then
      jq -n \
        --arg key "$key" \
        --arg status "$status" \
        '{
          ok: false,
          action: "transition",
          error: "required_fields_missing",
          message: "Transition requires --key and --status.",
          received: {
            key: (if $key == "" then null else $key end),
            status: (if $status == "" then null else $status end)
          }
        }'
      exit 1
    fi

    preview_json="$(jq -n --arg key "$key" --arg status "$status" '{key:$key, status:$status}')"
    cmd=(acli jira workitem transition --key "$key" --status "$status" --yes --json)

    if [[ "$confirm" -ne 1 ]]; then
      emit_result true "transition" false "$project" "$preview_json" "$(command_json "${cmd[@]}")" 'null' 'null' "" "Preview only. Re-run with --confirm to execute." '[]'
      exit 0
    fi

    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "transition" "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Work item transition failed."
      exit 1
    fi

    result_stdout="$RUN_STDOUT"
    result_stderr="$RUN_STDERR"
    verify_cmd=(acli jira workitem view "$key" --json)
    verify_json='null'
    run_capture "${verify_cmd[@]}"
    if [[ "$RUN_STATUS" -eq 0 ]]; then
      verify_json="$(string_or_json "$RUN_STDOUT")"
    fi

    emit_result true "transition" true "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$(string_or_json "$result_stdout")" "$verify_json" "$result_stderr" "" '[]'
    ;;
  comment)
    if [[ -z "$key" ]]; then
      jq -n '{
        ok: false,
        action: "comment",
        error: "key_missing",
        message: "Comment requires --key."
      }'
      exit 1
    fi
    if [[ -n "$body" && -n "$body_file" ]]; then
      jq -n '{
        ok: false,
        action: "comment",
        error: "body_ambiguous",
        message: "Use either --body or --body-file, not both."
      }'
      exit 1
    fi
    if [[ -z "$body" && -z "$body_file" ]]; then
      jq -n '{
        ok: false,
        action: "comment",
        error: "body_missing",
        message: "Comment requires --body or --body-file."
      }'
      exit 1
    fi

    preview_json="$(jq -n \
      --arg key "$key" \
      --arg body "$body" \
      --arg body_file "$body_file" \
      '{
        key: $key,
        body: (if $body == "" then null else $body end),
        body_file: (if $body_file == "" then null else $body_file end)
      }'
    )"

    cmd=(acli jira workitem comment create --key "$key" --json)
    [[ -n "$body" ]] && cmd+=(--body "$body")
    [[ -n "$body_file" ]] && cmd+=(--body-file "$body_file")

    if [[ "$confirm" -ne 1 ]]; then
      emit_result true "comment" false "$project" "$preview_json" "$(command_json "${cmd[@]}")" 'null' 'null' "" "Preview only. Re-run with --confirm to execute." '[]'
      exit 0
    fi

    run_capture "${cmd[@]}"
    if [[ "$RUN_STATUS" -ne 0 ]]; then
      emit_error "comment" "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$RUN_STDERR" "$RUN_STDOUT" "Comment creation failed."
      exit 1
    fi

    result_stdout="$RUN_STDOUT"
    result_stderr="$RUN_STDERR"
    verify_cmd=(acli jira workitem view "$key" --json --fields "comment,summary,status")
    verify_json='null'
    run_capture "${verify_cmd[@]}"
    if [[ "$RUN_STATUS" -eq 0 ]]; then
      verify_json="$(string_or_json "$RUN_STDOUT")"
    fi

    emit_result true "comment" true "$project" "$preview_json" "$(command_json "${cmd[@]}")" "$(string_or_json "$result_stdout")" "$verify_json" "$result_stderr" "" '[]'
    ;;
  *)
    printf 'Unknown action: %s\n' "$ACTION" >&2
    usage >&2
    exit 1
    ;;
esac
