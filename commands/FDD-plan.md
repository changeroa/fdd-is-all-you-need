# FDD Plan

Generate a Feature Map from the design document.

## Prerequisites
- Design document must exist (`.FDD/iterations/design_document.md`)
- Design document must be approved

## Instructions

### Phase 1: Analyze Design Document
1. Read `.FDD/iterations/design_document.md`
2. Extract:
   - Business objectives → `business_context.objectives`
   - Constraints → `business_context.constraints`
   - Success criteria → `business_context.success_criteria`
   - Architecture → `design_context.architecture`
   - Technologies → `design_context.technologies`

### Phase 2: Decompose into Feature Sets
1. **Identify Feature Sets** from functional requirements:
   - Group related features together
   - Each Feature Set = 3-7 related features
   - Name should reflect user-facing functionality

2. **For each Feature Set, define**:
   ```yaml
   - id: FS-XXX
     name: "Feature Set Name"
     description: "What this feature set delivers"
     status: pending
     priority: high|medium|low
     dependencies: [FS-YYY, FS-ZZZ]  # Other Feature Sets
     features:
       - id: F-XXX-001
         name: "Feature Name"
         description: "Specific feature description"
         status: pending
         dependencies: []  # Internal feature dependencies
   ```

3. **Build Dependency Graph**:
   - Identify dependencies between Feature Sets
   - Ensure no circular dependencies
   - Mark independent Feature Sets (can run in parallel)

### Phase 3: Quality Validation Loop

Run Validator/Improver loop using `/FDD-improve`:

```
/FDD-improve feature_map .FDD/feature_map.yaml 3
```

This will:
1. **Validate** via `/FDD-validate-map`:
   - Dependency Validity: No cycles, all references valid
   - Coverage: All requirements mapped to features
   - Granularity: Features are appropriately sized

2. **If issues found**, invoke `fdd-improver` agent and re-validate

3. **Generate execution order**:
   - Use `/FDD-get-executable` to identify parallelizable groups
   - Topological sort of Feature Sets

### Phase 4: Human Approval Gate
- Present Feature Map summary:
  - Total Feature Sets
  - Total Features
  - Estimated parallel execution groups
- Ask for approval to proceed

## Output
Update `.FDD/feature_map.yaml` with:
- Populated `business_context`
- Populated `design_context`
- Complete `feature_sets` list

## Next Step
After approval: `/FDD design`
