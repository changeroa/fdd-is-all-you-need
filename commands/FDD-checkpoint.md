# FDD Checkpoint

Save the current Feature Map state as a checkpoint for later recovery.

## Usage
```
/FDD-checkpoint [iteration] [feature_set_id]
```
- `iteration`: Optional. Current iteration number
- `feature_set_id`: Optional. Feature Set just completed

## Instructions

### 1. Ensure Directory Structure

Create if not exists:
```
.FDD/
├── checkpoints/
└── logs/
```

### 2. Create Checkpoint File

Copy current Feature Map to checkpoint:
```
.FDD/checkpoints/checkpoint_YYYYMMDD_HHMMSS.yaml
```

Timestamp format: `20240114_153045` (year-month-day_hour-minute-second)

### 3. Add Checkpoint Metadata

Append to the checkpoint file:
```yaml
# --- Checkpoint Metadata ---
checkpoint:
  created_at: "2024-01-14T15:30:45Z"
  iteration: 3
  feature_set: FS-002
  trigger: "iteration_complete"  # or "manual"
```

### 4. Update Feature Map Reference

Add checkpoint reference to the current Feature Map:
```yaml
execution:
  last_checkpoint: ".FDD/checkpoints/checkpoint_20240114_153045.yaml"
  current_iteration: 3
```

### 5. Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{"timestamp":"ISO8601","event":"checkpoint_created","file":"checkpoint_20240114_153045.yaml","iteration":3,"feature_set":"FS-002"}
```

### 6. Output

```
[FDD] Checkpoint saved: .FDD/checkpoints/checkpoint_20240114_153045.yaml
[FDD] Iteration 3 complete
```

## Checkpoint Contents

A checkpoint file is a complete Feature Map snapshot:
```yaml
metadata:
  project_name: "My Project"
  created_at: "2024-01-14T10:00:00Z"
  updated_at: "2024-01-14T15:30:45Z"
  total_features: 20
  completed_features: 8

business_context:
  # ... (preserved)

design_context:
  # ... (preserved)

feature_sets:
  - id: FS-001
    status: completed
    # ...
  - id: FS-002
    status: completed  # Just finished
    # ...
  - id: FS-003
    status: pending
    # ...

# --- Checkpoint Metadata ---
checkpoint:
  created_at: "2024-01-14T15:30:45Z"
  iteration: 3
  feature_set: FS-002
```

## Recovery

To restore from checkpoint, use `/FDD-resume` which will:
1. Find the latest checkpoint
2. Load the Feature Map state
3. Resume development from where it stopped

## Called By
- `/FDD-develop` (after each Feature Set completion)
- Manually for safety saves
