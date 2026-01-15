# FDD Rollback

Rollback Feature Sets or restore from checkpoints after failures.
Now with Git integration for complete state + code rollback.

## Usage
```
/FDD-rollback <mode> [target]
```

### Modes

| Mode | Description | Target |
|------|-------------|--------|
| `list` | List available checkpoints | - |
| `checkpoint` | Restore from a checkpoint | Checkpoint filename or `latest` |
| `feature-set` | Reset a Feature Set to pending | Feature Set ID (e.g., FS-001) |
| `feature` | Reset a single Feature to pending | Feature ID (e.g., F-001-002) |
| `full` | Restore both state AND code | Checkpoint filename or `latest` |

### Examples
```
/FDD-rollback list
/FDD-rollback checkpoint latest
/FDD-rollback checkpoint checkpoint_20240114_153045_123
/FDD-rollback feature-set FS-003
/FDD-rollback feature F-002-001
/FDD-rollback full latest
```

## Instructions

### Mode: `list`

Use the checkpoint script:
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

### Mode: `checkpoint`

Restore Feature Map state from a checkpoint:

```bash
bash .FDD/scripts/checkpoint-git.sh restore <checkpoint_name|latest>
```

This will:
1. **Acquire lock** on feature_map.yaml
2. **Backup current state** to `.FDD/feature_map.yaml.pre-rollback`
3. **Restore Feature Map** from checkpoint
4. **Log rollback event**
5. **Release lock**
6. Show Git commands to restore code if needed

Output:
```
═══════════════════════════════════════════════════
[FDD Checkpoint] Restoring from: checkpoint_20240114_153045_123
═══════════════════════════════════════════════════
[Checkpoint] Current state backed up to: feature_map.yaml.pre-rollback
[Checkpoint] Feature map restored

[Checkpoint] Git restore options:
  1. View changes since checkpoint:
     git diff fdd-checkpoint_20240114_153045_123..HEAD

  2. Restore code to checkpoint state:
     git checkout fdd-checkpoint_20240114_153045_123
     # or
     git reset --hard fdd-checkpoint_20240114_153045_123

  Note: Feature Map state has been restored.
  Use the commands above to also restore code if needed.

✓ Feature Map restored successfully
═══════════════════════════════════════════════════
```

### Mode: `feature-set`

Reset a Feature Set and all its features to `pending`:

1. **Acquire lock** with agent ID:
```bash
bash .FDD/scripts/file-lock.sh acquire .FDD/feature_map.yaml rollback-agent 30 300
```

2. **Create pre-rollback backup**:
```bash
cp .FDD/feature_map.yaml .FDD/feature_map.yaml.pre-rollback
```

3. **Update Feature Set**:
```yaml
feature_sets:
  - id: FS-003
    status: pending  # Reset from in_progress/completed/blocked
    features:
      - id: F-003-001
        status: pending  # Reset all features
      - id: F-003-002
        status: pending
```

4. **Update metadata** (recalculate completed counts)

5. **Save atomically**:
```bash
cat updated.yaml | bash .FDD/scripts/atomic-write.sh update .FDD/feature_map.yaml
```

6. **Log rollback event**:
```json
{"timestamp":"...","event":"rollback","type":"feature_set","target":"FS-003","previous_status":"blocked"}
```

7. **Release lock**:
```bash
bash .FDD/scripts/file-lock.sh release .FDD/feature_map.yaml rollback-agent
```

Output:
```
═══════════════════════════════════════════════════
[FDD Rollback] Feature Set Reset
═══════════════════════════════════════════════════
Reset FS-003: blocked → pending
Reset features: F-003-001, F-003-002, F-003-003

Note: Implementation code is preserved. Re-run /FDD-develop to retry.
═══════════════════════════════════════════════════
```

### Mode: `feature`

Reset a single Feature to `pending`:

1. **Acquire lock**
2. **Update Feature status**:
```yaml
features:
  - id: F-002-003
    status: pending  # Reset from in_progress/completed
```

3. **Update parent Feature Set status** if it was `completed`:
   - Change to `in_progress` (since not all features are complete anymore)

4. **Save atomically**
5. **Log event**
6. **Release lock**

### Mode: `full`

Full rollback - restore both Feature Map state AND code:

```bash
# 1. Restore Feature Map state
bash .FDD/scripts/checkpoint-git.sh restore <checkpoint_name|latest>

# 2. Get the Git tag from checkpoint info
bash .FDD/scripts/checkpoint-git.sh info <checkpoint_name>

# 3. Restore code
git reset --hard fdd-<checkpoint_name>
```

**Warning**: This discards all code changes since the checkpoint!

Output:
```
═══════════════════════════════════════════════════
[FDD Rollback] Full Restore
═══════════════════════════════════════════════════
⚠ WARNING: This will discard all code changes since checkpoint!

Checkpoint: checkpoint_20240114_153045_123
Git tag: fdd-checkpoint_20240114_153045_123

Proceed? (Requires explicit confirmation)

If confirmed:
1. Feature Map restored
2. Git reset to fdd-checkpoint_20240114_153045_123
3. Working directory matches checkpoint state

═══════════════════════════════════════════════════
```

## Rollback Strategies

### After Agent Failure

When a `fdd-developer` agent fails mid-Feature-Set:

```
Scenario: FS-003 has 5 features, agent completed 3 and failed on 4th

Option 1: Rollback entire Feature Set
  /FDD-rollback feature-set FS-003
  Result: All 5 features reset to pending, retry from beginning

Option 2: Rollback single Feature (preserve progress)
  /FDD-rollback feature F-003-004
  Result: Only F-003-004 reset, features 1-3 remain completed
  Then: Manually fix F-003-004 or resume development

Option 3: Check if timeout caused it
  bash .FDD/scripts/timeout-monitor.sh reset FS-003
```

### After Corrupted State

If feature_map.yaml is corrupted or inconsistent:

```bash
# Restore from last checkpoint
bash .FDD/scripts/checkpoint-git.sh restore latest
```

### After State-Code Mismatch

If Feature Map says completed but code is wrong:

```bash
# Check consistency first
bash .FDD/scripts/validate-consistency.sh check

# If mismatch found, full rollback
/FDD-rollback full latest
```

### Undo Recent Change

If a recent status update was wrong:

```bash
# Check pre-rollback backup
cat .FDD/feature_map.yaml.pre-rollback

# If needed, restore it
cp .FDD/feature_map.yaml.pre-rollback .FDD/feature_map.yaml
```

## Safety Features

### Pre-Rollback Backup

Every rollback operation creates a backup:
```
.FDD/feature_map.yaml.pre-rollback
```

This allows undoing the rollback itself if needed.

### Lock Requirement

All rollback operations acquire exclusive lock with agent ID to prevent concurrent modifications.

### Atomic Operations

All state changes use atomic-write.sh to prevent corruption during rollback.

### Logging

All rollback events are logged to `.FDD/logs/events.jsonl`:
```json
{
  "timestamp": "2024-01-14T15:45:00Z",
  "event": "rollback",
  "type": "checkpoint|feature_set|feature|full",
  "target": "checkpoint_20240114_153045_123",
  "backed_up_to": "feature_map.yaml.pre-rollback"
}
```

## Important Notes

1. **State-only rollback** (`checkpoint` mode) - Only Feature Map changes. Code remains as-is.

2. **Full rollback** (`full` mode) - Both state AND code restored. All changes since checkpoint are lost.

3. **Git integration** - Checkpoints have associated Git tags for code restoration.

4. **For code-only rollback**, use Git directly:
   ```bash
   git log --oneline  # Find commit before feature implementation
   git checkout <commit> -- <files>  # Restore specific files
   ```

5. **Combine strategies** for partial rollback:
   ```bash
   # 1. Rollback Feature Map state
   /FDD-rollback feature-set FS-003

   # 2. Rollback code using Git
   git checkout HEAD~3 -- src/features/fs-003/
   ```

## Called By
- Manual intervention after failures
- `/FDD-develop` when deadlock or failure detected
- Orchestrator for automated recovery
