# FDD Update Status

Update the status of a Feature or Feature Set in the Feature Map.

## Usage
```
/FDD-update-status <id> <status> [agent_id]
```

### Arguments
- `id`: Feature Set ID (`FS-XXX`) or Feature ID (`F-XXX-YYY`)
- `status`: One of `pending`, `in_progress`, `completed`, `blocked`
- `agent_id`: Optional. Agent identifier for lock ownership (default: generated from context)

### Examples
```
/FDD-update-status FS-001 in_progress fdd-developer-001
/FDD-update-status F-001-002 completed fdd-developer-001
```

## Instructions

### 1. Generate Agent ID

If not provided, generate a unique agent ID:
```bash
AGENT_ID="${3:-fdd-agent-$(date +%s%N | tail -c 6)}"
```

### 2. Acquire Lock (Agent ID Based)

Use the new agent-based locking mechanism:
```bash
bash .FDD/scripts/file-lock.sh acquire .FDD/feature_map.yaml "$AGENT_ID" 30 300
```

Parameters:
- `30`: Timeout in seconds (wait up to 30s to acquire)
- `300`: TTL in seconds (lock expires after 5 minutes if not released)

If lock acquisition fails:
1. Check who holds the lock: `bash .FDD/scripts/file-lock.sh status .FDD/feature_map.yaml`
2. If lock is stale/expired, it will be auto-cleaned
3. Report conflict if another agent is actively holding the lock

### 3. Load Feature Map

Read `.FDD/feature_map.yaml` using atomic read pattern.

### 4. Validate Input

**Status Validation**:
```
Valid statuses: pending | in_progress | completed | blocked
```

**ID Format Validation**:
- Feature Set: `FS-XXX` (e.g., FS-001)
- Feature: `F-XXX-YYY` (e.g., F-001-002)

### 5. Update Status

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

### 6. Update Metadata

Update the metadata section:
```yaml
metadata:
  updated_at: "2024-01-14T12:00:00Z"  # Current timestamp
  total_features: X      # Count of all features
  completed_features: Y  # Count of completed features
```

### 7. Save Using Atomic Write

Use atomic write to prevent corruption:
```bash
# Write updated content to feature map atomically
cat updated_content.yaml | bash .FDD/scripts/atomic-write.sh update .FDD/feature_map.yaml
```

### 8. Release Lock

Always release the lock after update, even if an error occurred:
```bash
bash .FDD/scripts/file-lock.sh release .FDD/feature_map.yaml "$AGENT_ID"
```

**Important**: Use try/finally pattern - lock MUST be released.

### 9. Output

```
[Lock] Acquired lock on .FDD/feature_map.yaml (Agent: fdd-developer-001)
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

### 10. Log Event

Append to `.FDD/logs/events.jsonl` using JSON-safe format:
```bash
python3 -c "
import json
from datetime import datetime, timezone
event = {
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'event': 'status_update',
    'feature': '<id>',
    'old_status': '<old>',
    'new_status': '<new>',
    'agent_id': '<agent_id>'
}
print(json.dumps(event))
" >> .FDD/logs/events.jsonl
```

## Error Handling

**Lock Timeout**:
```
[Lock] Timeout waiting for lock on .FDD/feature_map.yaml
[Lock] Current holder: fdd-developer-002 (Age: 45s)
Suggestion: Wait for other agent to complete, or use force-release if stuck
```

**Feature Not Found**:
```
Feature not found: F-999-001
```

**Invalid Status**:
```
Invalid status: unknown
Valid statuses: pending, in_progress, completed, blocked
```

**Lock Cleanup**:
If locks become stale, run:
```bash
bash .FDD/scripts/file-lock.sh cleanup .FDD/
```

## Race Condition Prevention

The new locking mechanism prevents race conditions by:
1. **Agent ID ownership**: Only the agent that acquired the lock can release it
2. **TTL expiration**: Stale locks auto-expire after TTL (default 5 minutes)
3. **Atomic directory creation**: Uses `mkdir` for atomic lock acquisition
4. **Re-entrant locks**: Same agent can refresh its own lock

## Called By
- `/FDD-develop` (progress tracking)
- `fdd-developer` agent (feature completion)
- `fdd-orchestrator` agent (wave completion)
- Manual status updates during development
