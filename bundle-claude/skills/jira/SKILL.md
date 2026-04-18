---
name: jira
description: Jira 이슈를 조회/생성/수정한다. CLI(curl) 기반으로 MCP 대체.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Jira CLI Skill

Jira REST API를 curl로 직접 호출하여 이슈를 관리한다. MCP 도구 대신 사용하여 컨텍스트를 절약한다.

## 인증 정보

- **Base URL**: `https://your-domain.atlassian.net`
- **런타임 설정**: `~/.claude/credentials.md` 같은 Git 비추적 로컬 파일에 `site`, `email`, `projects`, `default_project`만 둔다
- **실제 인증**: `acli jira auth login --web` 또는 OS 비밀 저장소를 우선 사용한다
- **주의**: `user:token`이나 Bearer 토큰을 명령행에 직접 적지 않는다

## 인자 파싱

`$ARGUMENTS`를 분석하여 아래 액션을 결정한다:

### 액션 목록

1. **이슈 조회** — 이슈 키가 주어지면 (예: `NMRS-12345`)
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/api/3/issue/{issueKey}" \
     | jq '{key:.key, summary:.fields.summary, status:.fields.status.name, assignee:.fields.assignee.displayName, description:.fields.description}'
   ```

2. **이슈 검색** — JQL 또는 키워드가 주어지면
   ```bash
   curl -s -G --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/api/3/search/jql" \
     --data-urlencode "jql={JQL}" --data-urlencode "fields=key,summary,status,assignee" \
     | jq '.issues[] | {key:.key, summary:.fields.summary, status:.fields.status.name}'
   ```

3. **이슈 생성** — "생성", "만들어" 등의 키워드
   - 생성 전 필수 필드 확인: 프로젝트, 이슈타입, summary
   - 메모리 규칙에 따라 상위항목(Epic), Sprint, 수정버전(fixVersions) 필수
   - 활성 Sprint/버전을 먼저 조회하여 추천 후 사용자 확인
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/agile/1.0/board/{boardId}/sprint?state=active" \
     | jq '.values[] | {id:.id, name:.name}'

   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/api/3/project/{projectKey}/versions" \
     | jq '[.[] | select(.released==false)] | .[] | {id:.id, name:.name}'

   curl -s --netrc-file "$HOME/.jira-netrc" -X POST \
     "https://your-domain.atlassian.net/rest/api/3/issue" \
     -H "Content-Type: application/json" \
     -d '{"fields":{"project":{"key":"{projectKey}"},"issuetype":{"name":"Task"},"summary":"{summary}","parent":{"key":"{epicKey}"},"customfield_10020":{sprintId},"fixVersions":[{"id":"{versionId}"}]}}'
   ```

4. **이슈 수정** — "수정", "업데이트", "변경" 등의 키워드 + 이슈 키
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" -X PUT \
     "https://your-domain.atlassian.net/rest/api/3/issue/{issueKey}" \
     -H "Content-Type: application/json" \
     -d '{"fields":{변경할 필드}}'
   ```

5. **상태 전환** — "진행", "완료", "전환" 등
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/api/3/issue/{issueKey}/transitions" \
     | jq '.transitions[] | {id:.id, name:.name}'

   curl -s --netrc-file "$HOME/.jira-netrc" -X POST \
     "https://your-domain.atlassian.net/rest/api/3/issue/{issueKey}/transitions" \
     -H "Content-Type: application/json" \
     -d '{"transition":{"id":"{transitionId}"}}'
   ```

6. **코멘트 추가** — "코멘트", "댓글" 등
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" -X POST \
     "https://your-domain.atlassian.net/rest/api/3/issue/{issueKey}/comment" \
     -H "Content-Type: application/json" \
     -d '{"body":"{코멘트 내용}"}'
   ```

7. **보드/스프린트 조회** — "보드", "스프린트" 등
   ```bash
   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/agile/1.0/board?projectKeyOrId={projectKey}" \
     | jq '.values[] | {id:.id, name:.name}'

   curl -s --netrc-file "$HOME/.jira-netrc" \
     "https://your-domain.atlassian.net/rest/agile/1.0/sprint/{sprintId}/issue" \
     | jq '.issues[] | {key:.key, summary:.fields.summary, status:.fields.status.name}'
   ```

8. **체크리스트 등록** — "체크리스트" 키워드 → `/jira-checklist` skill로 위임

## 응답 포맷

- jq로 필요한 필드만 추출하여 출력
- 결과를 간결하게 요약하여 사용자에게 보여줌
- 에러 발생 시 HTTP 상태 코드와 메시지 출력

## 주의사항

- Bearer 토큰이나 `user:token` 형태의 자격증명을 명령행에 직접 남기지 않는다
- `additional_fields` dict 파싱 실패 시 curl로 직접 호출
- Sprint 추가는 별도 Agile API 사용: `POST /rest/agile/1.0/sprint/{sprintId}/issue`

$ARGUMENTS
