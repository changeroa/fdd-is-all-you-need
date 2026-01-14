# FDD - Claude Code 내부 실행 방식

> Claude Code 환경 내에서 슬래시 커맨드 + CLAUDE.md + 훅으로 구현하는 Feature-Driven Development 프레임워크

---

## 철학: 반복 가능한 정밀성 (Repeatable Precision)

- **프로세스**로 품질을 보장한다
- Claude Code 자체가 오케스트레이터 역할
- 상태는 YAML 파일로 관리
- 훅으로 자동 품질 검사

---

## 1. 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────────┐
│                      Claude Code                                │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    /FDD 슬래시 커맨드                     │ │
│  │                           │                                 │ │
│  │                           ▼                                 │ │
│  │              ┌─────────────────────────┐                   │ │
│  │              │     CLAUDE.md           │                   │ │
│  │              │  (워크플로우 지침)        │                   │ │
│  │              └───────────┬─────────────┘                   │ │
│  │                          │                                  │ │
│  │            ┌─────────────┼─────────────┐                   │ │
│  │            ▼             ▼             ▼                   │ │
│  │      [Phase 1]     [Phase 2]     [Phase 3]                │ │
│  │      설계 생성      Feature Map   Iteration                │ │
│  │            │             │             │                   │ │
│  │            ▼             ▼             ▼                   │ │
│  │     Task 도구로 서브에이전트 호출 (병렬 가능)               │ │
│  │                          │                                  │ │
│  │                          ▼                                  │ │
│  │              ┌─────────────────────────┐                   │ │
│  │              │   .FDD/ 상태 파일     │                   │ │
│  │              │   feature_map.yaml      │                   │ │
│  │              └─────────────────────────┘                   │ │
│  │                          │                                  │ │
│  │                          ▼                                  │ │
│  │              ┌─────────────────────────┐                   │ │
│  │              │   PostToolUse 훅        │                   │ │
│  │              │   (자동 품질 검사)       │                   │ │
│  │              └─────────────────────────┘                   │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. 디렉토리 구조

```
project/
├── .claude/
│   ├── settings.json          # 훅 설정
│   └── commands/
│       ├── FDD.md          # /FDD 메인 커맨드
│       ├── FDD-init.md     # /FDD-init
│       ├── FDD-design.md   # /FDD-design
│       ├── FDD-plan.md     # /FDD-plan
│       ├── FDD-develop.md  # /FDD-develop
│       ├── FDD-status.md   # /FDD-status
│       └── FDD-resume.md   # /FDD-resume
│
├── .FDD/
│   ├── config.yaml            # 프로젝트 설정
│   ├── feature_map.yaml       # Feature Map (핵심 상태)
│   ├── design_document.yaml   # 설계 문서
│   ├── session_state.yaml     # 현재 세션 상태
│   │
│   ├── iterations/            # Iteration별 산출물
│   │   ├── set-auth/
│   │   │   ├── detailed_design.yaml
│   │   │   └── review_result.yaml
│   │   └── ...
│   │
│   ├── checkpoints/           # 체크포인트
│   │   └── ...
│   │
│   └── logs/
│       ├── events.jsonl
│       └── audit.jsonl
│
├── CLAUDE.md                  # 프로젝트 전역 지침
└── (프로젝트 소스 코드)
```

---

## 3. 슬래시 커맨드 정의

### 3.1 /FDD (메인 진입점)

```markdown
<!-- .claude/commands/FDD.md -->

# FDD - Feature-Driven Development

이 커맨드는 FDD 워크플로우를 실행합니다.

## 사용법

/FDD [subcommand] [options]

### 서브커맨드

- `init` - 프로젝트 초기화
- `design <requirements>` - 설계 문서 생성 (Phase 1)
- `plan` - Feature Map 생성 (Phase 2)
- `develop` - Iterative 개발 실행 (Phase 3)
- `run <requirements>` - 전체 워크플로우 실행
- `status` - 현재 상태 확인
- `resume [checkpoint]` - 체크포인트에서 재개

### 예시

```
/FDD init
/FDD run "사용자 인증 시스템 구현"
/FDD status
/FDD resume iteration_2
```

## 워크플로우 지침

$ARGUMENTS를 파싱하여 해당 서브커맨드를 실행하세요.
각 단계는 .FDD/ 디렉토리의 상태 파일을 읽고 업데이트합니다.

상세 지침은 CLAUDE.md의 [FDD Workflow] 섹션을 참조하세요.
```

### 3.2 /FDD-init

```markdown
<!-- .claude/commands/FDD-init.md -->

# FDD 프로젝트 초기화

## 실행 내용

1. `.FDD/` 디렉토리 구조 생성
2. `config.yaml` 기본 설정 생성
3. `feature_map.yaml` 빈 템플릿 생성
4. CLAUDE.md에 FDD 섹션 추가 (없는 경우)

## 생성할 파일들

### .FDD/config.yaml

```yaml
version: "1.0"
project:
  name: "$PROJECT_NAME"
  repo_path: "."

execution:
  max_parallel: 3
  max_feature_sets: 4

build_test:
  auto_build: true
  auto_test: true
  build_command: "npm run build"
  test_command: "npm test"
  retry:
    max_attempts: 3

gates:
  design_approval: true
  feature_map_approval: true
  iteration_approval: false

logging:
  level: "info"
```

### .FDD/feature_map.yaml

```yaml
meta:
  project_name: "$PROJECT_NAME"
  repo_path: "."
  created_at: "$TIMESTAMP"
  updated_at: "$TIMESTAMP"
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

## 실행

위 구조대로 파일들을 생성하세요. 이미 존재하는 파일은 덮어쓰지 마세요.
```

### 3.3 /FDD-design

```markdown
<!-- .claude/commands/FDD-design.md -->

# FDD Phase 1: 설계 문서 생성

## 입력

$ARGUMENTS: 자연어 요구사항 또는 요구사항 파일 경로

## 워크플로우

### Step 1: Requirements Scout

요구사항을 분석하고 구조화합니다.

**Task 에이전트 호출:**
```
subagent_type: Explore
prompt: |
  다음 요구사항을 분석하세요:

  $REQUIREMENTS

  수행할 작업:
  1. 요구사항의 모순/결함 탐지
  2. 불명확한 부분 식별
  3. 구조화된 요구사항 문서 생성

  출력 형식: YAML
```

### Step 2: Business Analyst

비즈니스 워크플로우와 가치를 정의합니다.

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  구조화된 요구사항을 바탕으로:

  $STRUCTURED_REQUIREMENTS

  수행할 작업:
  1. 비즈니스 워크플로우 정의
  2. 사용자 가치 분석
  3. 수용 기준 작성

  출력 형식: YAML (business_spec)
```

### Step 3: Architect

시스템 설계를 생성합니다.

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  비즈니스 스펙을 바탕으로:

  $BUSINESS_SPEC

  수행할 작업:
  1. UI 컴포넌트 설계 (coarse-grained, ID 부여)
  2. 데이터 모델 설계 (ID 부여)
  3. 모듈 구조 설계
  4. 기술 스택 결정

  출력 형식: YAML (design_document)

  중요: 각 UI 컴포넌트와 데이터 모델에 고유 ID를 부여하세요.
```

### Step 4: 저장 및 승인

1. `.FDD/design_document.yaml`에 설계 문서 저장
2. `gates.design_approval`이 true면 사용자 승인 요청

## 출력

- `.FDD/design_document.yaml` 생성/업데이트
- 승인 시 Phase 2로 진행 가능
```

### 3.4 /FDD-plan

```markdown
<!-- .claude/commands/FDD-plan.md -->

# FDD Phase 2: Feature Map 생성

## 전제조건

- `.FDD/design_document.yaml` 존재

## 워크플로우

### Step 1: Feature Extractor

설계 문서에서 Feature를 추출합니다.

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  설계 문서를 분석하여 Feature를 추출하세요:

  $DESIGN_DOCUMENT

  Feature 정의:
  - 사용자 가치 단위의 기능
  - 1-2주 내 구현 가능한 크기

  각 Feature에 대해 작성:
  - id: 고유 식별자
  - name: 기능명
  - business_workflow: 연관된 비즈니스 워크플로우
  - business_rules: 비즈니스 규칙 목록
  - ui_flow: UI 상호작용 흐름 (컴포넌트 ID 참조)
  - data_flow: 데이터 처리 흐름 (모델 ID 참조)
  - components: 관련 UI 컴포넌트 ID 목록
  - models: 관련 데이터 모델 ID 목록
  - acceptance_criteria: 수용 기준 목록

  출력 형식: YAML (feature_list)
```

### Step 2: Feature Planner

Feature Set을 구성하고 의존성을 분석합니다.

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  Feature 목록을 분석하여 Feature Map을 생성하세요:

  $FEATURE_LIST

  수행할 작업:
  1. Feature 간 의존성 분석 (비즈니스/기술)
  2. 응집도 높은 Feature Set 구성 (최대 $MAX_FEATURE_SETS개)
  3. Feature Set 간 DAG 생성

  규칙:
  - Feature A가 B에 의존하면, A는 B와 같은 Set이거나 후행 Set
  - 순환 의존성 불가 (DAG 유지)
  - 각 Set은 한 iteration에 구현 가능해야 함

  출력: feature_map.yaml 형식
```

### Step 3: 저장 및 승인

1. `.FDD/feature_map.yaml` 업데이트
2. `execution_state` 초기화
3. `gates.feature_map_approval`이 true면 사용자 승인 요청

## 출력

- `.FDD/feature_map.yaml` 업데이트
- 실행 계획 표시:
  ```
  Level 0: [set-auth, set-data] (병렬 2개)
  Level 1: [set-profile] (set-auth 완료 후)
  Level 2: [set-reports] (set-profile, set-data 완료 후)
  ```
```

### 3.5 /FDD-develop

```markdown
<!-- .claude/commands/FDD-develop.md -->

# FDD Phase 3: Iterative Development

## 전제조건

- `.FDD/feature_map.yaml` 존재
- Feature Map에 pending 상태의 노드 존재

## 워크플로우

### 메인 루프

```
while (pending_sets exist):
  1. 실행 가능한 Feature Set 식별 (의존성 해소된 것들)
  2. 병렬 실행 (max_parallel 제한)
  3. 상태 업데이트
  4. 체크포인트 저장
```

### 실행 가능 노드 식별

```python
def get_executable_sets(feature_map):
    executable = []
    for node in feature_map.nodes:
        if node.status == "todo":
            deps_done = all(
                get_node(dep).status == "done"
                for dep in node.depends_on
            )
            if deps_done:
                executable.append(node)
    return executable[:max_parallel]
```

### 단일 Feature Set 개발 (Iteration)

각 Feature Set에 대해 순차 실행:

#### Step 1: Chief Programmer

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  Feature Set을 분석하고 상세 설계를 생성하세요:

  ## Feature Set
  $FEATURE_SET

  ## 선행 Set 컨텍스트
  $PREDECESSOR_CONTEXT

  ## 전체 설계 문서
  $DESIGN_DOCUMENT

  수행할 작업:
  1. Feature 간 관계 분석
  2. 세부 설계 결정 (incremental design)
  3. 작업 계획 생성 (구체적인 task breakdown)

  출력:
  - detailed_design.yaml
  - task_plan.yaml (구현 순서, 파일 목록)
```

#### Step 2: Programmer

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  상세 설계와 작업 계획에 따라 코드를 구현하세요:

  ## 상세 설계
  $DETAILED_DESIGN

  ## 작업 계획
  $TASK_PLAN

  ## 현재 코드베이스 상태
  (관련 파일들 자동 로드)

  수행할 작업:
  1. 작업 계획의 각 task 순차 구현
  2. 코드 작성 (Write/Edit 도구 사용)
  3. 빌드 오류 발생 시 수정

  중요:
  - 각 파일 수정 후 PostToolUse 훅이 품질 검사를 실행합니다
  - 훅 실패 시 피드백을 받고 수정하세요

  완료 시 "IMPLEMENTATION_COMPLETE" 출력
```

#### Step 3: Reviewer

**Task 에이전트 호출:**
```
subagent_type: general-purpose
prompt: |
  구현된 코드를 검토하세요:

  ## Feature Set
  $FEATURE_SET

  ## 수용 기준
  $ACCEPTANCE_CRITERIA

  ## 변경된 파일
  $MODIFIED_FILES

  검토 항목:
  1. 수용 기준 충족 여부
  2. 코드 품질
  3. 보안 취약점
  4. 설계 일관성

  출력: review_result.yaml
  - status: passed | failed | needs_revision
  - issues: 발견된 문제 목록
  - suggestions: 개선 제안
```

### 병렬 실행

독립적인 Feature Set들을 동시에 개발:

```
executable_sets = get_executable_sets()

# 병렬 Task 호출 (단일 메시지에서 여러 Task)
for each set in executable_sets:
    Task(develop_iteration, set)  # 병렬 실행됨
```

### 상태 업데이트

각 iteration 완료 후:

1. `feature_map.yaml` 업데이트
   - `implementation_context.status`: done | blocked
   - `implementation_context.files_modified`: 수정된 파일 목록
   - `implementation_context.files_created`: 생성된 파일 목록
   - `implementation_context.completed_at`: 완료 시각

2. `execution_state` 업데이트
   - `completed_sets`에 추가
   - `in_progress_sets`에서 제거

3. 체크포인트 저장

### 빌드/테스트 루프

Programmer 단계에서 자동 실행:

```
for attempt in range(max_attempts):
    result = run_build()
    if result.success:
        break
    else:
        # 오류 피드백 → Programmer가 수정
        fix_errors(result.errors)
```

## 출력

- 코드 변경사항
- `.FDD/feature_map.yaml` 업데이트
- `.FDD/iterations/{set-id}/` 산출물
- 체크포인트
```

### 3.6 /FDD-status

```markdown
<!-- .claude/commands/FDD-status.md -->

# FDD 상태 확인

## 실행 내용

`.FDD/feature_map.yaml`을 읽어 현재 상태를 표시합니다.

## 출력 형식

```
FDD Status
=============

Project: $PROJECT_NAME
Phase: $CURRENT_PHASE

Feature Map:
┌─────────────┬────────────┬─────────────┬───────────────┐
│ Feature Set │ Status     │ Features    │ Depends On    │
├─────────────┼────────────┼─────────────┼───────────────┤
│ set-auth    │ ✓ done     │ 3           │ -             │
│ set-profile │ → progress │ 2           │ set-auth      │
│ set-reports │ ○ pending  │ 4           │ set-profile   │
└─────────────┴────────────┴─────────────┴───────────────┘

Progress: 1/3 Feature Sets (33%)

Next executable: [set-reports] (after set-profile completes)

Checkpoints available:
- iteration_1 (2024-01-15 10:30)
```

## 실행

feature_map.yaml을 읽고 위 형식으로 상태를 출력하세요.
```

### 3.7 /FDD-resume

```markdown
<!-- .claude/commands/FDD-resume.md -->

# FDD 체크포인트에서 재개

## 사용법

/FDD-resume [checkpoint_name]

- checkpoint_name 생략 시 latest 사용

## 실행 내용

1. `.FDD/checkpoints/{checkpoint_name}.yaml` 로드
2. `feature_map.yaml` 복원
3. `session_state.yaml` 복원
4. `/FDD-develop` 재개

## 체크포인트 구조

```yaml
version: 1
created_at: "2024-01-15T10:30:00Z"
feature_map_snapshot: { ... }
current_iteration: 2
notes: "set-auth 완료 후"
```
```

---

## 4. CLAUDE.md 워크플로우 지침

```markdown
<!-- CLAUDE.md에 추가할 섹션 -->

# FDD Workflow Guidelines

이 프로젝트는 FDD (Feature-Driven Development) 워크플로우를 사용합니다.

## 핵심 원칙

1. **Feature 단위 개발**: 모든 구현은 Feature Map의 Feature Set 단위로 진행
2. **의존성 준수**: Feature Set의 depends_on이 모두 done이어야 개발 시작
3. **상태 파일 유지**: 모든 변경은 `.FDD/feature_map.yaml`에 반영
4. **품질 훅**: 코드 작성 후 자동 품질 검사 실행

## 상태 파일 위치

- 설정: `.FDD/config.yaml`
- Feature Map: `.FDD/feature_map.yaml`
- 설계 문서: `.FDD/design_document.yaml`
- Iteration 산출물: `.FDD/iterations/{set-id}/`
- 로그: `.FDD/logs/`

## Feature Map 구조

```yaml
feature_map:
  nodes:
    - id: string           # Feature Set ID
      title: string        # 제목
      features: [...]      # 포함된 Feature 목록
      depends_on: [...]    # 선행 Feature Set ID
      business_context:    # 비즈니스 컨텍스트
      design_context:      # 설계 컨텍스트
      implementation_context:
        status: todo | in_progress | done | blocked
        files_modified: []
        files_created: []
```

## 개발 시 준수사항

1. **코드 작성 전**: 해당 Feature Set의 `detailed_design.yaml` 확인
2. **코드 작성 후**:
   - `feature_map.yaml` 업데이트 (files_modified, files_created)
   - 품질 훅 통과 확인
3. **Iteration 완료 시**: status를 done으로 변경

## 컨텍스트 전파

현재 Feature Set 개발 시 참조할 컨텍스트:
- 현재 Set의 business_context, design_context
- 선행 Set들의 implementation_context (files_modified, files_created)

## 슬래시 커맨드

- `/FDD init` - 프로젝트 초기화
- `/FDD design <요구사항>` - Phase 1: 설계
- `/FDD plan` - Phase 2: Feature Map 생성
- `/FDD develop` - Phase 3: 개발
- `/FDD status` - 상태 확인
- `/FDD resume` - 재개
```

---

## 5. 훅 설정

### 5.1 .claude/settings.json

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
      "Read(.FDD/**)",
      "Write(.FDD/**)"
    ]
  }
}
```

### 5.2 품질 검사 훅 스크립트

```bash
#!/bin/bash
# .FDD/hooks/quality-check.sh

FILE_PATH="$1"
CONFIG_FILE=".FDD/config.yaml"

# 설정 로드 (yq 또는 간단한 grep 사용)
BUILD_CMD=$(grep "build_command:" "$CONFIG_FILE" | cut -d'"' -f2)
TEST_CMD=$(grep "test_command:" "$CONFIG_FILE" | cut -d'"' -f2)

echo "=== FDD Quality Check ==="
echo "File: $FILE_PATH"
echo ""

# 1. Lint (있는 경우)
if [ -f "package.json" ] && grep -q '"lint"' package.json; then
    echo "→ Running lint..."
    npm run lint -- --fix "$FILE_PATH" 2>&1
    LINT_EXIT=$?
    if [ $LINT_EXIT -ne 0 ]; then
        echo "✗ Lint failed"
        exit 1
    fi
    echo "✓ Lint passed"
fi

# 2. TypeScript 검사 (있는 경우)
if [ -f "tsconfig.json" ]; then
    echo "→ Running type check..."
    npx tsc --noEmit 2>&1
    TSC_EXIT=$?
    if [ $TSC_EXIT -ne 0 ]; then
        echo "✗ Type check failed"
        exit 1
    fi
    echo "✓ Type check passed"
fi

# 3. 빌드 (설정된 경우)
if [ -n "$BUILD_CMD" ]; then
    echo "→ Running build..."
    $BUILD_CMD 2>&1
    BUILD_EXIT=$?
    if [ $BUILD_EXIT -ne 0 ]; then
        echo "✗ Build failed"
        exit 1
    fi
    echo "✓ Build passed"
fi

echo ""
echo "=== Quality Check Passed ==="
exit 0
```

### 5.3 Iteration 완료 훅

```bash
#!/bin/bash
# .FDD/hooks/iteration-complete.sh

FEATURE_SET_ID="$1"
CONFIG_FILE=".FDD/config.yaml"

TEST_CMD=$(grep "test_command:" "$CONFIG_FILE" | cut -d'"' -f2)

echo "=== Iteration Complete: $FEATURE_SET_ID ==="

# 전체 테스트 실행
if [ -n "$TEST_CMD" ]; then
    echo "→ Running full test suite..."
    $TEST_CMD 2>&1
    TEST_EXIT=$?
    if [ $TEST_EXIT -ne 0 ]; then
        echo "✗ Tests failed"
        exit 1
    fi
    echo "✓ All tests passed"
fi

# 체크포인트 저장
CHECKPOINT_DIR=".FDD/checkpoints"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CHECKPOINT_FILE="$CHECKPOINT_DIR/iteration_${FEATURE_SET_ID}_${TIMESTAMP}.yaml"

mkdir -p "$CHECKPOINT_DIR"
cp .FDD/feature_map.yaml "$CHECKPOINT_FILE"

# latest 심볼릭 링크 업데이트
ln -sf "$(basename $CHECKPOINT_FILE)" "$CHECKPOINT_DIR/latest"

echo "✓ Checkpoint saved: $CHECKPOINT_FILE"
exit 0
```

---

## 6. Feature Map YAML 스키마

```yaml
# .FDD/feature_map.yaml

meta:
  project_name: "My Project"
  repo_path: "."
  created_at: "2024-01-15T10:00:00Z"
  updated_at: "2024-01-15T12:30:00Z"
  version: "1.0"
  max_parallel: 3

design_summary:
  description: "사용자 인증 및 프로필 관리 시스템"
  ui_components:
    - id: "ui-login-form"
      name: "LoginForm"
      description: "로그인 폼 컴포넌트"
    - id: "ui-signup-form"
      name: "SignupForm"
      description: "회원가입 폼 컴포넌트"
    - id: "ui-profile-page"
      name: "ProfilePage"
      description: "프로필 페이지"
  data_models:
    - id: "model-user"
      name: "User"
      schema:
        id: string
        email: string
        name: string
        created_at: datetime
    - id: "model-session"
      name: "Session"
      schema:
        id: string
        user_id: string
        token: string
        expires_at: datetime
  modules:
    - auth
    - profile
    - common
  tech_stack:
    - TypeScript
    - React
    - Node.js

feature_map:
  nodes:
    - id: "set-auth"
      title: "인증 시스템"
      features:
        - id: "feat-login"
          name: "로그인"
          business_workflow: "사용자가 이메일/비밀번호로 로그인"
          business_rules:
            - "이메일 형식 검증"
            - "비밀번호 최소 8자"
          ui_flow: "ui-login-form에서 입력 → 제출 → 홈으로 이동"
          data_flow: "입력 검증 → API 호출 → model-session 생성"
          components: ["ui-login-form"]
          models: ["model-user", "model-session"]
          acceptance_criteria:
            - "유효한 자격증명으로 로그인 성공"
            - "잘못된 자격증명 시 오류 메시지 표시"
        - id: "feat-signup"
          name: "회원가입"
          business_workflow: "새 사용자 계정 생성"
          business_rules:
            - "이메일 중복 불가"
            - "비밀번호 확인 일치"
          ui_flow: "ui-signup-form에서 입력 → 제출 → 로그인 페이지로 이동"
          data_flow: "입력 검증 → API 호출 → model-user 생성"
          components: ["ui-signup-form"]
          models: ["model-user"]
          acceptance_criteria:
            - "유효한 정보로 가입 성공"
            - "중복 이메일 시 오류 표시"

      depends_on: []

      business_context:
        scope: "사용자 인증의 핵심 기능"
        user_stories:
          - "사용자로서 로그인하여 서비스를 이용하고 싶다"
          - "새 사용자로서 계정을 만들고 싶다"
        external_interfaces: []

      design_context:
        ui_components:
          - id: "ui-login-form"
            description: "이메일/비밀번호 입력 필드, 로그인 버튼"
            incremental_design: null
          - id: "ui-signup-form"
            description: "이메일/비밀번호/확인 입력 필드, 가입 버튼"
            incremental_design: null
        data_models:
          - id: "model-user"
            schema:
              id: string
              email: string
              password_hash: string
              name: string
          - id: "model-session"
            schema:
              id: string
              user_id: string
              token: string
        architectural_notes:
          - "JWT 기반 인증"
          - "비밀번호는 bcrypt로 해싱"

      implementation_context:
        status: "done"
        started_at: "2024-01-15T10:30:00Z"
        completed_at: "2024-01-15T11:45:00Z"
        files_modified:
          - "src/auth/login.ts"
          - "src/auth/signup.ts"
        files_created:
          - "src/auth/index.ts"
          - "src/models/user.ts"
          - "src/models/session.ts"
        diffs: ["abc123"]
        test_results:
          passed: 8
          failed: 0
          skipped: 0
        error_log: []

    - id: "set-profile"
      title: "프로필 관리"
      features:
        - id: "feat-view-profile"
          name: "프로필 조회"
          # ... (생략)
        - id: "feat-edit-profile"
          name: "프로필 수정"
          # ... (생략)

      depends_on: ["set-auth"]

      business_context:
        scope: "로그인한 사용자의 프로필 관리"
        # ...

      design_context:
        # ...

      implementation_context:
        status: "in_progress"
        started_at: "2024-01-15T12:00:00Z"
        completed_at: null
        files_modified: []
        files_created: []
        diffs: []
        test_results:
          passed: 0
          failed: 0
          skipped: 0
        error_log: []

execution_state:
  current_iteration: 2
  completed_sets: ["set-auth"]
  in_progress_sets: ["set-profile"]
  pending_sets: []
  blocked_sets: []
```

---

## 7. 병렬 실행 전략

### 7.1 DAG 기반 스케줄링

```
feature_map.yaml 분석:

set-auth (depends: [])           → Level 0
set-data (depends: [])           → Level 0
set-profile (depends: [set-auth]) → Level 1
set-reports (depends: [set-profile, set-data]) → Level 2

실행 계획:
Level 0: [set-auth, set-data] 병렬 실행
Level 1: [set-profile] (set-auth 완료 후)
Level 2: [set-reports] (set-profile, set-data 모두 완료 후)
```

### 7.2 Claude Code에서 병렬 Task 호출

```markdown
<!-- /FDD-develop 내부에서 -->

## 병렬 실행이 가능한 경우

executable_sets = [set-auth, set-data]  # 둘 다 depends_on이 빈 배열

이 경우, 단일 응답에서 여러 Task 도구를 호출하여 병렬 실행:

<parallel_tasks>
Task 1: develop_iteration(set-auth)
Task 2: develop_iteration(set-data)
</parallel_tasks>

Claude Code는 이를 동시에 처리합니다.
```

### 7.3 max_parallel 제한

```yaml
# config.yaml
execution:
  max_parallel: 3  # 동시에 최대 3개 Feature Set만 개발
```

실행 가능한 Set이 4개여도 3개만 병렬 실행, 나머지는 대기.

---

## 8. Human-in-the-Loop 게이트

### 8.1 승인 게이트 위치

| 게이트 | 설정 키 | 기본값 |
|--------|---------|--------|
| 설계 문서 승인 | `gates.design_approval` | true |
| Feature Map 승인 | `gates.feature_map_approval` | true |
| Iteration 시작 승인 | `gates.iteration_approval` | false |

### 8.2 승인 요청 방식

```markdown
<!-- 슬래시 커맨드 내에서 -->

## 승인 요청

gates.design_approval이 true인 경우:

AskUserQuestion 도구를 사용하여 승인 요청:

questions:
  - header: "설계 승인"
    question: "생성된 설계 문서를 승인하시겠습니까?"
    options:
      - label: "승인"
        description: "설계를 승인하고 Feature Map 생성으로 진행"
      - label: "수정 요청"
        description: "수정이 필요한 부분을 지정"
      - label: "거부"
        description: "설계를 거부하고 처음부터 다시 시작"
    multiSelect: false
```

---

## 9. 로그 및 감사

### 9.1 이벤트 로그

```jsonl
# .FDD/logs/events.jsonl

{"ts":"2024-01-15T10:30:00Z","event":"workflow_started","data":{"phase":"design"}}
{"ts":"2024-01-15T10:31:00Z","event":"agent_invoked","data":{"agent":"requirements_scout"}}
{"ts":"2024-01-15T10:32:00Z","event":"agent_completed","data":{"agent":"requirements_scout"}}
{"ts":"2024-01-15T10:35:00Z","event":"design_approved","data":{}}
{"ts":"2024-01-15T10:40:00Z","event":"feature_map_generated","data":{"sets":3}}
{"ts":"2024-01-15T10:45:00Z","event":"iteration_started","data":{"set":"set-auth"}}
{"ts":"2024-01-15T11:00:00Z","event":"quality_check","data":{"status":"passed"}}
{"ts":"2024-01-15T11:45:00Z","event":"iteration_completed","data":{"set":"set-auth"}}
```

### 9.2 감사 로그

```jsonl
# .FDD/logs/audit.jsonl

{"ts":"2024-01-15T10:50:00Z","action":"file_write","path":"src/auth/login.ts","agent":"programmer"}
{"ts":"2024-01-15T10:51:00Z","action":"file_write","path":"src/auth/signup.ts","agent":"programmer"}
{"ts":"2024-01-15T10:52:00Z","action":"bash_exec","command":"npm run build","exit_code":0}
{"ts":"2024-01-15T10:53:00Z","action":"quality_check","files":["src/auth/login.ts"],"result":"passed"}
```

---

## 10. 초기 설정 체크리스트

프로젝트에서 FDD를 사용하려면:

```bash
# 1. 슬래시 커맨드 파일 복사
mkdir -p .claude/commands
cp /path/to/FDD/commands/*.md .claude/commands/

# 2. 훅 설정
cp /path/to/FDD/settings.json .claude/settings.json

# 3. 훅 스크립트 복사
mkdir -p .FDD/hooks
cp /path/to/FDD/hooks/*.sh .FDD/hooks/
chmod +x .FDD/hooks/*.sh

# 4. CLAUDE.md에 지침 추가
cat /path/to/FDD/CLAUDE_SECTION.md >> CLAUDE.md

# 5. FDD 초기화
claude
> /FDD init
```

또는 `/FDD init`이 위 과정을 자동으로 수행하도록 구현.

---

## 11. 중간 산출물 품질 검사 및 개선 루프

### 11.1 개요

코드뿐만 아니라 **중간 산출물**(설계 문서, Feature Map, 상세 설계 등)도 품질 검사를 거쳐야 합니다. 검사 실패 시 자동으로 개선 루프를 실행합니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Artifact Quality Loop                        │
│                                                                  │
│   [Generate]                                                    │
│       │                                                         │
│       ▼                                                         │
│   ┌─────────┐     fail      ┌─────────┐                        │
│   │Validator├──────────────►│Improver │                        │
│   └────┬────┘               └────┬────┘                        │
│        │                         │                              │
│        │ pass                    │ improved                     │
│        │                         │                              │
│        ▼                         ▼                              │
│   ┌─────────┐               ┌─────────┐                        │
│   │  Save   │◄──────────────┤Validator│◄─── (max N iterations) │
│   └─────────┘     pass      └─────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 검증 대상 산출물

| 산출물 | 생성 단계 | 검증 항목 |
|--------|----------|----------|
| Structured Requirements | Phase 1.1 | 완전성, 일관성, 모호성 |
| Business Spec | Phase 1.2 | 워크플로우 커버리지, 수용기준 명확성 |
| Design Document | Phase 1.3 | ID 고유성, 참조 무결성, 기술적 실현가능성 |
| Feature List | Phase 2.1 | 범위 적절성, ID 참조 유효성 |
| Feature Map | Phase 2.2 | DAG 유효성, 의존성 논리성, 균형 |
| Detailed Design | Phase 3.1 | 구현 가능성, 파일 구조 적절성 |
| Review Result | Phase 3.3 | 수용기준 검증 완전성 |

### 11.3 Validator 정의

#### 11.3.1 Requirements Validator

```yaml
requirements_validator:
  checks:
    - name: "completeness"
      description: "필수 섹션(summary, functional_requirements)이 있는지"
      severity: "error"

    - name: "consistency"
      description: "요구사항 간 모순이 없는지"
      severity: "error"

    - name: "clarity"
      description: "각 요구사항이 명확하고 측정 가능한지"
      severity: "warning"

    - name: "priority_assignment"
      description: "모든 요구사항에 우선순위가 있는지"
      severity: "warning"
```

#### 11.3.2 Design Document Validator

```yaml
design_document_validator:
  checks:
    - name: "id_uniqueness"
      description: "모든 UI 컴포넌트와 데이터 모델의 ID가 고유한지"
      severity: "error"

    - name: "id_format"
      description: "ID 형식이 규칙을 따르는지 (ui-xxx, model-xxx)"
      severity: "error"

    - name: "reference_integrity"
      description: "참조된 ID가 실제로 존재하는지"
      severity: "error"

    - name: "completeness"
      description: "필수 섹션(ui_components, data_models, modules)이 있는지"
      severity: "error"

    - name: "tech_stack_validity"
      description: "기술 스택이 프로젝트와 호환되는지"
      severity: "warning"

    - name: "component_coverage"
      description: "모든 워크플로우가 UI 컴포넌트로 커버되는지"
      severity: "warning"

    - name: "model_schema_validity"
      description: "데이터 모델 스키마가 유효한지"
      severity: "error"
```

#### 11.3.3 Feature Map Validator

```yaml
feature_map_validator:
  checks:
    - name: "dag_validity"
      description: "순환 의존성이 없는지 (DAG인지)"
      severity: "error"

    - name: "dependency_logic"
      description: "의존성 관계가 논리적인지"
      severity: "error"

    - name: "feature_coverage"
      description: "모든 요구사항이 Feature로 커버되는지"
      severity: "warning"

    - name: "set_balance"
      description: "Feature Set 크기가 균형 잡혔는지 (±30% 이내)"
      severity: "warning"

    - name: "id_reference_validity"
      description: "components, models ID가 설계 문서에 존재하는지"
      severity: "error"

    - name: "acceptance_criteria_exists"
      description: "모든 Feature에 수용 기준이 있는지"
      severity: "error"

    - name: "max_sets_limit"
      description: "Feature Set 수가 max_feature_sets 이하인지"
      severity: "warning"
```

#### 11.3.4 Detailed Design Validator

```yaml
detailed_design_validator:
  checks:
    - name: "file_path_validity"
      description: "파일 경로가 프로젝트 구조와 일치하는지"
      severity: "warning"

    - name: "implementation_order_logic"
      description: "구현 순서가 의존성을 고려했는지"
      severity: "error"

    - name: "feature_coverage"
      description: "모든 Feature가 구현 계획에 포함되었는지"
      severity: "error"

    - name: "existing_file_check"
      description: "수정할 파일이 실제로 존재하는지"
      severity: "warning"

    - name: "key_exports_defined"
      description: "생성할 파일의 주요 export가 정의되었는지"
      severity: "warning"
```

### 11.4 Validator Task 호출

각 산출물 생성 후 Validator를 호출합니다.

```yaml
# 예: 설계 문서 검증

Task:
  description: "설계 문서 검증"
  subagent_type: "general-purpose"
  prompt: |
    다음 설계 문서를 검증하세요:

    ## 설계 문서
    ```yaml
    $DESIGN_DOCUMENT
    ```

    ## 검증 규칙

    ### Error 수준 (반드시 통과해야 함)
    1. id_uniqueness: 모든 ui-xxx, model-xxx ID가 고유해야 함
    2. id_format: ID가 ui-xxx 또는 model-xxx 형식이어야 함
    3. reference_integrity: 참조된 ID가 문서 내 존재해야 함
    4. completeness: ui_components, data_models, modules, tech_stack 필수
    5. model_schema_validity: 데이터 모델에 유효한 스키마가 있어야 함

    ### Warning 수준 (권장)
    6. tech_stack_validity: 기술 스택이 일반적으로 호환 가능해야 함
    7. component_coverage: 비즈니스 워크플로우가 UI로 커버되어야 함

    ## 출력 형식
    ```yaml
    validation_result:
      status: "passed" | "failed"
      errors:
        - check: "체크 이름"
          message: "오류 메시지"
          location: "오류 위치 (예: ui_components[2])"
          suggestion: "수정 제안"
      warnings:
        - check: "체크 이름"
          message: "경고 메시지"
          suggestion: "개선 제안"
      summary:
        total_checks: 7
        passed: 5
        errors: 1
        warnings: 1
    ```

    status는 errors가 0개일 때만 "passed"입니다.
```

### 11.5 Improver Task 호출

검증 실패 시 Improver가 산출물을 개선합니다.

```yaml
# 예: 설계 문서 개선

Task:
  description: "설계 문서 개선"
  subagent_type: "general-purpose"
  prompt: |
    설계 문서에서 품질 검사 오류가 발견되었습니다.
    오류를 수정한 개선된 버전을 생성하세요.

    ## 원본 설계 문서
    ```yaml
    $ORIGINAL_DESIGN_DOCUMENT
    ```

    ## 검증 결과
    ```yaml
    $VALIDATION_RESULT
    ```

    ## 수정 지침

    각 error에 대해:
    1. 오류 원인 분석
    2. suggestion을 참고하여 수정 방안 결정
    3. 수정 적용

    각 warning에 대해:
    - 가능하면 개선, 불가능하면 현재 상태 유지

    ## 출력

    수정된 전체 설계 문서를 YAML 형식으로 출력하세요.
    - 원본 구조를 유지하세요
    - 수정된 부분만 변경하세요
    - 주석이나 설명을 추가하지 마세요

    ```yaml
    # 수정된 설계 문서 전체
    ```
```

### 11.6 개선 루프 설정

```yaml
# .FDD/config.yaml

quality_check:
  artifacts:
    enabled: true
    max_improvement_iterations: 3    # 최대 개선 반복 횟수
    fail_on_warning: false           # warning도 실패로 처리할지
    require_human_approval_on_fail: true  # 최대 반복 후 실패 시 사용자 승인

  validators:
    requirements:
      enabled: true
      checks:
        completeness: error
        consistency: error
        clarity: warning
        priority_assignment: warning

    design_document:
      enabled: true
      checks:
        id_uniqueness: error
        id_format: error
        reference_integrity: error
        completeness: error
        tech_stack_validity: warning
        component_coverage: warning
        model_schema_validity: error

    feature_map:
      enabled: true
      checks:
        dag_validity: error
        dependency_logic: error
        feature_coverage: warning
        set_balance: warning
        id_reference_validity: error
        acceptance_criteria_exists: error
        max_sets_limit: warning

    detailed_design:
      enabled: true
      checks:
        file_path_validity: warning
        implementation_order_logic: error
        feature_coverage: error
        existing_file_check: warning
        key_exports_defined: warning
```

### 11.7 개선 루프 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                    Quality Check Loop                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  iteration = 0                                                  │
│  max_iterations = config.quality_check.artifacts.max_improvement_iterations
│                                                                  │
│  while iteration < max_iterations:                              │
│      │                                                          │
│      ├── 1. Task(Validator)                                     │
│      │      └── result = {status, errors, warnings}             │
│      │                                                          │
│      ├── 2. if result.status == "passed":                       │
│      │      └── break (성공)                                     │
│      │                                                          │
│      ├── 3. if iteration == max_iterations - 1:                 │
│      │      └── break (최대 반복 도달)                           │
│      │                                                          │
│      ├── 4. Task(Improver)                                      │
│      │      └── improved_artifact = ...                         │
│      │                                                          │
│      ├── 5. artifact = improved_artifact                        │
│      │                                                          │
│      └── 6. iteration += 1                                      │
│                                                                  │
│  if result.status == "failed":                                  │
│      if config.require_human_approval_on_fail:                  │
│          AskUserQuestion("검증 실패. 진행할까요?")               │
│      else:                                                      │
│          mark_as_blocked()                                      │
│                                                                  │
│  Save artifact to file                                          │
│  Log validation result                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.8 슬래시 커맨드 통합

#### /FDD-design 내부 흐름 (Phase 1.3)

```markdown
### Step 4: Architect

(기존 Architect Task 호출)

### Step 4.1: 설계 문서 검증 루프

```
for iteration in 1..max_improvement_iterations:

    # Validator 호출
    validation_result = Task(
        description: "설계 문서 검증",
        subagent_type: "general-purpose",
        prompt: (위의 Validator 프롬프트)
    )

    # 통과 시 종료
    if validation_result.status == "passed":
        log("설계 문서 검증 통과 (iteration: {iteration})")
        break

    # 실패 시 개선
    log("설계 문서 검증 실패 - 개선 시도 (iteration: {iteration})")

    improved_design = Task(
        description: "설계 문서 개선",
        subagent_type: "general-purpose",
        prompt: (위의 Improver 프롬프트)
    )

    design_document = improved_design

# 최종 실패 처리
if validation_result.status == "failed":
    if config.require_human_approval_on_fail:
        approval = AskUserQuestion(
            header: "검증 실패"
            question: "설계 문서 검증이 실패했습니다. 그래도 진행할까요?"
            options:
                - label: "진행"
                  description: "경고를 무시하고 진행"
                - label: "중단"
                  description: "설계 단계를 중단"
        )
```

### Step 5: 설계 문서 저장

검증 통과 또는 사용자 승인 후 저장
```

### 11.9 검증 결과 로깅

```jsonl
# .FDD/logs/events.jsonl

{"ts":"2024-01-15T10:35:00Z","event":"validation_started","data":{"artifact":"design_document","iteration":1}}
{"ts":"2024-01-15T10:35:10Z","event":"validation_completed","data":{"artifact":"design_document","status":"failed","errors":2,"warnings":1}}
{"ts":"2024-01-15T10:35:11Z","event":"improvement_started","data":{"artifact":"design_document","iteration":1}}
{"ts":"2024-01-15T10:35:30Z","event":"improvement_completed","data":{"artifact":"design_document","iteration":1}}
{"ts":"2024-01-15T10:35:31Z","event":"validation_started","data":{"artifact":"design_document","iteration":2}}
{"ts":"2024-01-15T10:35:40Z","event":"validation_completed","data":{"artifact":"design_document","status":"passed","errors":0,"warnings":1}}
{"ts":"2024-01-15T10:35:41Z","event":"artifact_saved","data":{"artifact":"design_document","path":".FDD/design_document.yaml"}}
```

### 11.10 품질 메트릭 표시

`/FDD status --quality` 실행 시:

```
Quality Metrics
===============

Artifacts:
┌──────────────────────┬──────────┬────────────┬──────────┐
│ Artifact             │ Status   │ Iterations │ Warnings │
├──────────────────────┼──────────┼────────────┼──────────┤
│ Requirements         │ ✓ passed │ 1          │ 0        │
│ Business Spec        │ ✓ passed │ 1          │ 1        │
│ Design Document      │ ✓ passed │ 2          │ 1        │
│ Feature Map          │ ✓ passed │ 1          │ 0        │
├──────────────────────┼──────────┼────────────┼──────────┤
│ Detailed Design      │          │            │          │
│   └── set-auth       │ ✓ passed │ 1          │ 0        │
│   └── set-profile    │ ✓ passed │ 2          │ 1        │
│   └── set-reports    │ ○ pending│ -          │ -        │
└──────────────────────┴──────────┴────────────┴──────────┘

Code Quality:
┌──────────────┬────────┬────────┐
│ Check        │ Passed │ Failed │
├──────────────┼────────┼────────┤
│ Lint         │ 45     │ 0      │
│ TypeCheck    │ 45     │ 0      │
│ Build        │ 12     │ 0      │
│ Test         │ 38     │ 2      │
└──────────────┴────────┴────────┘

Overall Quality Score: 92%
  Artifact validation: 100%
  Code quality: 84%
```

### 11.11 개선 전략 가이드

| 오류 유형 | 자동 개선 전략 |
|----------|---------------|
| ID 중복 | 중복 ID에 숫자 접미사 추가 (-2, -3) |
| ID 형식 오류 | 올바른 접두사로 변환 (component → ui-component) |
| 참조 무결성 | 누락된 정의 추가 또는 잘못된 참조 수정 |
| DAG 순환 | 의존성 재분석 후 순환 끊기 |
| 커버리지 부족 | 누락된 항목 식별 후 추가 |
| 불균형 | Feature Set 재분배 |
| 스키마 누락 | 기본 스키마 생성 |
| 수용기준 누락 | 비즈니스 규칙 기반으로 생성 |
