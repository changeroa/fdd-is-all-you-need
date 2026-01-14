# FDD Update Status

Update the status of a Feature or Feature Set in the Feature Map.

## Usage
```
/FDD-update-status <id> <status>
```

### Arguments
- `id`: Feature Set ID (`FS-XXX`) or Feature ID (`F-XXX-YYY`)
- `status`: One of `pending`, `in_progress`, `completed`, `blocked`

### Examples
```
/FDD-update-status FS-001 in_progress
/FDD-update-status F-001-002 completed
```

## Instructions

### 1. Acquire Lock (Concurrency Safety)

Before modifying the Feature Map, acquire an exclusive lock:
```bash
bash .FDD/scripts/file-lock.sh acquire .FDD/feature_map.yaml 30
```

This prevents race conditions when multiple agents update simultaneously.
If lock acquisition fails (timeout), report the conflict and retry later.

### 2. Load Feature Map
Read `.FDD/feature_map.yaml`.

### 3. Validate Input

**Status Validation**:
```
Valid statuses: pending | in_progress | completed | blocked
```

**ID Format Validation**:
- Feature Set: `FS-XXX` (e.g., FS-001)
- Feature: `F-XXX-YYY` (e.g., F-001-002)

### 4. Update Status

**For Feature Set (FS-XXX)**:
```yaml
# Before
feature_sets:
  - id: FS-001
    status: pending  # ← Change this
    features: [...]

# After
feature_sets:
  - id: FS-001
    status: in_progress  # ← Updated
    features: [...]
```

**Special Case - Completing Feature Set**:
When marking a Feature Set as `completed`, also mark all its features as `completed`.

**For Feature (F-XXX-YYY)**:
```yaml
feature_sets:
  - id: FS-001
    features:
      - id: F-001-002
        status: in_progress  # ← Update this
```

**Special Case - Auto-complete Feature Set**:
When a Feature is marked `completed`, check if all features in its set are completed.
If so, automatically mark the Feature Set as `completed`.

### 5. Update Metadata

Update the metadata section:
```yaml
metadata:
  updated_at: "2024-01-14T12:00:00Z"  # Current timestamp
  total_features: X      # Count of all features
  completed_features: Y  # Count of completed features
```

### 6. Save and Release Lock

Write updated Feature Map to `.FDD/feature_map.yaml`, then release the lock:
```bash
bash .FDD/scripts/file-lock.sh release .FDD/feature_map.yaml
```

**Important**: Always release the lock, even if an error occurs during update.

Output:
```
[Lock] Acquired lock on .FDD/feature_map.yaml
Updated Feature Set FS-001: pending → in_progress
Feature map updated successfully
[Lock] Released lock on .FDD/feature_map.yaml
```

Or for auto-completion:
```
Updated Feature F-001-003: in_progress → completed
  → Feature Set FS-001 automatically marked completed
Feature map updated successfully
```

### 7. Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{"timestamp":"ISO8601","event":"status_update","feature":"<id>","old_status":"<old>","new_status":"<new>"}
```

## Error Handling

**Feature Not Found**:
```
Feature not found: F-999-001
```

**Invalid Status**:
```
Invalid status: unknown
Valid statuses: pending, in_progress, completed, blocked
```

## Called By
- `/FDD-develop` (progress tracking)
- Manual status updates during development
