# Harness for K-PM

영문 버전: [README.md](README.md)

Codex나 Claude Code를 사용하는 기획자가 에이전트 워크플로우를 빠르게 세팅할 수 있도록 정리한 planner bundle입니다.

이 저장소는 PM 실무에 맞는 기본값을 묶어서 제공합니다.

- 기획자 중심의 라우팅 규칙
- 명시적 요청이 있을 때만 위임하는 delegation 정책
- planning, design, implementation, review, QA의 역할 분리
- 기획서, 리서치, 요약, 문서, 슬라이드, Figma, Jira, 브라우저 작업에 바로 쓸 수 있는 skill 묶음

이 저장소는 설치 프레임워크가 아니라, 실제로 복사해서 쓰는 번들 배포물입니다.

## 포함 내용

### `bundle-codex/`

- `AGENTS.md`
- 16개의 역할 정의가 들어 있는 `agents/*.toml`
- 26개의 재사용 가능한 `skills/*`

### `bundle-claude/`

- `CLAUDE.md`
- 16개의 역할 정의가 들어 있는 `agents/*.md`
- 27개의 재사용 가능한 `skills/*`
- Claude 쪽 정리 작업에 쓰는 `refresh-planning-subagents` 포함

대표 역할:
`product-manager`, `business-analyst`, `project-manager`, `ui-designer`, `api-designer`, `architect-reviewer`, `frontend-developer`, `backend-developer`, `code-reviewer`, `qa-expert`

대표 스킬:
`create-prd`, `user-stories`, `summarize-meeting`, `summarize-interview`, `analyze-feature-requests`, `brainstorm-ideas-existing`, `jira-checklist`, `korean-humanizer`, `slides`, `figma`, `openai-docs`

## 빠른 설치

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

이미 `~/.codex/AGENTS.md`나 `~/.claude/CLAUDE.md`를 쓰고 있다면, 그대로 덮어쓰기보다 수동으로 병합하는 편이 안전합니다. 번들의 일부만 쓰고 싶다면 필요한 agent나 skill만 골라서 복사하면 됩니다.

## 기본 운영 원칙

- 서브에이전트는 기본으로 켜지지 않습니다.
- 사용자가 명시적으로 요청했을 때만 delegation을 사용합니다.
- 항상 가장 작은 유효 에이전트 조합을 우선합니다.
- planning, design, implementation, review, QA를 논리적으로 분리합니다.
- 명시적 요청이 없으면 큰 리팩터링을 피합니다.

## 커스터마이징 포인트

- 전역 라우팅 규칙은 `bundle-codex/AGENTS.md` 또는 `bundle-claude/CLAUDE.md`에서 수정합니다.
- 개별 역할 정의는 `bundle-*/agents/` 아래에서 조정합니다.
- 필요한 스킬만 남기거나 새 스킬을 추가하려면 `bundle-*/skills/`를 편집합니다.
- Codex와 Claude에서 비슷한 동작을 원하면 두 번들의 변경을 같이 맞추는 편이 좋습니다.

## 이런 용도에 맞습니다

이 번들은 다음 같은 일을 에이전트와 함께 처리하는 기획자에게 맞춰져 있습니다.

- PRD와 스펙 문서 작성
- 제품 탐색과 아이디어 발산
- 인터뷰와 미팅 요약
- Jira 기반 실행 지원
- 디자인 리뷰와 Figma 핸드오프
- 문서, 슬라이드, 브라우저 기반 실무 보조

완성형 표준이라기보다, 빠르게 깔고 바로 손보는 출발점에 가깝습니다. 팀의 실제 워크플로우에 맞게 덜어내고 조정하면서 쓰는 구성을 의도했습니다.
