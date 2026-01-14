# FDD Design

Create detailed implementation designs for each Feature Set.

## Prerequisites
- Feature Map must exist and be approved
- `.FDD/feature_map.yaml` must have populated `feature_sets`

## Instructions

### Phase 1: Load Feature Map
1. Read `.FDD/feature_map.yaml`
2. Get list of Feature Sets in dependency order
3. Identify which Feature Sets need detailed design

### Phase 2: Parallel Design Creation

**Option A: Use Orchestrator (Recommended)**
```
Invoke fdd-orchestrator agent with mode: "design"
The orchestrator will:
1. Identify independent Feature Sets
2. Spawn fdd-designer agents in parallel
3. Track completion and handle validation
```

**Option B: Manual Parallel Execution**
Spawn `fdd-designer` agents in parallel for independent Feature Sets:
```
Task(subagent_type: "fdd-is-all-you-need:fdd-designer", prompt: "Design FS-001...")
Task(subagent_type: "fdd-is-all-you-need:fdd-designer", prompt: "Design FS-002...")
Task(subagent_type: "fdd-is-all-you-need:fdd-designer", prompt: "Design FS-003...")
# All three run in parallel when in same message
```

For each Feature Set, create `.FDD/iterations/design_FS-XXX.md`:

```markdown
# Detailed Design: [Feature Set Name]

## 1. Overview
- Feature Set ID: FS-XXX
- Dependencies: [List]
- Features: [Count]

## 2. Architecture Integration
### 2.1 Components Affected
- [Component 1]: [Changes needed]
- [Component 2]: [Changes needed]

### 2.2 New Components
- [New Component]: [Purpose]

## 3. Feature Specifications

### 3.1 Feature: F-XXX-001 - [Name]
**Description**: [Detailed description]

**Implementation**:
- Files to create/modify: [List]
- Key functions/classes: [List]
- External dependencies: [List]

**Interfaces**:
```typescript
// Interface definitions
```

**Test Cases**:
- [ ] [Test case 1]
- [ ] [Test case 2]

### 3.2 Feature: F-XXX-002 - [Name]
[Same structure...]

## 4. Implementation Order
1. F-XXX-001 (no dependencies)
2. F-XXX-002 (depends on F-XXX-001)
...

## 5. Risk Assessment
| Risk | Mitigation |
|------|------------|
| [Risk] | [Mitigation] |
```

### Phase 3: Quality Validation Loop

For each detailed design, run Validator/Improver loop using `/FDD-improve`:

```
/FDD-improve detailed_design .FDD/iterations/design_FS-XXX.md 3
```

This will:
1. **Validate** via `/FDD-validate-detail`:
   - Technical Accuracy: APIs exist, patterns correct
   - Implementation Feasibility: Can be implemented as described
   - Interface Consistency: Interfaces align across features

2. **If issues found**, invoke `fdd-improver` agent and re-validate

### Phase 4: Update Feature Map
- Add `implementation_context` to each feature:
  ```yaml
  implementation_context:
    files: [list of files]
    interfaces: [interface names]
    design_doc: .FDD/iterations/design_FS-XXX.md
  ```

### Phase 5: Human Approval Gate (Optional)
- If `approval_gates.detailed_design` is true in config
- Present summary of all detailed designs
- Ask for approval before development

## Output
- `.FDD/iterations/design_FS-XXX.md` for each Feature Set
- Updated `.FDD/feature_map.yaml` with implementation contexts

## Next Step
After completion: `/FDD develop`
