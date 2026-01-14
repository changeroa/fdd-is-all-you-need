# FDD Analyze

Analyze requirements and create a comprehensive design document.

## Prerequisites
- Project must be initialized (`/FDD init`)
- Requirements document or description must be available

## Instructions

### Phase 1: Gather Requirements
1. **Identify input sources**:
   - README.md, REQUIREMENTS.md, or similar docs
   - User-provided description
   - Existing codebase analysis (if any)

2. **Ask clarifying questions** if needed:
   - Target users/audience
   - Core functionality requirements
   - Technical constraints
   - Integration requirements

### Phase 2: Create Design Document
Generate `.FDD/iterations/design_document.md` with:

```markdown
# Design Document: [Project Name]

## 1. Executive Summary
[Brief overview of the project]

## 2. Business Context
### 2.1 Objectives
- [Objective 1]
- [Objective 2]

### 2.2 Constraints
- [Constraint 1]
- [Constraint 2]

### 2.3 Success Criteria
- [Criterion 1]
- [Criterion 2]

## 3. Functional Requirements
### 3.1 [Feature Category 1]
- FR-001: [Requirement description]
- FR-002: [Requirement description]

## 4. Non-Functional Requirements
- NFR-001: Performance - [Description]
- NFR-002: Security - [Description]

## 5. Technical Architecture
### 5.1 System Overview
[Architecture description]

### 5.2 Technology Stack
- [Technology 1]: [Purpose]
- [Technology 2]: [Purpose]

## 6. Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| [Risk 1] | [Impact] | [Mitigation] |
```

### Phase 3: Quality Validation Loop

Run the Validator/Improver loop using `/FDD-improve`:

```
/FDD-improve design_document .FDD/iterations/design_document.md 3
```

This will:
1. **Validate** via `/FDD-validate-design`:
   - Completeness: All sections filled?
   - Clarity: Unambiguous descriptions?
   - Consistency: No contradictions?

2. **If issues found**, invoke `fdd-improver` agent and re-validate

3. **If quality gate passes**, proceed to human approval

### Phase 4: Human Approval Gate
- Present design document summary to user
- Ask for approval to proceed
- If approved, mark phase complete

## Output
- `.FDD/iterations/design_document.md`
- Log events to `.FDD/logs/events.jsonl`

## Next Step
After approval: `/FDD plan`
