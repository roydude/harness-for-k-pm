# NOTICE

영문 버전: [NOTICE.md](NOTICE.md)

이 저장소는 non-system Codex 스킬을 위한 공개 설치 번들입니다.

명시적으로 `vendor/skills/` 아래에 포함한 스킬을 제외하면, 업스트림 제3자 스킬 폴더 자체를 이 저장소에 재배포하지 않습니다. 대부분의 스킬은 `manifest/skills.yaml`에 적힌 pinned commit SHA를 기준으로 원래 GitHub 저장소에서 직접 설치됩니다.

## 업스트림 출처

### OpenAI Skills

- 원본 저장소: `openai/skills`
- 설치 대상 스킬:
  - `doc`
  - `figma`
  - `figma-implement-design`
  - `openai-docs`
  - `pdf`
  - `playwright`
- 설치 방식: 업스트림 GitHub path 설치
- 라이선스: 업스트림 저장소와 각 설치 스킬 디렉터리 내 라이선스 파일 참조

### UI / UX Pro Max

- 원본 저장소: `nextlevelbuilder/ui-ux-pro-max-skill`
- 설치 대상 스킬: `ui-ux-pro-max`
- 설치 방식: 업스트림 GitHub path 설치
- 라이선스: 업스트림 저장소 참조

### PM Skills Marketplace

- 원본 저장소: `phuryn/pm-skills`
- 설치 대상 스킬: `manifest/skills.yaml`에 적힌 Codex 호환 `skills/*/SKILL.md` 항목 전체
- 설치 방식: 업스트림 GitHub path 설치
- 업스트림 선언 라이선스: MIT

### Vendored Local Skill

- vendored 경로: `vendor/skills/korean-humanizer`
- 설치 대상 스킬: `korean-humanizer`
- 설치 방식: 이 저장소에서 직접 복사
- 출처: 이 번들 저장소에서 유지하는 로컬 커스텀 스킬

## 재배포 메모

- 기본적으로 이 저장소는 vendored 로컬 스킬 1개만 직접 포함합니다.
- 업스트림 스킬의 저작권과 출처는 원본 저장소에 귀속됩니다.
- 나중에 vendored 스킬을 더 추가하면 이 파일과 `manifest/skills.yaml`를 함께 갱신해야 합니다.
