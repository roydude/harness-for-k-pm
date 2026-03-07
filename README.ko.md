# Harness for K-PM

영문 버전: [README.md](README.md)

K-PM Agent Harness

한국의 프로덕트 매니저는 여전히 업무 범위가 매우 넓은 경우가 많습니다.

비즈니스 전략과 조직 KPI를 보는 역할만 맡는 것이 아닙니다. 기획서 작성, 데이터 분석, 화면 설계, 클라이언트 커뮤니케이션, 일정 관리, QA, 버그 리포팅, 운영 CS, 때로는 마케팅까지 함께 담당하기도 합니다.

이 레포는 그런 한국형 PM, 즉 K-PM을 위해 만들었습니다. 스타트업부터 대기업까지 다양한 환경에서 일하는 프로덕트 매니저가 자신의 실제 업무 맥락에 맞춰 골라 쓸 수 있는 에이전트 하네스를 제공합니다.

목표는 분명합니다. 반복적이고 무거운 실무 부담은 덜어내고, 더 중요한 판단과 조율, 문제 해결에 더 집중할 수 있게 돕는 것입니다.

현재 이 저장소는 비시스템(non-system) Codex 스킬을 빠르게 재설치하기 위한 공개 설치 번들 역할을 합니다.

이 저장소는 재사용 가능한 Codex 스킬을 하나의 manifest로 관리하고, Codex CLI와 Codex App 모두에서 `${CODEX_HOME:-$HOME/.codex}/skills`로 설치합니다. 업스트림 스킬은 원래 GitHub 저장소에서 commit SHA 기준으로 고정해 가져오고, 로컬 전용 스킬만 `vendor/skills/` 아래에 직접 보관합니다.

## 저장소 구성

- `manifest/skills.yaml`: 설치 가능한 스킬의 source-of-truth
- `scripts/install_codex_skills.py`: dry-run, category, single-skill 설치를 지원하는 설치기
- `scripts/check_updates.py`: pinned GitHub ref의 업데이트 여부를 확인하는 스크립트
- `vendor/skills/`: 로컬 전용 vendored 스킬
- `NOTICE.md`: 업스트림 출처와 라이선스 메모
- `NOTICE.ko.md`: 출처와 라이선스의 한국어 버전

## 빠른 시작

macOS와 Linux에서 동일하게 사용할 수 있습니다.

```bash
git clone <your-public-repo-url> harness-for-k-pm
cd harness-for-k-pm
python3 scripts/install_codex_skills.py --all
```

커스텀 Codex home에 설치:

```bash
CODEX_HOME=/tmp/codex-home python3 scripts/install_codex_skills.py --all
```

아무 것도 바꾸지 않고 설치 계획만 보기:

```bash
python3 scripts/install_codex_skills.py --all --dry-run
```

카테고리별 설치:

```bash
python3 scripts/install_codex_skills.py --category "PM 전략"
```

단일 스킬 설치:

```bash
python3 scripts/install_codex_skills.py --skill korean-humanizer
```

기존 스킬 강제 재설치:

```bash
python3 scripts/install_codex_skills.py --all --force
```

## 카테고리

manifest 카테고리는 이후 `AGENTS.md`에서도 그대로 재사용할 수 있게 맞춰두었습니다.

- `기본 생산성 / 문서 / 디자인`
- `PM 데이터 분석`
- `PM 제품 탐색`
- `PM 전략`
- `PM 실행 / 기획 운영`
- `시장 조사 / GTM / 성장`
- `실무 툴킷 / 문서 보조`

## 업데이트 워크플로우

업스트림 default branch가 현재 pin된 SHA보다 앞섰는지 확인:

```bash
python3 scripts/check_updates.py
```

권장 유지보수 흐름:

1. `python3 scripts/check_updates.py`를 실행한다.
2. 실제로 반영할 업스트림 변경만 검토한다.
3. `manifest/skills.yaml`의 `ref`를 기존 SHA에서 새 SHA로 올린다.
4. 임시 `CODEX_HOME`에 테스트 설치를 다시 돌린다.
5. manifest 변경을 커밋한다.

설치 스크립트는 업스트림을 자동 머지하지 않습니다. manifest가 명시적인 검토 지점입니다.

## Manifest 스키마

`manifest/skills.yaml`의 각 항목은 아래 필드를 사용합니다.

- `name`: manifest 식별자
- `category`: 사용자용 카테고리
- `source_type`: `github_path` 또는 `vendored`
- `repo`: 업스트림 GitHub 스킬의 `owner/repo`
- `ref`: pin된 commit SHA
- `path`: repo 내부 스킬 경로 또는 vendored 경로
- `dest_name`: `~/.codex/skills` 아래 생성될 디렉터리명
- `license`: SPDX 유사 표기 또는 `see upstream`
- `notes`: 선택 메모

## 설치 메모

- `.system` 스킬은 의도적으로 제외했습니다.
- 기본 동작은 기존 스킬 디렉터리를 skip합니다.
- Codex 내장 `install-skill-from-github.py`가 있으면 우선 재사용합니다.
- 그 helper가 없으면 Python 표준 라이브러리만으로 동작하는 zip-download fallback을 사용합니다.
