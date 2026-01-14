# FDD 구현 계획 (Claude Code 내부 실행 방식)

> 별도 앱 없이 슬래시 커맨드 + CLAUDE.md + 훅으로 구현

---

## 구현 개요

### 산출물

```
FDDAgent/
├── commands/                    # 슬래시 커맨드 정의
│   ├── FDD.md
│   ├── FDD-init.md
│   ├── FDD-design.md
│   ├── FDD-plan.md
│   ├── FDD-develop.md
│   ├── FDD-status.md
│   └── FDD-resume.md
│
├── hooks/                       # 훅 스크립트
│   ├── quality-check.sh
│   ├── iteration-complete.sh
│   └── pre-commit.sh
│
├── templates/                   # 템플릿 파일
│   ├── config.yaml
│   ├── feature_map.yaml
│   ├── settings.json
│   └── CLAUDE_SECTION.md
│
├── install.sh                   # 설치 스크립트
│
└── docs/
    ├── SPECIFICATION_V2.md
    └── IMPLEMENTATION_PLAN_V2.md
```

### 설치 후 프로젝트 구조

```
target-project/
├── .claude/
│   ├── settings.json           # 훅 설정 (복사됨)
│   └── commands/               # 슬래시 커맨드 (복사됨)
│       └── FDD*.md
│
├── .FDD/                    # /FDD init으로 생성
│   ├── config.yaml
│   ├── feature_map.yaml
│   ├── design_document.yaml
│   ├── hooks/
│   │   └── *.sh
│   ├── iterations/
│   ├── checkpoints/
│   └── logs/
│
└── CLAUDE.md                   # FDD 섹션 추가됨
```

---

## Phase 1: 기본 인프라 (Day 1-2)

### 1.1 설치 스크립트

```bash
#!/bin/bash
# install.sh

FDD_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-.}"

echo "=== FDD Installer ==="
echo "Installing to: $TARGET_DIR"

# 1. .claude/commands 디렉토리 생성 및 커맨드 복사
mkdir -p "$TARGET_DIR/.claude/commands"
cp "$FDD_DIR/commands/"*.md "$TARGET_DIR/.claude/commands/"
echo "✓ Slash commands installed"

# 2. .claude/settings.json 복사 (병합)
if [ -f "$TARGET_DIR/.claude/settings.json" ]; then
    echo "⚠ .claude/settings.json exists - manual merge required"
    cp "$FDD_DIR/templates/settings.json" "$TARGET_DIR/.claude/settings.json.FDD"
else
    cp "$FDD_DIR/templates/settings.json" "$TARGET_DIR/.claude/settings.json"
    echo "✓ Hook settings installed"
fi

# 3. .FDD 기본 구조 생성
mkdir -p "$TARGET_DIR/.FDD/hooks"
mkdir -p "$TARGET_DIR/.FDD/iterations"
mkdir -p "$TARGET_DIR/.FDD/checkpoints"
mkdir -p "$TARGET_DIR/.FDD/logs"

# 4. 훅 스크립트 복사
cp "$FDD_DIR/hooks/"*.sh "$TARGET_DIR/.FDD/hooks/"
chmod +x "$TARGET_DIR/.FDD/hooks/"*.sh
echo "✓ Hook scripts installed"

# 5. 템플릿 복사
cp "$FDD_DIR/templates/config.yaml" "$TARGET_DIR/.FDD/"
cp "$FDD_DIR/templates/feature_map.yaml" "$TARGET_DIR/.FDD/"
echo "✓ Templates installed"

# 6. CLAUDE.md에 섹션 추가
if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    if ! grep -q "FDD Workflow" "$TARGET_DIR/CLAUDE.md"; then
        echo "" >> "$TARGET_DIR/CLAUDE.md"
        cat "$FDD_DIR/templates/CLAUDE_SECTION.md" >> "$TARGET_DIR/CLAUDE.md"
        echo "✓ CLAUDE.md updated"
    else
        echo "⚠ CLAUDE.md already has FDD section"
    fi
else
    cp "$FDD_DIR/templates/CLAUDE_SECTION.md" "$TARGET_DIR/CLAUDE.md"
    echo "✓ CLAUDE.md created"
fi

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. cd $TARGET_DIR"
echo "  2. claude"
echo "  3. /FDD init"
```

### 1.2 기본 설정 템플릿

```yaml
# templates/config.yaml

version: "1.0"

project:
  name: "Untitled Project"
  repo_path: "."

execution:
  max_parallel: 3
  max_feature_sets: 4
  timeout_per_iteration: 30m

build_test:
  auto_build: true
  auto_test: true
  build_command: "npm run build"
  test_command: "npm test"
  lint_command: "npm run lint"
  typecheck_command: "npx tsc --noEmit"
  retry:
    max_attempts: 3
    strategy: "fix_and_retry"

gates:
  design_approval: true
  feature_map_approval: true
  iteration_approval: false

logging:
  level: "info"
  events_file: ".FDD/logs/events.jsonl"
  audit_file: ".FDD/logs/audit.jsonl"

hooks:
  post_tool_use:
    enabled: true
    checks:
      - lint
      - typecheck
      - build
  post_iteration:
    enabled: true
    checks:
      - test
```

### 1.3 빈 Feature Map 템플릿

```yaml
# templates/feature_map.yaml

meta:
  project_name: "Untitled Project"
  repo_path: "."
  created_at: null
  updated_at: null
  version: "1.0"
  max_parallel: 3

design_summary: null

feature_map:
  nodes: []

execution_state:
  current_iteration: 0
  completed_sets: []
  in_progress_sets: []
  pending_sets: []
  blocked_sets: []
```

### 1.4 CLAUDE.md 섹션 템플릿

```markdown
# templates/CLAUDE_SECTION.md

---

# FDD Workflow Guidelines

이 프로젝트는 FDD (Feature-Driven Development) 워크플로우를 사용합니다.

## 핵심 원칙

1. **Feature 단위 개발**: 모든 구현은 Feature Map의 Feature Set 단위로 진행
2. **의존성 준수**: Feature Set의 depends_on이 모두 done이어야 개발 시작
3. **상태 파일 유지**: 모든 변경은 `.FDD/feature_map.yaml`에 반영
4. **품질 훅**: 코드 작성 후 자동 품질 검사 실행

## 상태 파일 위치

| 파일 | 용도 |
|------|------|
| `.FDD/config.yaml` | 프로젝트 설정 |
| `.FDD/feature_map.yaml` | Feature Map (핵심 상태) |
| `.FDD/design_document.yaml` | 설계 문서 |
| `.FDD/iterations/{set-id}/` | Iteration별 산출물 |
| `.FDD/logs/` | 이벤트/감사 로그 |

## 슬래시 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/FDD init` | 프로젝트 초기화 |
| `/FDD design <요구사항>` | Phase 1: 설계 문서 생성 |
| `/FDD plan` | Phase 2: Feature Map 생성 |
| `/FDD develop` | Phase 3: Iterative 개발 |
| `/FDD status` | 현재 상태 확인 |
| `/FDD resume` | 체크포인트에서 재개 |

## Feature Map 상태 값

| 상태 | 의미 |
|------|------|
| `todo` | 아직 시작하지 않음 |
| `in_progress` | 개발 중 |
| `done` | 완료 |
| `blocked` | 오류로 차단됨 |

## 개발 시 준수사항

1. **코드 작성 전**: 해당 Feature Set의 상세 설계 확인
2. **코드 작성 후**: feature_map.yaml 업데이트 (files_modified, files_created)
3. **Iteration 완료 시**: status를 done으로 변경, 체크포인트 저장

## 컨텍스트 전파 규칙

현재 Feature Set 개발 시 참조할 컨텍스트:
- 현재 Set의 `business_context`, `design_context`
- 선행 Set들의 `implementation_context` (수정/생성된 파일 목록)
```

---

## Phase 2: 슬래시 커맨드 구현 (Day 3-5)

### 2.1 /FDD (메인 라우터)

```markdown
# commands/FDD.md

---
description: FDD Feature-Driven Development 워크플로우
argument_description: 서브커맨드 (init|design|plan|develop|status|resume)
---

# FDD

Feature-Driven Development 워크플로우를 실행합니다.

## 사용법

```
/FDD <subcommand> [arguments]
```

## 서브커맨드

| 커맨드 | 설명 |
|--------|------|
| `init` | 프로젝트 초기화 |
| `design <요구사항>` | Phase 1: 설계 문서 생성 |
| `plan` | Phase 2: Feature Map 생성 |
| `develop` | Phase 3: Iterative 개발 |
| `status` | 현재 상태 확인 |
| `resume [checkpoint]` | 체크포인트에서 재개 |
| `run <요구사항>` | 전체 워크플로우 실행 |

## 실행

$ARGUMENTS를 파싱하여 해당 서브커맨드의 슬래시 커맨드를 호출하세요:

- `init` → `/FDD-init` 실행
- `design <req>` → `/FDD-design` 실행 (요구사항 전달)
- `plan` → `/FDD-plan` 실행
- `develop` → `/FDD-develop` 실행
- `status` → `/FDD-status` 실행
- `resume [cp]` → `/FDD-resume` 실행
- `run <req>` → design → plan → develop 순차 실행

서브커맨드가 없으면 사용법을 출력하세요.
```

### 2.2 /FDD-init

```markdown
# commands/FDD-init.md

---
description: FDD 프로젝트 초기화
---

# FDD 초기화

## 실행 내용

1. `.FDD/` 디렉토리 확인 및 생성
2. `config.yaml` 프로젝트명 설정
3. `feature_map.yaml` 타임스탬프 설정
4. CLAUDE.md FDD 섹션 확인

## 단계별 실행

### Step 1: 디렉토리 확인

`.FDD/` 디렉토리가 있는지 확인하세요.
있다면 이미 초기화된 것입니다.

```bash
ls -la .FDD/
```

### Step 2: 프로젝트명 확인

사용자에게 프로젝트명을 질문하세요:

```
AskUserQuestion:
  header: "프로젝트명"
  question: "이 프로젝트의 이름은 무엇인가요?"
  options:
    - label: "package.json에서 가져오기"
      description: "package.json의 name 필드 사용"
    - label: "디렉토리명 사용"
      description: "현재 디렉토리명을 프로젝트명으로 사용"
```

### Step 3: config.yaml 업데이트

`.FDD/config.yaml` 파일을 읽고 project.name을 업데이트하세요.

### Step 4: feature_map.yaml 초기화

`.FDD/feature_map.yaml` 파일을 읽고 다음을 업데이트:
- `meta.project_name`: 프로젝트명
- `meta.created_at`: 현재 타임스탬프 (ISO8601)
- `meta.updated_at`: 현재 타임스탬프

### Step 5: CLAUDE.md 확인

CLAUDE.md 파일에 "FDD Workflow" 섹션이 있는지 확인하세요.
없다면 사용자에게 알려주세요.

### Step 6: 완료 메시지

```
✓ FDD 초기화 완료

프로젝트: {project_name}
설정 파일: .FDD/config.yaml
상태 파일: .FDD/feature_map.yaml

다음 단계:
  /FDD design "요구사항 설명"
```
```

### 2.3 /FDD-design

```markdown
# commands/FDD-design.md

---
description: Phase 1 - 설계 문서 생성
argument_description: 자연어 요구사항 또는 요구사항 파일 경로
---

# FDD Phase 1: 설계 문서 생성

## 입력

$ARGUMENTS: 자연어 요구사항 텍스트 또는 파일 경로

파일 경로인 경우 (`.md`, `.txt` 등으로 끝나면) 파일을 읽어서 요구사항을 추출하세요.

## 워크플로우

### Step 1: Requirements Scout

Task 도구를 사용하여 요구사항 분석 에이전트를 호출하세요:

```yaml
Task:
  description: "요구사항 분석"
  subagent_type: "Explore"
  prompt: |
    다음 요구사항을 분석하세요:

    ---
    $REQUIREMENTS
    ---

    수행할 작업:
    1. 요구사항의 모순/결함 탐지
    2. 불명확한 부분 식별 (있다면 목록화)
    3. 구조화된 요구사항 문서 생성

    출력 형식 (YAML):
    ```yaml
    structured_requirements:
      summary: "프로젝트 요약"
      functional_requirements:
        - id: "FR-001"
          description: "기능 설명"
          priority: high|medium|low
      non_functional_requirements:
        - id: "NFR-001"
          description: "비기능 요구사항"
      ambiguities:
        - "불명확한 부분 1"
      contradictions:
        - "모순점 1"
    ```
```

### Step 2: 모호성 해결 (선택적)

ambiguities 목록이 있다면, AskUserQuestion으로 명확화를 요청하세요:

```yaml
AskUserQuestion:
  header: "요구사항 명확화"
  question: "다음 부분을 명확히 해주세요: {ambiguity}"
  options:
    - label: "옵션 A"
      description: "..."
    - label: "옵션 B"
      description: "..."
```

### Step 3: Business Analyst

Task 도구를 사용하여 비즈니스 분석 에이전트를 호출하세요:

```yaml
Task:
  description: "비즈니스 분석"
  subagent_type: "general-purpose"
  prompt: |
    구조화된 요구사항을 바탕으로 비즈니스 스펙을 생성하세요:

    ---
    $STRUCTURED_REQUIREMENTS
    ---

    수행할 작업:
    1. 비즈니스 워크플로우 정의
    2. 사용자 스토리 작성
    3. 수용 기준(Acceptance Criteria) 작성

    출력 형식 (YAML):
    ```yaml
    business_spec:
      workflows:
        - id: "WF-001"
          name: "워크플로우 이름"
          description: "설명"
          steps:
            - "단계 1"
            - "단계 2"
      user_stories:
        - id: "US-001"
          as_a: "사용자 역할"
          i_want: "원하는 것"
          so_that: "이유"
          acceptance_criteria:
            - "기준 1"
            - "기준 2"
    ```
```

### Step 4: Architect

Task 도구를 사용하여 아키텍처 설계 에이전트를 호출하세요:

```yaml
Task:
  description: "아키텍처 설계"
  subagent_type: "general-purpose"
  prompt: |
    비즈니스 스펙을 바탕으로 시스템 설계를 생성하세요:

    ---
    $BUSINESS_SPEC
    ---

    수행할 작업:
    1. UI 컴포넌트 설계 (coarse-grained)
       - 각 컴포넌트에 고유 ID 부여 (ui-xxx 형식)
    2. 데이터 모델 설계
       - 각 모델에 고유 ID 부여 (model-xxx 형식)
    3. 모듈 구조 설계
    4. 기술 스택 결정

    출력 형식 (YAML):
    ```yaml
    design_document:
      summary: "시스템 요약"
      ui_components:
        - id: "ui-xxx"
          name: "ComponentName"
          description: "설명"
          children: []
      data_models:
        - id: "model-xxx"
          name: "ModelName"
          description: "설명"
          schema:
            field1: type
            field2: type
      modules:
        - name: "module-name"
          description: "모듈 설명"
          responsibilities:
            - "책임 1"
      tech_stack:
        frontend: ["React", "TypeScript"]
        backend: ["Node.js", "Express"]
        database: ["PostgreSQL"]
    ```

    중요: 모든 UI 컴포넌트와 데이터 모델에 고유 ID를 반드시 부여하세요.
    이 ID는 이후 Feature 정의에서 참조됩니다.
```

### Step 5: 설계 문서 저장

생성된 설계 문서를 `.FDD/design_document.yaml`에 저장하세요.

### Step 6: 승인 게이트

`.FDD/config.yaml`의 `gates.design_approval`을 확인하세요.

true인 경우:

```yaml
AskUserQuestion:
  header: "설계 승인"
  question: "생성된 설계 문서를 승인하시겠습니까?"
  options:
    - label: "승인"
      description: "설계를 승인하고 Feature Map 생성으로 진행"
    - label: "수정 요청"
      description: "수정이 필요한 부분 지정"
    - label: "거부"
      description: "설계를 거부하고 처음부터 다시"
```

승인 시 완료 메시지 출력:

```
✓ Phase 1 완료: 설계 문서 생성

저장 위치: .FDD/design_document.yaml

다음 단계:
  /FDD plan
```
```

### 2.4 /FDD-plan

```markdown
# commands/FDD-plan.md

---
description: Phase 2 - Feature Map 생성
---

# FDD Phase 2: Feature Map 생성

## 전제조건

`.FDD/design_document.yaml` 파일이 존재해야 합니다.
없다면 먼저 `/FDD design`을 실행하라고 안내하세요.

## 워크플로우

### Step 1: 설계 문서 로드

`.FDD/design_document.yaml`을 읽으세요.

### Step 2: Feature Extractor

Task 도구를 사용하여 Feature 추출 에이전트를 호출하세요:

```yaml
Task:
  description: "Feature 추출"
  subagent_type: "general-purpose"
  prompt: |
    설계 문서에서 Feature를 추출하세요:

    ---
    $DESIGN_DOCUMENT
    ---

    Feature 정의:
    - 사용자 가치 단위의 기능
    - 1-2주 내 구현 가능한 크기
    - 독립적으로 테스트 가능

    각 Feature에 대해 작성:

    ```yaml
    features:
      - id: "feat-xxx"
        name: "기능명"
        business_workflow: "연관된 워크플로우 ID 또는 설명"
        business_rules:
          - "규칙 1"
        ui_flow: "UI 상호작용 흐름 (ui-xxx ID 참조)"
        data_flow: "데이터 처리 흐름 (model-xxx ID 참조)"
        components:
          - "ui-xxx"
        models:
          - "model-xxx"
        acceptance_criteria:
          - "수용 기준 1"
          - "수용 기준 2"
    ```

    중요:
    - ui_flow와 data_flow에서 설계 문서의 컴포넌트/모델 ID를 참조하세요
    - components와 models에 관련 ID를 명시하세요
```

### Step 3: Feature Planner

Task 도구를 사용하여 Feature Map 생성 에이전트를 호출하세요:

```yaml
Task:
  description: "Feature Map 생성"
  subagent_type: "general-purpose"
  prompt: |
    Feature 목록을 분석하여 Feature Map을 생성하세요:

    ---
    $FEATURES
    ---

    설정:
    - max_feature_sets: $MAX_FEATURE_SETS (config.yaml에서)

    수행할 작업:
    1. Feature 간 의존성 분석
       - 비즈니스 의존성: A 기능이 B 기능 전에 필요한가?
       - 기술 의존성: A 구현이 B 구현에 필요한 코드를 생성하는가?
    2. 응집도 높은 Feature Set 구성
       - 같은 모듈/컴포넌트를 공유하는 Feature들을 묶기
       - 한 iteration에 구현 가능한 크기로 제한
    3. Feature Set 간 DAG 생성
       - depends_on 관계 설정
       - 순환 의존성 불가

    출력 형식:

    ```yaml
    feature_sets:
      - id: "set-xxx"
        title: "Feature Set 제목"
        features: ["feat-xxx", "feat-yyy"]
        depends_on: []
        business_context:
          scope: "범위 설명"
          user_stories: ["US-xxx"]
        design_context:
          ui_components: ["ui-xxx"]
          data_models: ["model-xxx"]
          architectural_notes: ["메모"]
    ```

    규칙:
    - Feature A가 B에 의존하면, A는 B와 같은 Set이거나 후행 Set에 있어야 함
    - 순환 의존성은 허용되지 않음 (DAG 유지)
    - 최대 $MAX_FEATURE_SETS개의 Set으로 제한
```

### Step 4: Feature Map 저장

`.FDD/feature_map.yaml`을 업데이트하세요:

1. `design_summary` 섹션 채우기 (설계 문서에서)
2. `feature_map.nodes` 채우기 (생성된 Feature Set들)
3. 각 노드의 `implementation_context.status`를 "todo"로 설정
4. `execution_state` 초기화:
   - `pending_sets`: 모든 Feature Set ID
   - `completed_sets`: []
   - `in_progress_sets`: []
5. `meta.updated_at` 업데이트

### Step 5: 실행 계획 표시

DAG를 분석하여 실행 계획을 표시하세요:

```
Feature Map 생성 완료

실행 계획:
┌─────────────────────────────────────────────────────┐
│ Level 0: [set-auth, set-data]      (병렬 2개)       │
│     ↓                                               │
│ Level 1: [set-profile]             (set-auth 후)   │
│     ↓                                               │
│ Level 2: [set-reports]             (profile, data) │
└─────────────────────────────────────────────────────┘

총 Feature Sets: 4
총 Features: 12
예상 Iterations: 4
```

### Step 6: 승인 게이트

`.FDD/config.yaml`의 `gates.feature_map_approval`을 확인하세요.

true인 경우 사용자 승인 요청:

```yaml
AskUserQuestion:
  header: "Feature Map 승인"
  question: "생성된 Feature Map을 승인하시겠습니까?"
  options:
    - label: "승인"
      description: "Feature Map을 승인하고 개발로 진행"
    - label: "수정 요청"
      description: "Feature Set 구성 수정"
    - label: "거부"
      description: "Feature Map 재생성"
```

승인 시:

```
✓ Phase 2 완료: Feature Map 생성

저장 위치: .FDD/feature_map.yaml

다음 단계:
  /FDD develop
```
```

### 2.5 /FDD-develop

```markdown
# commands/FDD-develop.md

---
description: Phase 3 - Iterative Development
---

# FDD Phase 3: Iterative Development

## 전제조건

`.FDD/feature_map.yaml`에 pending 상태의 Feature Set이 있어야 합니다.

## 메인 루프

```
while (pending 또는 in_progress sets exist):
  1. 실행 가능한 Feature Set 식별
  2. 병렬/순차 개발 실행
  3. 상태 업데이트
  4. 체크포인트 저장
```

## 워크플로우

### Step 1: Feature Map 로드 및 상태 확인

`.FDD/feature_map.yaml`을 읽고 현재 상태를 확인하세요:

```
current_status:
  completed: [set-auth]
  in_progress: []
  pending: [set-profile, set-reports]
  blocked: []
```

### Step 2: 실행 가능 노드 식별

다음 조건을 만족하는 Feature Set을 찾으세요:
- `status == "todo"`
- `depends_on`의 모든 Set이 `status == "done"`

```python
def get_executable_sets():
    executable = []
    for node in feature_map.nodes:
        if node.implementation_context.status != "todo":
            continue
        deps_done = all(
            get_node(dep).implementation_context.status == "done"
            for dep in node.depends_on
        )
        if deps_done:
            executable.append(node)
    return executable[:max_parallel]
```

### Step 3: 병렬/순차 실행 결정

executable_sets의 개수에 따라:

- **1개**: 순차 실행
- **2개 이상**: 병렬 실행 (max_parallel 제한 내에서)

### Step 4: 단일 Feature Set 개발 (Iteration)

각 Feature Set에 대해 다음을 순차 실행:

#### 4.1 상태 업데이트

```yaml
# feature_map.yaml 업데이트
implementation_context:
  status: "in_progress"
  started_at: "$CURRENT_TIMESTAMP"
```

#### 4.2 컨텍스트 조립

현재 Feature Set 개발에 필요한 컨텍스트를 조립하세요:

1. **현재 Set의 컨텍스트**:
   - `business_context`
   - `design_context`
   - `features` 목록

2. **선행 Set들의 컨텍스트**:
   - `implementation_context.files_modified`
   - `implementation_context.files_created`

3. **설계 문서에서 관련 부분**:
   - 참조된 `ui_components` 상세
   - 참조된 `data_models` 상세

#### 4.3 Chief Programmer

```yaml
Task:
  description: "상세 설계 - $FEATURE_SET_ID"
  subagent_type: "general-purpose"
  prompt: |
    Feature Set을 분석하고 상세 설계를 생성하세요:

    ## Feature Set 정보
    $FEATURE_SET_YAML

    ## 선행 Set 구현 정보
    $PREDECESSOR_CONTEXT

    ## 설계 문서 (관련 부분)
    $DESIGN_EXCERPT

    수행할 작업:
    1. Feature 간 관계 분석
    2. 세부 설계 결정 (어떤 파일에 어떤 코드)
    3. 작업 계획 생성 (순서, 의존성)

    출력:
    ```yaml
    detailed_design:
      overview: "구현 개요"
      files_to_create:
        - path: "src/xxx/yyy.ts"
          purpose: "용도"
          key_exports: ["export1", "export2"]
      files_to_modify:
        - path: "src/existing.ts"
          changes: "변경 내용"
      implementation_order:
        - step: 1
          description: "데이터 모델 생성"
          files: ["src/models/xxx.ts"]
        - step: 2
          description: "API 엔드포인트 구현"
          files: ["src/api/xxx.ts"]
    ```
```

상세 설계를 `.FDD/iterations/{set-id}/detailed_design.yaml`에 저장하세요.

#### 4.4 Programmer

```yaml
Task:
  description: "코드 구현 - $FEATURE_SET_ID"
  subagent_type: "general-purpose"
  prompt: |
    상세 설계에 따라 코드를 구현하세요:

    ## 상세 설계
    $DETAILED_DESIGN

    ## 수용 기준
    $ACCEPTANCE_CRITERIA

    수행할 작업:
    1. implementation_order에 따라 순차 구현
    2. 각 파일 작성 시 Write/Edit 도구 사용
    3. 빌드 오류 발생 시 수정

    주의사항:
    - 각 파일 수정 후 품질 검사 훅이 자동 실행됩니다
    - 훅 실패 시 오류 메시지를 확인하고 수정하세요
    - 모든 수용 기준을 충족하도록 구현하세요

    완료 시 다음을 출력:
    ```yaml
    implementation_result:
      status: "complete"
      files_created: [...]
      files_modified: [...]
      notes: "구현 노트"
    ```
```

#### 4.5 Reviewer

```yaml
Task:
  description: "코드 리뷰 - $FEATURE_SET_ID"
  subagent_type: "general-purpose"
  prompt: |
    구현된 코드를 검토하세요:

    ## Feature Set
    $FEATURE_SET_YAML

    ## 수용 기준
    $ACCEPTANCE_CRITERIA

    ## 변경된 파일
    $FILES_CHANGED

    검토 항목:
    1. 수용 기준 충족 여부 (각 기준별 pass/fail)
    2. 코드 품질 (가독성, 유지보수성)
    3. 잠재적 버그
    4. 보안 취약점

    출력:
    ```yaml
    review_result:
      status: "passed" | "needs_revision" | "failed"
      acceptance_criteria_check:
        - criterion: "기준 1"
          status: "pass"
        - criterion: "기준 2"
          status: "fail"
          reason: "이유"
      issues:
        - severity: "high" | "medium" | "low"
          file: "path/to/file"
          line: 42
          description: "문제 설명"
      suggestions:
        - "개선 제안 1"
    ```
```

리뷰 결과를 `.FDD/iterations/{set-id}/review_result.yaml`에 저장하세요.

#### 4.6 상태 최종 업데이트

리뷰 통과 시:

```yaml
implementation_context:
  status: "done"
  completed_at: "$CURRENT_TIMESTAMP"
  files_modified: [...]
  files_created: [...]
```

리뷰 실패 시:
- `needs_revision`: Programmer에게 수정 요청 후 재리뷰
- `failed`: status를 "blocked"로 설정, 사용자에게 알림

### Step 5: 병렬 실행 (2개 이상인 경우)

실행 가능한 Set이 여러 개인 경우, 단일 응답에서 여러 Task를 호출하세요:

```
# 예: set-auth와 set-data가 둘 다 실행 가능한 경우

동시에 두 Task 호출:
- Task 1: develop_iteration("set-auth")
- Task 2: develop_iteration("set-data")
```

Claude Code는 이를 병렬로 처리합니다.

### Step 6: 체크포인트 저장

각 Feature Set 완료 후:

1. `.FDD/feature_map.yaml` 저장
2. 체크포인트 생성:
   ```bash
   bash .FDD/hooks/iteration-complete.sh "$FEATURE_SET_ID"
   ```

### Step 7: 다음 Iteration

모든 실행 가능한 Set이 완료되면:
- Step 2로 돌아가 다음 실행 가능 노드 확인
- 더 이상 실행 가능한 노드가 없으면 완료

### Step 8: 완료

모든 Feature Set이 done 상태가 되면:

```
✓ Phase 3 완료: Iterative Development

결과:
- 완료된 Feature Sets: 4/4
- 생성된 파일: 15
- 수정된 파일: 8

체크포인트: .FDD/checkpoints/latest

로그: .FDD/logs/events.jsonl
```
```

### 2.6 /FDD-status

```markdown
# commands/FDD-status.md

---
description: FDD 현재 상태 확인
---

# FDD 상태 확인

## 실행 내용

`.FDD/feature_map.yaml`을 읽어 현재 상태를 표시합니다.

## 출력 형식

```
┌─────────────────────────────────────────────────────────────┐
│                    FDD Status                            │
├─────────────────────────────────────────────────────────────┤
│ Project: $PROJECT_NAME                                      │
│ Phase: $CURRENT_PHASE                                       │
│ Last Updated: $UPDATED_AT                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Feature Map:                                                │
│ ┌───────────────┬──────────────┬──────────┬──────────────┐ │
│ │ Feature Set   │ Status       │ Features │ Depends On   │ │
│ ├───────────────┼──────────────┼──────────┼──────────────┤ │
│ │ set-auth      │ ✓ done       │ 3        │ -            │ │
│ │ set-data      │ ✓ done       │ 2        │ -            │ │
│ │ set-profile   │ → in_progress│ 2        │ set-auth     │ │
│ │ set-reports   │ ○ pending    │ 4        │ profile,data │ │
│ └───────────────┴──────────────┴──────────┴──────────────┘ │
│                                                             │
│ Progress: 2/4 Feature Sets (50%)                           │
│ ████████████░░░░░░░░░░░░                                   │
│                                                             │
│ Next executable: [set-reports] (after set-profile)         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ Checkpoints:                                                │
│   • iteration_1 (2024-01-15 10:30)                         │
│   • iteration_2 (2024-01-15 11:45) ← latest                │
└─────────────────────────────────────────────────────────────┘
```

## Status 아이콘

- `✓` done
- `→` in_progress
- `○` pending
- `✗` blocked

## 추가 정보

`/FDD status --verbose` 시 각 Feature Set의 상세 정보도 표시:
- 포함된 Features 목록
- 수정/생성된 파일 목록
- 수용 기준 충족 현황
```

### 2.7 /FDD-resume

```markdown
# commands/FDD-resume.md

---
description: 체크포인트에서 재개
argument_description: 체크포인트 이름 (생략 시 latest)
---

# FDD 체크포인트에서 재개

## 사용법

```
/FDD resume [checkpoint_name]
```

- checkpoint_name 생략 시 `latest` 사용

## 워크플로우

### Step 1: 체크포인트 목록 확인

```bash
ls -la .FDD/checkpoints/
```

### Step 2: 체크포인트 로드

$ARGUMENTS가 있으면 해당 체크포인트, 없으면 `latest` 심볼릭 링크 따라가기.

### Step 3: Feature Map 복원

체크포인트 파일을 `.FDD/feature_map.yaml`로 복사하세요.

### Step 4: 상태 확인

```
체크포인트 복원 완료: $CHECKPOINT_NAME

복원된 상태:
- 완료: [set-auth, set-data]
- 진행중: []
- 대기: [set-profile, set-reports]

이어서 개발을 진행합니다...
```

### Step 5: /FDD-develop 호출

자동으로 `/FDD-develop`를 실행하여 개발을 재개하세요.
```

---

## Phase 3: 훅 스크립트 구현 (Day 6-7)

### 3.1 품질 검사 훅

```bash
#!/bin/bash
# hooks/quality-check.sh

set -e

FILE_PATH="$1"
FDD_DIR=".FDD"
CONFIG_FILE="$FDD_DIR/config.yaml"
LOG_FILE="$FDD_DIR/logs/audit.jsonl"

# 타임스탬프
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 로그 함수
log_event() {
    local action="$1"
    local status="$2"
    local details="$3"
    echo "{\"ts\":\"$TS\",\"action\":\"$action\",\"status\":\"$status\",\"file\":\"$FILE_PATH\",\"details\":\"$details\"}" >> "$LOG_FILE"
}

echo "=== FDD Quality Check ==="
echo "File: $FILE_PATH"
echo "Time: $TS"
echo ""

# 파일 확장자 확인
EXT="${FILE_PATH##*.}"

# TypeScript/JavaScript 파일인 경우만 검사
if [[ "$EXT" != "ts" && "$EXT" != "tsx" && "$EXT" != "js" && "$EXT" != "jsx" ]]; then
    echo "→ Skipping non-JS/TS file"
    exit 0
fi

FAILED=0

# 1. ESLint (있는 경우)
if [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
    echo "→ Running ESLint..."
    if npm run lint -- "$FILE_PATH" 2>&1; then
        echo "✓ Lint passed"
        log_event "lint" "passed" ""
    else
        echo "✗ Lint failed"
        log_event "lint" "failed" "ESLint errors"
        FAILED=1
    fi
fi

# 2. TypeScript 검사
if [ -f "tsconfig.json" ]; then
    echo "→ Running TypeScript check..."
    if npx tsc --noEmit 2>&1; then
        echo "✓ TypeScript passed"
        log_event "typecheck" "passed" ""
    else
        echo "✗ TypeScript failed"
        log_event "typecheck" "failed" "Type errors"
        FAILED=1
    fi
fi

# 3. 빌드 (설정된 경우)
if [ -f "package.json" ] && grep -q '"build"' package.json 2>/dev/null; then
    echo "→ Running build..."
    if npm run build 2>&1; then
        echo "✓ Build passed"
        log_event "build" "passed" ""
    else
        echo "✗ Build failed"
        log_event "build" "failed" "Build errors"
        FAILED=1
    fi
fi

echo ""

if [ $FAILED -eq 0 ]; then
    echo "=== Quality Check Passed ==="
    exit 0
else
    echo "=== Quality Check Failed ==="
    exit 1
fi
```

### 3.2 Iteration 완료 훅

```bash
#!/bin/bash
# hooks/iteration-complete.sh

set -e

FEATURE_SET_ID="$1"
FDD_DIR=".FDD"
CHECKPOINT_DIR="$FDD_DIR/checkpoints"
LOG_FILE="$FDD_DIR/logs/events.jsonl"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Iteration Complete: $FEATURE_SET_ID ==="
echo "Time: $TS"
echo ""

# 이벤트 로그
echo "{\"ts\":\"$TS\",\"event\":\"iteration_completed\",\"data\":{\"set\":\"$FEATURE_SET_ID\"}}" >> "$LOG_FILE"

# 테스트 실행 (설정된 경우)
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    echo "→ Running tests..."
    if npm test 2>&1; then
        echo "✓ All tests passed"
        echo "{\"ts\":\"$TS\",\"event\":\"tests_passed\",\"data\":{\"set\":\"$FEATURE_SET_ID\"}}" >> "$LOG_FILE"
    else
        echo "⚠ Some tests failed"
        echo "{\"ts\":\"$TS\",\"event\":\"tests_failed\",\"data\":{\"set\":\"$FEATURE_SET_ID\"}}" >> "$LOG_FILE"
    fi
fi

# 체크포인트 저장
mkdir -p "$CHECKPOINT_DIR"
CHECKPOINT_FILE="$CHECKPOINT_DIR/iteration_${FEATURE_SET_ID}_${TIMESTAMP}.yaml"

cp "$FDD_DIR/feature_map.yaml" "$CHECKPOINT_FILE"
echo "✓ Checkpoint saved: $CHECKPOINT_FILE"

# latest 심볼릭 링크 업데이트
cd "$CHECKPOINT_DIR"
rm -f latest
ln -s "$(basename "$CHECKPOINT_FILE")" latest
cd - > /dev/null

echo ""
echo "=== Iteration Complete ==="
```

### 3.3 Pre-commit 훅 (선택적)

```bash
#!/bin/bash
# hooks/pre-commit.sh

set -e

FDD_DIR=".FDD"

echo "=== FDD Pre-commit Check ==="

# Feature Map 상태 확인
if [ -f "$FDD_DIR/feature_map.yaml" ]; then
    # blocked 상태가 있는지 확인
    if grep -q "status: blocked" "$FDD_DIR/feature_map.yaml"; then
        echo "⚠ Warning: There are blocked Feature Sets"
        echo "  Run '/FDD status' to see details"
    fi

    # in_progress 상태가 있는지 확인
    if grep -q "status: in_progress" "$FDD_DIR/feature_map.yaml"; then
        echo "⚠ Warning: There are in-progress Feature Sets"
        echo "  Consider completing them before committing"
    fi
fi

echo "✓ Pre-commit check passed"
exit 0
```

---

## Phase 4: 템플릿 및 문서 (Day 8)

### 4.1 settings.json 템플릿

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": {
          "tool_name": ["Write", "Edit"]
        },
        "hooks": [
          {
            "type": "command",
            "command": "bash .FDD/hooks/quality-check.sh \"$CLAUDE_TOOL_USE_FILE_PATH\"",
            "timeout": 120000
          }
        ]
      }
    ]
  },

  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(bash .FDD/hooks/*)",
      "Read(.FDD/**)",
      "Write(.FDD/**)",
      "Edit(.FDD/**)"
    ]
  }
}
```

### 4.2 README.md

```markdown
# FDD

Claude Code 환경에서 사용하는 Feature-Driven Development 프레임워크

## 설치

```bash
git clone https://github.com/xxx/FDD.git
cd your-project
bash /path/to/FDD/install.sh .
```

## 사용법

```bash
# Claude Code 시작
claude

# 프로젝트 초기화
> /FDD init

# 전체 워크플로우 실행
> /FDD run "사용자 인증 시스템 구현"

# 또는 단계별 실행
> /FDD design "요구사항 설명"
> /FDD plan
> /FDD develop

# 상태 확인
> /FDD status

# 체크포인트에서 재개
> /FDD resume
```

## 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/FDD init` | 프로젝트 초기화 |
| `/FDD design <req>` | 설계 문서 생성 |
| `/FDD plan` | Feature Map 생성 |
| `/FDD develop` | Iterative 개발 |
| `/FDD status` | 상태 확인 |
| `/FDD resume` | 재개 |

## 라이선스

MIT
```

---

## 구현 일정 요약

| Day | 작업 | 산출물 |
|-----|------|--------|
| 1-2 | 기본 인프라 | install.sh, templates/ |
| 3-5 | 슬래시 커맨드 | commands/*.md |
| 6-7 | 훅 스크립트 | hooks/*.sh |
| 8 | 문서화 | README.md |
| 9-10 | 품질 검사 모듈 | Validator, Improver, 검증 규칙 |
| 11-12 | 통합 및 테스트 | E2E 테스트, 품질 검사 테스트 |

---

## Phase 5: 중간 산출물 품질 검사 모듈 (Day 9-10)

### 5.1 Validator 슬래시 커맨드 추가

각 산출물 검증을 위한 내부 커맨드를 추가합니다.

```markdown
# commands/internal/validate-artifact.md

---
description: 산출물 품질 검증 (내부용)
---

# 산출물 검증

## 입력

- $ARTIFACT_TYPE: requirements | design_document | feature_map | detailed_design
- $ARTIFACT_CONTENT: 검증할 산출물 YAML

## 검증 규칙 로드

`.FDD/config.yaml`에서 해당 validator 설정을 로드합니다.

## 검증 실행

Task 도구를 사용하여 검증 에이전트를 호출합니다:

```yaml
Task:
  description: "$ARTIFACT_TYPE 검증"
  subagent_type: "general-purpose"
  prompt: |
    다음 $ARTIFACT_TYPE을(를) 검증하세요:

    ## 산출물
    ```yaml
    $ARTIFACT_CONTENT
    ```

    ## 검증 규칙
    $VALIDATION_RULES

    ## 출력 형식
    ```yaml
    validation_result:
      status: "passed" | "failed"
      errors: [...]
      warnings: [...]
      summary:
        total_checks: N
        passed: N
        errors: N
        warnings: N
    ```
```

## 출력

검증 결과를 YAML 형식으로 반환합니다.
```

### 5.2 Improver 슬래시 커맨드 추가

```markdown
# commands/internal/improve-artifact.md

---
description: 산출물 개선 (내부용)
---

# 산출물 개선

## 입력

- $ARTIFACT_TYPE: 산출물 유형
- $ORIGINAL_ARTIFACT: 원본 산출물
- $VALIDATION_RESULT: 검증 결과

## 개선 실행

Task 도구를 사용하여 개선 에이전트를 호출합니다:

```yaml
Task:
  description: "$ARTIFACT_TYPE 개선"
  subagent_type: "general-purpose"
  prompt: |
    $ARTIFACT_TYPE에서 품질 검사 오류가 발견되었습니다.
    오류를 수정하세요.

    ## 원본
    ```yaml
    $ORIGINAL_ARTIFACT
    ```

    ## 검증 결과
    ```yaml
    $VALIDATION_RESULT
    ```

    ## 수정 지침
    - 각 error를 반드시 수정
    - warning은 가능하면 개선
    - 원본 구조 유지

    ## 출력
    수정된 전체 산출물 (YAML)
```

## 출력

개선된 산출물을 YAML 형식으로 반환합니다.
```

### 5.3 품질 루프 헬퍼 함수

슬래시 커맨드 내에서 재사용할 수 있는 품질 검사 루프 패턴:

```markdown
# 품질 검사 루프 패턴 (슬래시 커맨드 내 사용)

## 사용법

각 산출물 생성 단계에서 다음 패턴을 적용합니다:

```
# 1. 설정 로드
config = Read(".FDD/config.yaml")
max_iterations = config.quality_check.artifacts.max_improvement_iterations
require_approval = config.quality_check.artifacts.require_human_approval_on_fail

# 2. 품질 검사 루프
artifact = generated_artifact
iteration = 1

while iteration <= max_iterations:

    # 2.1 검증
    validation_result = Task(Validator, artifact)

    # 2.2 통과 시 종료
    if validation_result.status == "passed":
        Log("검증 통과", iteration)
        break

    # 2.3 마지막 반복이면 종료
    if iteration == max_iterations:
        Log("최대 반복 도달", iteration)
        break

    # 2.4 개선
    artifact = Task(Improver, artifact, validation_result)
    iteration += 1

# 3. 최종 처리
if validation_result.status == "failed":
    if require_approval:
        approval = AskUserQuestion("검증 실패. 진행할까요?")
        if approval == "중단":
            return ERROR
    else:
        mark_blocked()
        return ERROR

# 4. 저장
Write(artifact_path, artifact)
Log("저장 완료", artifact_path)
```
```

### 5.4 슬래시 커맨드 수정

기존 슬래시 커맨드에 품질 검사 루프를 통합합니다.

#### /FDD-design 수정

```markdown
# commands/FDD-design.md (수정)

## Step 1: Requirements Scout
(기존 내용)

### Step 1.1: 요구사항 검증 루프
```
# 품질 검사 루프 적용
artifact = structured_requirements
artifact_type = "requirements"

(위의 품질 검사 루프 패턴 적용)
```

## Step 2: Business Analyst
(기존 내용)

### Step 2.1: 비즈니스 스펙 검증 루프
```
artifact = business_spec
artifact_type = "business_spec"

(품질 검사 루프 패턴 적용)
```

## Step 3: Architect
(기존 내용)

### Step 3.1: 설계 문서 검증 루프
```
artifact = design_document
artifact_type = "design_document"

(품질 검사 루프 패턴 적용)
```
```

#### /FDD-plan 수정

```markdown
# commands/FDD-plan.md (수정)

## Step 1: Feature Extractor
(기존 내용)

### Step 1.1: Feature 목록 검증 루프
```
artifact = feature_list
artifact_type = "feature_list"

(품질 검사 루프 패턴 적용)
```

## Step 2: Feature Planner
(기존 내용)

### Step 2.1: Feature Map 검증 루프
```
artifact = feature_map
artifact_type = "feature_map"

(품질 검사 루프 패턴 적용)
```
```

#### /FDD-develop 수정

```markdown
# commands/FDD-develop.md (수정)

## Iteration 내부: Chief Programmer
(기존 내용)

### Chief Programmer 후: 상세 설계 검증 루프
```
artifact = detailed_design
artifact_type = "detailed_design"

(품질 검사 루프 패턴 적용)
```
```

### 5.5 검증 규칙 템플릿

```yaml
# templates/validation_rules.yaml

requirements:
  error:
    - check: completeness
      rule: "summary와 functional_requirements 섹션 필수"
    - check: consistency
      rule: "요구사항 간 모순 없음"
  warning:
    - check: clarity
      rule: "각 요구사항이 측정 가능해야 함"
    - check: priority
      rule: "모든 요구사항에 우선순위 필요"

design_document:
  error:
    - check: id_uniqueness
      rule: "모든 ID가 고유해야 함"
      pattern: "ui-*, model-*"
    - check: id_format
      rule: "ID가 ui-xxx 또는 model-xxx 형식"
    - check: reference_integrity
      rule: "참조된 ID가 존재해야 함"
    - check: completeness
      rule: "ui_components, data_models, modules, tech_stack 필수"
    - check: model_schema
      rule: "모든 데이터 모델에 스키마 정의"
  warning:
    - check: tech_stack_validity
      rule: "기술 스택 호환성"
    - check: component_coverage
      rule: "워크플로우의 UI 커버리지"

feature_map:
  error:
    - check: dag_validity
      rule: "순환 의존성 없음"
    - check: dependency_logic
      rule: "의존성 논리적"
    - check: id_reference
      rule: "components, models ID가 설계 문서에 존재"
    - check: acceptance_criteria
      rule: "모든 Feature에 수용 기준"
  warning:
    - check: feature_coverage
      rule: "요구사항 커버리지"
    - check: set_balance
      rule: "Feature Set 크기 균형 (±30%)"
    - check: max_sets
      rule: "max_feature_sets 이하"

detailed_design:
  error:
    - check: implementation_order
      rule: "구현 순서가 의존성 반영"
    - check: feature_coverage
      rule: "모든 Feature 구현 계획 포함"
  warning:
    - check: file_path
      rule: "파일 경로가 프로젝트 구조와 일치"
    - check: existing_file
      rule: "수정 대상 파일 존재"
    - check: key_exports
      rule: "주요 export 정의"
```

### 5.6 로깅 업데이트

```bash
# hooks/log-validation.sh

#!/bin/bash

ARTIFACT_TYPE="$1"
STATUS="$2"
ITERATION="$3"
ERRORS="$4"
WARNINGS="$5"

LOG_FILE=".FDD/logs/events.jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{\"ts\":\"$TS\",\"event\":\"validation_completed\",\"data\":{\"artifact\":\"$ARTIFACT_TYPE\",\"status\":\"$STATUS\",\"iteration\":$ITERATION,\"errors\":$ERRORS,\"warnings\":$WARNINGS}}" >> "$LOG_FILE"
```

---

## Phase 6: 통합 및 테스트 (Day 11-12)

### 6.1 전체 워크플로우 E2E 테스트

```markdown
# 테스트 시나리오

## 시나리오 1: 정상 흐름
1. /FDD init
2. /FDD design "간단한 TODO 앱"
3. /FDD plan
4. /FDD develop
5. /FDD status

기대 결과:
- 모든 단계 성공
- feature_map.yaml에 모든 Set이 done
- 코드 생성 완료

## 시나리오 2: 검증 실패 → 자동 개선
1. /FDD design (의도적으로 불완전한 요구사항)
2. 검증 실패 → Improver 호출 → 재검증

기대 결과:
- 최대 3회 반복 후 통과 또는 사용자 승인 요청

## 시나리오 3: 체크포인트 재개
1. /FDD develop (중간에 중단)
2. /FDD resume

기대 결과:
- 체크포인트에서 정확히 재개
- 완료된 Set은 건너뜀

## 시나리오 4: 병렬 실행
1. 독립적인 Feature Set 2개 이상
2. /FDD develop

기대 결과:
- 병렬 Task 호출 확인
- 상태 동기화 정상
```

### 6.2 품질 검사 테스트

```markdown
# 품질 검사 테스트 시나리오

## 테스트 1: ID 중복 감지 및 수정
- 입력: 중복 ID가 있는 설계 문서
- 기대: Validator가 중복 감지, Improver가 수정

## 테스트 2: DAG 순환 감지 및 수정
- 입력: A→B→C→A 순환이 있는 Feature Map
- 기대: Validator가 순환 감지, Improver가 재구성

## 테스트 3: 참조 무결성 오류 및 수정
- 입력: 존재하지 않는 ID 참조
- 기대: Validator가 감지, Improver가 추가 또는 수정

## 테스트 4: 최대 반복 도달
- 입력: 수정 불가능한 오류
- 기대: 3회 반복 후 사용자 승인 요청
```

---

## 검증 체크리스트

### 기능 검증

- [ ] `/FDD init` - 디렉토리 구조 생성
- [ ] `/FDD design` - 설계 문서 생성
- [ ] `/FDD plan` - Feature Map 생성
- [ ] `/FDD develop` - Iteration 실행
- [ ] `/FDD status` - 상태 표시
- [ ] `/FDD resume` - 체크포인트 복원

### 훅 검증

- [ ] Write/Edit 후 코드 품질 검사 자동 실행
- [ ] 검사 실패 시 피드백 전달
- [ ] Iteration 완료 시 체크포인트 저장

### 품질 검사 검증

- [ ] Requirements 검증 (완전성, 일관성)
- [ ] Design Document 검증 (ID 고유성, 참조 무결성)
- [ ] Feature Map 검증 (DAG 유효성, 의존성)
- [ ] Detailed Design 검증 (구현 순서, 커버리지)
- [ ] 검증 실패 시 Improver 자동 호출
- [ ] 최대 반복 후 사용자 승인 요청

### 병렬 실행 검증

- [ ] 독립적인 Feature Set 병렬 개발
- [ ] max_parallel 제한 적용
- [ ] 상태 동기화 정상 동작

### 통합 검증

- [ ] 전체 워크플로우 end-to-end
- [ ] 체크포인트에서 재개
- [ ] Human-in-the-loop 게이트
