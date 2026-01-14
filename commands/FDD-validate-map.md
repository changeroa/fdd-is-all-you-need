# FDD Validate Feature Map

Validate the Feature Map structure, dependencies, and coverage.

## Usage
```
/FDD-validate-map [path]
```
- `path`: Optional. Default: `.FDD/feature_map.yaml`

## Instructions

### 1. Load Feature Map
Read `.FDD/feature_map.yaml` and parse the YAML structure.

### 2. Structural Validation

Check for required top-level keys:
- `metadata` - Project metadata
- `business_context` - Business objectives and constraints
- `design_context` - Architecture and patterns
- `feature_sets` - List of Feature Sets

### 3. Feature Set Validation

For each Feature Set, verify:

| Field | Required | Validation |
|-------|----------|------------|
| `id` | Yes | Format: `FS-XXX` (unique) |
| `name` | Yes | Non-empty string |
| `status` | Yes | One of: pending, in_progress, completed, blocked |
| `features` | Yes | Non-empty array |
| `dependencies` | No | Array of valid FS-XXX references |

### 4. Feature Validation

For each Feature within a Feature Set:

| Field | Required | Validation |
|-------|----------|------------|
| `id` | Yes | Format: `F-XXX-YYY` (unique within set) |
| `name` | Yes | Non-empty string |
| `status` | Yes | One of: pending, in_progress, completed |
| `acceptance_criteria` | Recommended | List of testable criteria |

### 5. Dependency Validation

- Check all dependency references point to existing Feature Sets
- **Detect circular dependencies** using DFS cycle detection:
  ```
  For each FS in feature_sets:
    If has_cycle(FS, visited={}, recursion_stack={}):
      Report: "Circular dependency detected"
  ```

### 6. Granularity Checks

Report warnings for:
- Feature Sets with > 10 features (consider splitting)
- Feature Sets with < 2 features (consider merging)
- Empty feature_sets array

### 7. Output Results

```markdown
=== Feature Map Validation ===
File: .FDD/feature_map.yaml

[If all pass]
✓ Validation PASSED

[If warnings only]
Warnings:
  ⚠ Feature Set FS-003 has only 1 feature
  ⚠ Feature Set FS-005 has 12 features (consider splitting)

⚠ Validation PASSED with warnings

[If errors]
Issues:
  ✗ Missing required key: business_context
  ✗ Duplicate Feature Set ID: FS-002
  ✗ Circular dependency detected: FS-001 → FS-003 → FS-001

✗ Validation FAILED - X issue(s) found
```

### 8. Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{"timestamp":"ISO8601","event":"validation","artifact":"feature_map","result":"pass|fail|pass_with_warnings","issues":[]}
```

## Return Values
- **PASS**: All checks passed
- **PASS_WITH_WARNINGS**: Structure valid, but recommendations exist
- **FAIL**: Critical issues found

## Called By
- `/FDD-plan` (after Feature Map generation)
- `/FDD-improve` (during quality loop)
