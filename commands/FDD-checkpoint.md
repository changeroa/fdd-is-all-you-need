# FDD Checkpoint

Save the current Feature Map state as a checkpoint for later recovery.
Now with Git integration for complete state + code synchronization.

## Usage
```
/FDD-checkpoint [iteration] [feature_set_id] [message]
```
- `iteration`: Optional. Current iteration number
- `feature_set_id`: Optional. Feature Set just completed
- `message`: Optional. Checkpoint description

## Instructions

### Use Git-Integrated Checkpoint Script (Recommended)

```bash
bash .FDD/scripts/checkpoint-git.sh create [iteration] [feature_set_id] [message]
```

This automatically:
1. Creates a timestamped checkpoint file (with milliseconds to avoid collisions)
2. Commits all current changes to Git
3. Creates a Git tag for the checkpoint
4. Updates feature_map.yaml with checkpoint reference

### Manual Mode

If you need more control:

#### 1. Ensure Directory Structure

Create if not exists:
```
.FDD/
├── checkpoints/
└── logs/
```

#### 2. Create Checkpoint File

Copy current Feature Map to checkpoint with millisecond precision:
```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MILLIS=$(python3 -c "import time; print(int((time.time() % 1) * 1000))")
CHECKPOINT_FILE=".FDD/checkpoints/checkpoint_${TIMESTAMP}_${MILLIS}.yaml"
```

#### 3. Add Checkpoint Metadata

The checkpoint file includes:
```yaml
# Feature Map content...
feature_sets:
  - id: FS-001
    status: completed
    # ...

# Checkpoint Metadata
_checkpoint:
  name: "checkpoint_20240114_153045_123"
  created_at: "2024-01-14T15:30:45.123Z"
  iteration: 3
  feature_set: FS-002
  message: "Completed authentication module"
  git:
    enabled: true
    commit: "abc123def456"
    tag: "fdd-checkpoint_20240114_153045_123"
```

#### 4. Update Feature Map Reference

```yaml
execution:
  last_checkpoint: ".FDD/checkpoints/checkpoint_20240114_153045_123.yaml"
  current_iteration: 3
```

#### 5. Git Integration

If in a Git repository:
```bash
# Stage all changes
git add -A

# Commit with FDD prefix
git commit -m "[FDD] Checkpoint after FS-002: Completed authentication module"

# Create tag
git tag -a "fdd-checkpoint_20240114_153045_123" -m "FDD Checkpoint"
```

### Checkpoint List

View all checkpoints:
```bash
bash .FDD/scripts/checkpoint-git.sh list
```

Output:
```
═══════════════════════════════════════════════════
[FDD Checkpoint] Available Checkpoints
═══════════════════════════════════════════════════

1. checkpoint_20240114_153045_123 (latest)
   Created: 2024-01-14T15:30:45Z
   Iteration: 3
   Feature Set: FS-002
   Progress: 2/5 completed
   Git tag: fdd-checkpoint_20240114_153045_123

2. checkpoint_20240114_142030_456
   Created: 2024-01-14T14:20:30Z
   Iteration: 2
   Feature Set: FS-001
   Progress: 1/5 completed
   Git tag: fdd-checkpoint_20240114_142030_456
```

### Checkpoint Info

Get detailed info about a checkpoint:
```bash
bash .FDD/scripts/checkpoint-git.sh info checkpoint_20240114_153045_123
```

### Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{
  "timestamp": "2024-01-14T15:30:45Z",
  "event": "checkpoint",
  "type": "created",
  "message": "Checkpoint checkpoint_20240114_153045_123 created (git: true)"
}
```

## Output

```
═══════════════════════════════════════════════════
[FDD Checkpoint] Creating: checkpoint_20240114_153045_123
═══════════════════════════════════════════════════
[Checkpoint] Staging all changes...
[Checkpoint] Creating Git commit...
[Checkpoint] Created Git tag: fdd-checkpoint_20240114_153045_123

✓ Checkpoint created successfully
  Name: checkpoint_20240114_153045_123
  File: .FDD/checkpoints/checkpoint_20240114_153045_123.yaml
  Git commit: abc123de
  Git tag: fdd-checkpoint_20240114_153045_123
═══════════════════════════════════════════════════
```

## Recovery Options

### Restore Feature Map State Only
```bash
bash .FDD/scripts/checkpoint-git.sh restore latest
# or
bash .FDD/scripts/checkpoint-git.sh restore checkpoint_20240114_153045_123
```

### Restore Code + State (Full Rollback)
```bash
# 1. Restore Feature Map state
bash .FDD/scripts/checkpoint-git.sh restore checkpoint_20240114_153045_123

# 2. Restore code to that point
git checkout fdd-checkpoint_20240114_153045_123
# or for hard reset:
git reset --hard fdd-checkpoint_20240114_153045_123
```

### View Changes Since Checkpoint
```bash
git diff fdd-checkpoint_20240114_153045_123..HEAD
```

## Collision Prevention

Checkpoint names now include milliseconds to prevent collisions:
- Old format: `checkpoint_20240114_153045.yaml`
- New format: `checkpoint_20240114_153045_123.yaml`

This ensures unique names even when multiple checkpoints are created within the same second.

## Called By
- `/FDD-develop` (after each Feature Set completion)
- `fdd-orchestrator` agent (after each wave)
- Manually for safety saves
