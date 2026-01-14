# FDD Rollback

Rollback Feature Sets or restore from checkpoints after failures.

## Usage
```
/FDD-rollback <mode> [target]
```

### Modes

| Mode | Description | Target |
|------|-------------|--------|
| `checkpoint` | Restore from a checkpoint | Checkpoint filename or `latest` |
| `feature-set` | Reset a Feature Set to pending | Feature Set ID (e.g., FS-001) |
| `feature` | Reset a single Feature to pending | Feature ID (e.g., F-001-002) |
| `list` | List available checkpoints | - |

### Examples
```
/FDD-rollback list
/FDD-rollback checkpoint latest
/FDD-rollback checkpoint checkpoint_20240114_153045.yaml
/FDD-rollback feature-set FS-003
/FDD-rollback feature F-002-001
```

## Instructions

### Mode: `list`

List all available checkpoints:
```
ls -la .FDD/checkpoints/
```

Output:
```
=== Available Checkpoints ===
1. checkpoint_20240114_153045.yaml (latest)
   - Created: 2024-01-14 15:30:45
   - Iteration: 3
   - Feature Set: FS-002

2. checkpoint_20240114_142030.yaml
   - Created: 2024-01-14 14:20:30
   - Iteration: 2
   - Feature Set: FS-001

3. checkpoint_20240114_130015.yaml
   - Created: 2024-01-14 13:00:15
   - Iteration: 1
   - Feature Set: FS-001
```

### Mode: `checkpoint`

Restore Feature Map state from a checkpoint:

1. **Acquire lock** on feature_map.yaml
2. **Backup current state**:
   ```
   cp .FDD/feature_map.yaml .FDD/feature_map.yaml.pre-rollback
   ```
3. **Load checkpoint**:
   - If `latest`: Find most recent file in `.FDD/checkpoints/`
   - Otherwise: Load specified checkpoint file
4. **Restore Feature Map**:
   ```
   cp .FDD/checkpoints/<checkpoint> .FDD/feature_map.yaml
   ```
5. **Remove checkpoint metadata** from restored file (the `checkpoint:` section at the end)
6. **Log rollback event**
7. **Release lock**

Output:
```
=== Checkpoint Rollback ===
Restored from: checkpoint_20240114_153045.yaml
Previous state backed up to: feature_map.yaml.pre-rollback

State after rollback:
- Completed: FS-001, FS-002
- In Progress: (none)
- Pending: FS-003, FS-004, FS-005

Note: Code changes are NOT rolled back. Only Feature Map state is restored.
```

### Mode: `feature-set`

Reset a Feature Set and all its features to `pending`:

1. **Acquire lock** on feature_map.yaml
2. **Create pre-rollback backup**
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
5. **Log rollback event**:
   ```json
   {"timestamp":"...","event":"rollback","type":"feature_set","target":"FS-003","previous_status":"blocked"}
   ```
6. **Release lock**

Output:
```
=== Feature Set Rollback ===
Reset FS-003: blocked → pending
Reset features: F-003-001, F-003-002, F-003-003

Note: Implementation code is preserved. Re-run /FDD-develop to retry.
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
4. **Log event**
5. **Release lock**

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
```

### After Corrupted State

If feature_map.yaml is corrupted or inconsistent:

```
/FDD-rollback checkpoint latest
```

This restores the last known good state.

### Undo Recent Change

If a recent status update was wrong:

```
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

All rollback operations acquire exclusive lock to prevent concurrent modifications.

### Logging

All rollback events are logged to `.FDD/logs/events.jsonl`:
```json
{
  "timestamp": "2024-01-14T15:45:00Z",
  "event": "rollback",
  "type": "checkpoint",
  "source": "checkpoint_20240114_153045.yaml",
  "backed_up_to": "feature_map.yaml.pre-rollback"
}
```

## Important Notes

1. **Code is NOT rolled back** - Only Feature Map state changes. Implemented code remains in the codebase.

2. **Checkpoints are Feature Map snapshots** - They don't include code state.

3. **For code rollback**, use Git:
   ```bash
   git log --oneline  # Find commit before feature implementation
   git checkout <commit> -- <files>  # Restore specific files
   ```

4. **Combine strategies** for full rollback:
   ```
   # 1. Rollback Feature Map state
   /FDD-rollback feature-set FS-003

   # 2. Rollback code using Git
   git checkout HEAD~3 -- src/features/fs-003/
   ```

## Called By
- Manual intervention after failures
- `/FDD-develop` when deadlock or failure detected
- Orchestrator for automated recovery
