#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEFAULT_CREDENTIALS_FILE="${ROOT_DIR}/credentials.md"

trim() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_site() {
  local value
  value="$(trim "${1:-}")"
  value="${value#https://}"
  value="${value#http://}"
  value="${value%/}"
  printf '%s' "$value"
}

extract_credentials_block() {
  local file_path="$1"
  awk '
    /<!-- jira-acli:credentials:start -->/ { in_block=1; next }
    /<!-- jira-acli:credentials:end -->/ { in_block=0 }
    in_block { print }
  ' "$file_path"
}

load_credentials() {
  local file_path="$1"
  local block line key value

  if [[ ! -f "$file_path" ]]; then
    return 1
  fi

  block="$(extract_credentials_block "$file_path")"
  if [[ -z "$block" ]]; then
    return 2
  fi

  JIRA_ACLI_SITE=""
  JIRA_ACLI_EMAIL=""
  JIRA_ACLI_TOKEN=""
  JIRA_ACLI_PROJECTS=""
  JIRA_ACLI_DEFAULT_PROJECT=""

  while IFS= read -r line; do
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="$(trim "$key")"
    value="$(trim "$value")"

    case "$key" in
      site)
        JIRA_ACLI_SITE="$(normalize_site "$value")"
        ;;
      email)
        JIRA_ACLI_EMAIL="$value"
        ;;
      token)
        JIRA_ACLI_TOKEN="$value"
        ;;
      projects)
        JIRA_ACLI_PROJECTS="$value"
        ;;
      default_project)
        JIRA_ACLI_DEFAULT_PROJECT="$value"
        ;;
    esac
  done <<< "$block"

  export JIRA_ACLI_SITE JIRA_ACLI_EMAIL JIRA_ACLI_TOKEN JIRA_ACLI_PROJECTS JIRA_ACLI_DEFAULT_PROJECT
  return 0
}

project_list_json() {
  local projects="${1:-}"
  jq -Rn --arg raw "$projects" '
    ($raw
      | split(",")
      | map(gsub("^\\s+|\\s+$"; ""))
      | map(select(length > 0)))
  '
}

first_project() {
  local projects="${1:-}"
  printf '%s' "$projects" | awk -F',' '
    {
      for (i = 1; i <= NF; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
        if ($i != "") {
          print $i
          exit
        }
      }
    }
  '
}

check_jq_available() {
  command -v jq >/dev/null 2>&1
}

check_acli_available() {
  command -v acli >/dev/null 2>&1
}

check_auth_status() {
  acli jira auth status >/dev/null 2>&1
}

login_hint() {
  cat <<EOF
acli jira auth login --web
echo "<token>" | acli jira auth login --site "${JIRA_ACLI_SITE:-your-domain.atlassian.net}" --email "${JIRA_ACLI_EMAIL:-you@example.com}" --token
EOF
}

status_json() {
  local credentials_file="$1"
  local credentials_ok="$2"
  local acli_ok="$3"
  local jq_ok="$4"
  local auth_ok="$5"
  local first_project_value

  first_project_value="$(first_project "${JIRA_ACLI_PROJECTS:-}")"

  jq -n \
    --arg credentials_file "$credentials_file" \
    --arg root_dir "$ROOT_DIR" \
    --arg site "${JIRA_ACLI_SITE:-}" \
    --arg email "${JIRA_ACLI_EMAIL:-}" \
    --arg default_project "${JIRA_ACLI_DEFAULT_PROJECT:-}" \
    --arg first_project "$first_project_value" \
    --argjson projects "$(project_list_json "${JIRA_ACLI_PROJECTS:-}")" \
    --argjson credentials_ok "$credentials_ok" \
    --argjson acli_ok "$acli_ok" \
    --argjson jq_ok "$jq_ok" \
    --argjson auth_ok "$auth_ok" \
    --arg login_hint "$(login_hint)" \
    '{
      ok: ($credentials_ok and $acli_ok and $jq_ok and $auth_ok),
      root_dir: $root_dir,
      credentials_file: $credentials_file,
      credentials: {
        ok: $credentials_ok,
        site: $site,
        email: $email,
        projects: $projects,
        default_project: $default_project,
        first_project: $first_project
      },
      dependencies: {
        acli: $acli_ok,
        jq: $jq_ok
      },
      auth: {
        ok: $auth_ok,
        login_hint: $login_hint
      }
    }'
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--credentials FILE] [--json]

Checks:
- credentials marker block in credentials.md
- jq availability
- acli availability
- jira auth status
EOF
}

main() {
  local credentials_file="$DEFAULT_CREDENTIALS_FILE"
  local json_mode=0
  local credentials_ok=false
  local acli_ok=false
  local jq_ok=false
  local auth_ok=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --credentials)
        credentials_file="$2"
        shift 2
        ;;
      --json)
        json_mode=1
        shift
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

  if load_credentials "$credentials_file"; then
    credentials_ok=true
  fi

  if check_jq_available; then
    jq_ok=true
  fi

  if check_acli_available; then
    acli_ok=true
  fi

  if [[ "$acli_ok" == true ]] && check_auth_status; then
    auth_ok=true
  fi

  if [[ "$json_mode" -eq 1 ]]; then
    status_json "$credentials_file" "$credentials_ok" "$acli_ok" "$jq_ok" "$auth_ok"
    exit 0
  fi

  printf 'root_dir=%s\n' "$ROOT_DIR"
  printf 'credentials_file=%s\n' "$credentials_file"
  printf 'credentials_ok=%s\n' "$credentials_ok"
  printf 'site=%s\n' "${JIRA_ACLI_SITE:-}"
  printf 'email=%s\n' "${JIRA_ACLI_EMAIL:-}"
  printf 'projects=%s\n' "${JIRA_ACLI_PROJECTS:-}"
  printf 'default_project=%s\n' "${JIRA_ACLI_DEFAULT_PROJECT:-}"
  printf 'jq_ok=%s\n' "$jq_ok"
  printf 'acli_ok=%s\n' "$acli_ok"
  printf 'auth_ok=%s\n' "$auth_ok"

  if [[ "$auth_ok" != true ]]; then
    printf '\nLogin hints:\n%s\n' "$(login_hint)"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
