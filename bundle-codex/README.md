# planner bundle for Codex

Codex에 설치되는 실제 planner bundle 배포물이다.

- `AGENTS.md`
- `agents/*.toml`
- `skills/*`

`scripts/install-planner-bundle.mjs --runtime codex`는 이 디렉토리를 그대로 `~/.codex` 아래에 설치한다.

설치 후에는 `credentials.example.md`를 `credentials.md`로 복사해 비밀이 아닌 Jira 설정만 채우고, 실제 인증은 `acli jira auth login --web`으로 처리한다.
