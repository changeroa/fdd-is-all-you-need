# FDD Validate Feature Map

Validate the Feature Map structure, dependencies, and coverage.

## Usage
```
/FDD-validate-map [path]
```
- `path`: Optional. Default: `.FDD/feature_map.yaml`

## Instructions

### Use Validation Script (Recommended)

For reliable, consistent validation, use the validation script:

```bash
bash .FDD/scripts/validate-deps.sh check [path]
```

This provides:
- Circular dependency detection (DFS-based algorithm)
- Reference integrity validation
- Topological sort generation
- Parallel execution wave preview
- Granularity warnings

### Script Commands

```bash
# Full validation
bash .FDD/scripts/validate-deps.sh check .FDD/feature_map.yaml

# Check for circular dependencies only
bash .FDD/scripts/validate-deps.sh cycles .FDD/feature_map.yaml

# Generate execution order
bash .FDD/scripts/validate-deps.sh order .FDD/feature_map.yaml

# Show parallel execution waves (with priority ordering)
bash .FDD/scripts/validate-deps.sh waves .FDD/feature_map.yaml
```

### Manual Validation Steps

If you need to validate manually:

#### 1. Load Feature Map
Read `.FDD/feature_map.yaml` and parse the YAML structure.

#### 2. Structural Validation

Check for required top-level keys:
- `metadata` - Project metadata
- `business_context` - Business objectives and constraints
- `design_context` - Architecture and patterns
- `feature_sets` - List of Feature Sets

#### 3. Feature Set Validation

For each Feature Set, verify:

| Field | Required | Validation |
|-------|----------|------------|
| `id` | Yes | Format: `FS-XXX` (unique) |
| `name` | Yes | Non-empty string |
| `status` | Yes | One of: pending, in_progress, completed, blocked |
| `priority` | No | One of: critical, high, medium, low |
| `features` | Yes | Non-empty array |
| `dependencies` | No | Array of valid FS-XXX references |

#### 4. Feature Validation

For each Feature within a Feature Set:

| Field | Required | Validation |
|-------|----------|------------|
| `id` | Yes | Format: `F-XXX-YYY` (unique within set) |
| `name` | Yes | Non-empty string |
| `status` | Yes | One of: pending, in_progress, completed |
| `acceptance_criteria` | Recommended | List of testable criteria |

#### 5. Dependency Validation

The script performs these checks automatically:
- Validates all dependency references point to existing Feature Sets
- Detects circular dependencies using DFS cycle detection
- Generates topological sort to verify execution order

**Circular Dependency Detection Algorithm**:
```python
def detect_cycles(graph):
    cycles = []
    visited = set()
    rec_stack = set()
    path = []

    def dfs(node):
        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                if dfs(neighbor):
                    return True
            elif neighbor in rec_stack:
                # Found cycle
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                cycles.append(cycle)
                return True

        path.pop()
        rec_stack.remove(node)
        return False

    for node in graph:
        if node not in visited:
            dfs(node)

    return cycles
```

#### 6. Granularity Checks

Report warnings for:
- Feature Sets with > 10 features (consider splitting)
- Feature Sets with < 2 features (consider merging)
- Empty feature_sets array

#### 7. Status Consistency

Check for status inconsistencies:
- `completed` Feature Set with non-completed features
- `pending` Feature Set with `in_progress` or `completed` features

### Output Results

```
═══════════════════════════════════════════════════
[ValidateDeps] Feature Map Dependency Validation
═══════════════════════════════════════════════════
File: .FDD/feature_map.yaml
Feature Sets: 5

✓ All dependency checks passed

Execution preview:
  Wave 1: FS-001, FS-002
  Wave 2: FS-003, FS-004
  Wave 3: FS-005

═══════════════════════════════════════════════════
VALIDATION PASSED
═══════════════════════════════════════════════════
```

**With Warnings**:
```
⚠ Warnings:
  - Feature Set 'FS-003' has only 1 feature(s) (consider merging)
  - Feature Set 'FS-005' has 12 features (consider splitting)

═══════════════════════════════════════════════════
VALIDATION PASSED (with warnings)
═══════════════════════════════════════════════════
```

**With Errors**:
```
✗ Errors:
  - Feature Set 'FS-002' references non-existent dependency 'FS-099'
  - Circular dependency: FS-001 → FS-003 → FS-001

═══════════════════════════════════════════════════
VALIDATION FAILED
═══════════════════════════════════════════════════
```

### Priority-Based Wave Ordering

When generating execution waves, Feature Sets are ordered by priority within each wave:
1. `critical` - Execute first
2. `high`
3. `medium` (default)
4. `low` - Execute last

This ensures critical features are completed before less important ones when parallelization allows.

### Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{
  "timestamp": "2024-01-14T12:00:00Z",
  "event": "validation",
  "artifact": "feature_map",
  "result": "pass|fail|pass_with_warnings",
  "issues": []
}
```

## Return Values
- **PASS**: All checks passed (exit code 0)
- **PASS_WITH_WARNINGS**: Structure valid, but recommendations exist (exit code 0)
- **FAIL**: Critical issues found (exit code 1)

## Called By
- `/FDD-plan` (after Feature Map generation)
- `/FDD-improve` (during quality loop)
- `/FDD-develop` (before starting development)
