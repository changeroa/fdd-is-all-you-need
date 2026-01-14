# FDD Get Executable Features

Find Feature Sets that can be executed (all dependencies satisfied).

## Usage
```
/FDD-get-executable [max_count]
```
- `max_count`: Optional. Maximum number to return. Default: 3

## Instructions

### 1. Load Feature Map
Read `.FDD/feature_map.yaml` and extract `feature_sets`.

### 2. Build Status Map

Create a lookup of Feature Set statuses:
```
status_map = {
  "FS-001": "completed",
  "FS-002": "in_progress",
  "FS-003": "pending",
  ...
}
```

### 3. Find Executable Feature Sets

A Feature Set is **executable** if:
1. Its status is `pending` (not yet started)
2. ALL of its dependencies are `completed`

```
For each Feature Set:
  If status == "pending":
    If all dependencies have status == "completed":
      → Executable
    Else:
      → Blocked (list unmet dependencies)
```

### 4. Categorize Results

**Executable**: Ready to start
**Blocked**: Waiting on dependencies
**In Progress**: Already being worked on
**Completed**: Already done

### 5. Output Results

```markdown
=== Executable Feature Sets ===
1. FS-003: User Authentication (4 features)
   Dependencies: FS-001 (completed)
2. FS-004: API Integration (3 features)
   Dependencies: none
3. FS-005: Dashboard UI (5 features)
   Dependencies: FS-003, FS-004 (all completed)

Total executable: 3
Total blocked: 2

=== Blocked Feature Sets ===
- FS-006: Payment Processing
  Waiting on: FS-003, FS-007
- FS-007: Notification System
  Waiting on: FS-002

EXECUTABLE_IDS=FS-003,FS-004,FS-005
```

### 6. Return Value

The last line contains machine-readable output:
```
EXECUTABLE_IDS=FS-XXX,FS-YYY,FS-ZZZ
```

This can be used by other skills to determine what to work on next.

## Use Cases

**During `/FDD-develop`**:
- Identify which Feature Sets can be parallelized
- Determine next work items

**For `/FDD-status`**:
- Show blocked items and their blockers
- Help understand project flow

## Notes

- If no Feature Sets are executable, development cannot proceed
- Check if blocked items have circular dependencies
- Consider re-prioritizing if critical features are blocked
