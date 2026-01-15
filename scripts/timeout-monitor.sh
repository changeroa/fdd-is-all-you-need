#!/bin/bash
# FDD Timeout Monitor
# Monitors in_progress states and handles timeouts
#
# Features:
# - Detects stale in_progress Feature Sets
# - Configurable timeout thresholds
# - Auto-recovery options
# - Status reporting
#
# Usage:
#   timeout-monitor.sh check [feature_map_path]
#   timeout-monitor.sh mark-stale [feature_map_path]
#   timeout-monitor.sh reset <feature_set_id> [feature_map_path]
#   timeout-monitor.sh watch [interval_seconds] [feature_map_path]

set -e

ACTION="${1:-check}"
ARG1="$2"
ARG2="$3"

FDD_DIR=".FDD"
FEATURE_MAP="${ARG2:-${ARG1:-.FDD/feature_map.yaml}}"
CONFIG_FILE="$FDD_DIR/config.yaml"
LOG_FILE="$FDD_DIR/logs/events.jsonl"
STATE_FILE="$FDD_DIR/.progress-state.json"

# Default timeout: 30 minutes (1800 seconds)
DEFAULT_TIMEOUT=1800

# Ensure directories exist
mkdir -p "$FDD_DIR/logs"

# JSON-safe logging
log_event() {
    local event_type="$1"
    local message="$2"

    python3 -c "
import json
from datetime import datetime, timezone

event = {
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'event': 'timeout_monitor',
    'type': '''$event_type''',
    'message': '''$message'''
}
print(json.dumps(event))
" >> "$LOG_FILE"
}

# Get timeout from config
get_timeout() {
    if [ -f "$CONFIG_FILE" ]; then
        local timeout=$(python3 -c "
import yaml
try:
    with open('$CONFIG_FILE') as f:
        cfg = yaml.safe_load(f) or {}
    print(cfg.get('feature_development', {}).get('default_timeout', $DEFAULT_TIMEOUT) // 1000)
except:
    print($DEFAULT_TIMEOUT)
")
        echo "$timeout"
    else
        echo "$DEFAULT_TIMEOUT"
    fi
}

# Update progress state (track when each FS entered in_progress)
update_state() {
    python3 << 'PYTHON_EOF'
import yaml
import json
import os
from datetime import datetime, timezone

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')
state_file = os.environ.get('STATE_FILE', '.FDD/.progress-state.json')

# Load current state
state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except:
        state = {}

# Load feature map
try:
    with open(feature_map_path) as f:
        data = yaml.safe_load(f) or {}
except:
    print("Error loading feature map")
    exit(1)

now = datetime.now(timezone.utc).isoformat()
updated = False

for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')
    status = fs.get('status', 'pending')

    if status == 'in_progress':
        if fs_id not in state or state[fs_id].get('status') != 'in_progress':
            # Just entered in_progress
            state[fs_id] = {
                'status': 'in_progress',
                'started_at': now,
                'last_activity': now
            }
            updated = True
        else:
            # Update last activity
            state[fs_id]['last_activity'] = now
    elif fs_id in state:
        # Status changed from in_progress
        state[fs_id] = {
            'status': status,
            'completed_at': now
        }
        updated = True

# Save state
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)

if updated:
    print("State updated")
PYTHON_EOF
}

# Check for timeout violations
check_timeouts() {
    export FEATURE_MAP
    export STATE_FILE
    export TIMEOUT=$(get_timeout)

    python3 << 'PYTHON_EOF'
import yaml
import json
import os
from datetime import datetime, timezone

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')
state_file = os.environ.get('STATE_FILE', '.FDD/.progress-state.json')
timeout = int(os.environ.get('TIMEOUT', 1800))

# Load state
state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except:
        pass

# Load feature map
try:
    with open(feature_map_path) as f:
        data = yaml.safe_load(f) or {}
except:
    print("Error loading feature map")
    exit(1)

now = datetime.now(timezone.utc)
stale = []
active = []

print("═══════════════════════════════════════════════════")
print("[FDD Timeout Monitor] Status Check")
print(f"Timeout threshold: {timeout}s ({timeout // 60} minutes)")
print("═══════════════════════════════════════════════════")
print()

for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')
    fs_name = fs.get('name', 'Unknown')
    status = fs.get('status', 'pending')

    if status == 'in_progress':
        fs_state = state.get(fs_id, {})
        started_str = fs_state.get('started_at')

        if started_str:
            try:
                started = datetime.fromisoformat(started_str.replace('Z', '+00:00'))
                elapsed = (now - started).total_seconds()

                if elapsed > timeout:
                    stale.append({
                        'id': fs_id,
                        'name': fs_name,
                        'elapsed': elapsed,
                        'started': started_str
                    })
                else:
                    active.append({
                        'id': fs_id,
                        'name': fs_name,
                        'elapsed': elapsed,
                        'remaining': timeout - elapsed
                    })
            except:
                # Can't parse time, treat as stale
                stale.append({
                    'id': fs_id,
                    'name': fs_name,
                    'elapsed': -1,
                    'started': 'Unknown'
                })
        else:
            # No state info, treat as just started
            active.append({
                'id': fs_id,
                'name': fs_name,
                'elapsed': 0,
                'remaining': timeout
            })

if active:
    print("Active (within timeout):")
    for item in active:
        remaining_min = int(item['remaining'] // 60)
        elapsed_min = int(item['elapsed'] // 60)
        print(f"  → {item['id']}: {item['name']}")
        print(f"    Running: {elapsed_min}m, Remaining: {remaining_min}m")
    print()

if stale:
    print("⚠ STALE (exceeded timeout):")
    for item in stale:
        elapsed_min = int(item['elapsed'] // 60) if item['elapsed'] > 0 else '?'
        print(f"  ✗ {item['id']}: {item['name']}")
        print(f"    Started: {item['started']}")
        print(f"    Elapsed: {elapsed_min}m (timeout: {timeout // 60}m)")
    print()
    print(f"To reset stale Feature Sets, run:")
    for item in stale:
        print(f"  timeout-monitor.sh reset {item['id']}")
    exit(1)
else:
    if not active:
        print("No Feature Sets currently in progress.")
    else:
        print("✓ All in_progress Feature Sets are within timeout")

print()
print("═══════════════════════════════════════════════════")
PYTHON_EOF
}

# Mark stale Feature Sets as blocked
mark_stale() {
    export FEATURE_MAP
    export STATE_FILE
    export TIMEOUT=$(get_timeout)

    python3 << 'PYTHON_EOF'
import yaml
import json
import os
from datetime import datetime, timezone

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')
state_file = os.environ.get('STATE_FILE', '.FDD/.progress-state.json')
timeout = int(os.environ.get('TIMEOUT', 1800))

# Load state
state = {}
if os.path.exists(state_file):
    try:
        with open(state_file) as f:
            state = json.load(f)
    except:
        pass

# Load feature map
with open(feature_map_path) as f:
    data = yaml.safe_load(f) or {}

now = datetime.now(timezone.utc)
marked = []

for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')
    status = fs.get('status', 'pending')

    if status == 'in_progress':
        fs_state = state.get(fs_id, {})
        started_str = fs_state.get('started_at')

        if started_str:
            try:
                started = datetime.fromisoformat(started_str.replace('Z', '+00:00'))
                elapsed = (now - started).total_seconds()

                if elapsed > timeout:
                    fs['status'] = 'blocked'
                    fs['blocked_reason'] = f'Timeout after {int(elapsed)}s'
                    marked.append(fs_id)
            except:
                fs['status'] = 'blocked'
                fs['blocked_reason'] = 'Timeout (unknown duration)'
                marked.append(fs_id)

if marked:
    with open(feature_map_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    print(f"Marked {len(marked)} Feature Set(s) as blocked:")
    for fs_id in marked:
        print(f"  - {fs_id}")
else:
    print("No stale Feature Sets found")
PYTHON_EOF

    log_event "mark_stale" "Marked stale Feature Sets as blocked"
}

# Reset a Feature Set to pending
reset_feature_set() {
    local fs_id="$1"

    if [ -z "$fs_id" ]; then
        echo "[Timeout] Error: Feature Set ID required"
        exit 1
    fi

    export FEATURE_MAP
    export FS_ID="$fs_id"

    python3 << 'PYTHON_EOF'
import yaml
import os

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')
fs_id = os.environ.get('FS_ID')

with open(feature_map_path) as f:
    data = yaml.safe_load(f) or {}

found = False
for fs in data.get('feature_sets', []):
    if fs.get('id') == fs_id:
        old_status = fs.get('status')
        fs['status'] = 'pending'
        if 'blocked_reason' in fs:
            del fs['blocked_reason']

        # Also reset all features in this set
        for feature in fs.get('features', []):
            if feature.get('status') in ['in_progress', 'blocked']:
                feature['status'] = 'pending'

        found = True
        print(f"Reset {fs_id}: {old_status} → pending")
        break

if not found:
    print(f"Feature Set not found: {fs_id}")
    exit(1)

with open(feature_map_path, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYTHON_EOF

    log_event "reset" "Reset Feature Set $fs_id to pending"
}

# Watch mode - continuous monitoring
watch_mode() {
    local interval="${1:-60}"
    local feature_map="${2:-.FDD/feature_map.yaml}"

    export FEATURE_MAP="$feature_map"
    export STATE_FILE

    echo "[Timeout Monitor] Starting watch mode (interval: ${interval}s)"
    echo "Press Ctrl+C to stop"
    echo ""

    while true; do
        update_state
        check_timeouts || true
        echo ""
        echo "Next check in ${interval}s..."
        sleep "$interval"
        clear
    done
}

case "$ACTION" in
    check)
        if [ -n "$ARG1" ] && [ "$ARG1" != "-" ]; then
            FEATURE_MAP="$ARG1"
        fi
        export FEATURE_MAP
        export STATE_FILE
        update_state
        check_timeouts
        ;;
    mark-stale)
        if [ -n "$ARG1" ] && [ "$ARG1" != "-" ]; then
            FEATURE_MAP="$ARG1"
        fi
        export FEATURE_MAP
        export STATE_FILE
        update_state
        mark_stale
        ;;
    reset)
        FEATURE_MAP="${ARG2:-.FDD/feature_map.yaml}"
        export FEATURE_MAP
        reset_feature_set "$ARG1"
        ;;
    watch)
        watch_mode "$ARG1" "$ARG2"
        ;;
    *)
        echo "FDD Timeout Monitor"
        echo ""
        echo "Usage:"
        echo "  timeout-monitor.sh check [feature_map_path]"
        echo "  timeout-monitor.sh mark-stale [feature_map_path]"
        echo "  timeout-monitor.sh reset <feature_set_id> [feature_map_path]"
        echo "  timeout-monitor.sh watch [interval_seconds] [feature_map_path]"
        exit 1
        ;;
esac
