#!/bin/bash
# FDD Git-Integrated Checkpoint System
# Creates checkpoints that include both Feature Map state AND Git commits
#
# Features:
# - Automatic Git commit on checkpoint
# - Git tag for each checkpoint
# - Rollback includes Git revert option
# - Code and state stay synchronized
#
# Usage:
#   checkpoint-git.sh create [iteration] [feature_set_id] [message]
#   checkpoint-git.sh restore <checkpoint_name|latest>
#   checkpoint-git.sh list
#   checkpoint-git.sh info <checkpoint_name>

set -e

ACTION="${1:-create}"
ARG1="$2"
ARG2="$3"
ARG3="$4"

FDD_DIR=".FDD"
CHECKPOINT_DIR="$FDD_DIR/checkpoints"
LOG_FILE="$FDD_DIR/logs/events.jsonl"
FEATURE_MAP="$FDD_DIR/feature_map.yaml"

# Ensure directories exist
mkdir -p "$CHECKPOINT_DIR"
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
    'event': 'checkpoint',
    'type': '''$event_type''',
    'message': '''$message'''
}
print(json.dumps(event))
" >> "$LOG_FILE"
}

# Check if in a Git repository
check_git() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "[Checkpoint] Warning: Not a Git repository. Git integration disabled."
        return 1
    fi
    return 0
}

# Generate checkpoint name with milliseconds to avoid collisions
generate_checkpoint_name() {
    # Include milliseconds for uniqueness
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local millis=$(python3 -c "import time; print(int((time.time() % 1) * 1000))")
    echo "checkpoint_${timestamp}_${millis}"
}

# Create checkpoint
create_checkpoint() {
    local iteration="${1:-0}"
    local feature_set="${2:-}"
    local message="${3:-Checkpoint}"

    local checkpoint_name=$(generate_checkpoint_name)
    local checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}.yaml"
    local git_enabled=false
    local git_commit=""
    local git_tag=""

    echo "═══════════════════════════════════════════════════"
    echo "[FDD Checkpoint] Creating: $checkpoint_name"
    echo "═══════════════════════════════════════════════════"

    # Check if Feature Map exists
    if [ ! -f "$FEATURE_MAP" ]; then
        echo "[Checkpoint] Error: Feature map not found: $FEATURE_MAP"
        exit 1
    fi

    # Git operations
    if check_git; then
        git_enabled=true

        # Check for uncommitted changes
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "[Checkpoint] Staging all changes..."
            git add -A

            # Create commit
            local commit_msg="[FDD] $message"
            if [ -n "$feature_set" ]; then
                commit_msg="[FDD] Checkpoint after $feature_set: $message"
            fi

            echo "[Checkpoint] Creating Git commit..."
            git commit -m "$commit_msg" --allow-empty || true
        fi

        # Get current commit hash
        git_commit=$(git rev-parse HEAD)

        # Create Git tag
        git_tag="fdd-${checkpoint_name}"
        git tag -a "$git_tag" -m "FDD Checkpoint: $message" 2>/dev/null || {
            # Tag exists, append random suffix
            git_tag="fdd-${checkpoint_name}-$(date +%s)"
            git tag -a "$git_tag" -m "FDD Checkpoint: $message"
        }
        echo "[Checkpoint] Created Git tag: $git_tag"
    fi

    # Create checkpoint file with metadata
    python3 << PYTHON_EOF
import yaml
import json
from datetime import datetime, timezone

# Load current feature map
with open('$FEATURE_MAP', 'r') as f:
    data = yaml.safe_load(f) or {}

# Add checkpoint metadata
data['_checkpoint'] = {
    'name': '$checkpoint_name',
    'created_at': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'iteration': $iteration,
    'feature_set': '$feature_set' if '$feature_set' else None,
    'message': '$message',
    'git': {
        'enabled': $( [ "$git_enabled" = "true" ] && echo "True" || echo "False" ),
        'commit': '$git_commit' if '$git_commit' else None,
        'tag': '$git_tag' if '$git_tag' else None
    }
}

# Write checkpoint file
with open('$checkpoint_file', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"[Checkpoint] Saved to: $checkpoint_file")
PYTHON_EOF

    # Update feature map with checkpoint reference
    python3 << PYTHON_EOF
import yaml

with open('$FEATURE_MAP', 'r') as f:
    data = yaml.safe_load(f) or {}

if 'execution' not in data:
    data['execution'] = {}

data['execution']['last_checkpoint'] = '$checkpoint_file'
data['execution']['current_iteration'] = $iteration

with open('$FEATURE_MAP', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYTHON_EOF

    log_event "created" "Checkpoint $checkpoint_name created (git: $git_enabled)"

    echo ""
    echo "✓ Checkpoint created successfully"
    echo "  Name: $checkpoint_name"
    echo "  File: $checkpoint_file"
    if [ "$git_enabled" = "true" ]; then
        echo "  Git commit: ${git_commit:0:8}"
        echo "  Git tag: $git_tag"
    fi
    echo "═══════════════════════════════════════════════════"
}

# Restore from checkpoint
restore_checkpoint() {
    local checkpoint_name="$1"

    if [ -z "$checkpoint_name" ]; then
        echo "[Checkpoint] Error: Checkpoint name required"
        exit 1
    fi

    local checkpoint_file=""

    if [ "$checkpoint_name" = "latest" ]; then
        checkpoint_file=$(ls -t "$CHECKPOINT_DIR"/*.yaml 2>/dev/null | head -1)
        if [ -z "$checkpoint_file" ]; then
            echo "[Checkpoint] Error: No checkpoints found"
            exit 1
        fi
    else
        checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}.yaml"
        if [ ! -f "$checkpoint_file" ]; then
            # Try without .yaml extension
            checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}"
        fi
    fi

    if [ ! -f "$checkpoint_file" ]; then
        echo "[Checkpoint] Error: Checkpoint not found: $checkpoint_name"
        exit 1
    fi

    echo "═══════════════════════════════════════════════════"
    echo "[FDD Checkpoint] Restoring from: $(basename "$checkpoint_file")"
    echo "═══════════════════════════════════════════════════"

    # Extract checkpoint metadata
    local git_tag=""
    local git_commit=""

    git_info=$(python3 << PYTHON_EOF
import yaml
import json

with open('$checkpoint_file', 'r') as f:
    data = yaml.safe_load(f) or {}

meta = data.get('_checkpoint', {})
git = meta.get('git', {})

print(json.dumps({
    'tag': git.get('tag'),
    'commit': git.get('commit'),
    'enabled': git.get('enabled', False)
}))
PYTHON_EOF
)

    git_tag=$(echo "$git_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag') or '')")
    git_commit=$(echo "$git_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('commit') or '')")
    git_enabled=$(echo "$git_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('enabled', False))")

    # Backup current feature map
    local backup_file="$FEATURE_MAP.pre-restore"
    cp "$FEATURE_MAP" "$backup_file"
    echo "[Checkpoint] Current state backed up to: $backup_file"

    # Restore feature map (remove checkpoint metadata)
    python3 << PYTHON_EOF
import yaml

with open('$checkpoint_file', 'r') as f:
    data = yaml.safe_load(f) or {}

# Remove checkpoint metadata
if '_checkpoint' in data:
    del data['_checkpoint']

with open('$FEATURE_MAP', 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print("[Checkpoint] Feature map restored")
PYTHON_EOF

    # Git restore
    if [ "$git_enabled" = "True" ] && check_git; then
        echo ""
        echo "[Checkpoint] Git restore options:"
        echo "  1. View changes since checkpoint:"
        echo "     git diff $git_commit..HEAD"
        echo ""
        echo "  2. Restore code to checkpoint state:"
        echo "     git checkout $git_tag"
        echo "     # or"
        echo "     git reset --hard $git_commit"
        echo ""
        echo "  Note: Feature Map state has been restored."
        echo "  Use the commands above to also restore code if needed."
    fi

    log_event "restored" "Restored from $(basename "$checkpoint_file")"

    echo ""
    echo "✓ Feature Map restored successfully"
    echo "═══════════════════════════════════════════════════"
}

# List checkpoints
list_checkpoints() {
    echo "═══════════════════════════════════════════════════"
    echo "[FDD Checkpoint] Available Checkpoints"
    echo "═══════════════════════════════════════════════════"

    if [ ! -d "$CHECKPOINT_DIR" ] || [ -z "$(ls -A "$CHECKPOINT_DIR" 2>/dev/null)" ]; then
        echo "No checkpoints found."
        return
    fi

    local count=0
    for file in $(ls -t "$CHECKPOINT_DIR"/*.yaml 2>/dev/null); do
        ((count++))
        local name=$(basename "$file" .yaml)
        local info=$(python3 << PYTHON_EOF
import yaml
from datetime import datetime

with open('$file', 'r') as f:
    data = yaml.safe_load(f) or {}

meta = data.get('_checkpoint', {})
created = meta.get('created_at', 'Unknown')
iteration = meta.get('iteration', '?')
fs = meta.get('feature_set', '-')
git = meta.get('git', {})
git_tag = git.get('tag', '-')

# Count completed feature sets
completed = sum(1 for fs in data.get('feature_sets', []) if fs.get('status') == 'completed')
total = len(data.get('feature_sets', []))

print(f"  Created: {created}")
print(f"  Iteration: {iteration}")
print(f"  Feature Set: {fs or '-'}")
print(f"  Progress: {completed}/{total} completed")
print(f"  Git tag: {git_tag}")
PYTHON_EOF
)
        local latest=""
        if [ $count -eq 1 ]; then
            latest=" (latest)"
        fi

        echo ""
        echo "$count. $name$latest"
        echo "$info"
    done

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "Total: $count checkpoint(s)"
}

# Show checkpoint info
show_info() {
    local checkpoint_name="$1"

    if [ -z "$checkpoint_name" ]; then
        echo "[Checkpoint] Error: Checkpoint name required"
        exit 1
    fi

    local checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}.yaml"
    if [ ! -f "$checkpoint_file" ]; then
        checkpoint_file="$CHECKPOINT_DIR/${checkpoint_name}"
    fi

    if [ ! -f "$checkpoint_file" ]; then
        echo "[Checkpoint] Error: Checkpoint not found: $checkpoint_name"
        exit 1
    fi

    echo "═══════════════════════════════════════════════════"
    echo "[FDD Checkpoint] Details: $checkpoint_name"
    echo "═══════════════════════════════════════════════════"

    python3 << PYTHON_EOF
import yaml
import json

with open('$checkpoint_file', 'r') as f:
    data = yaml.safe_load(f) or {}

meta = data.get('_checkpoint', {})
print(f"Name: {meta.get('name', 'Unknown')}")
print(f"Created: {meta.get('created_at', 'Unknown')}")
print(f"Iteration: {meta.get('iteration', '?')}")
print(f"Feature Set: {meta.get('feature_set') or '-'}")
print(f"Message: {meta.get('message', '-')}")
print()

git = meta.get('git', {})
print("Git Integration:")
print(f"  Enabled: {git.get('enabled', False)}")
print(f"  Commit: {git.get('commit', '-')}")
print(f"  Tag: {git.get('tag', '-')}")
print()

print("Feature Sets Status:")
for fs in data.get('feature_sets', []):
    status = fs.get('status', 'unknown')
    symbol = {'completed': '✓', 'in_progress': '→', 'pending': '○', 'blocked': '✗'}.get(status, '?')
    print(f"  {symbol} {fs.get('id')}: {fs.get('name')} [{status}]")
PYTHON_EOF

    echo "═══════════════════════════════════════════════════"
}

case "$ACTION" in
    create)
        create_checkpoint "$ARG1" "$ARG2" "$ARG3"
        ;;
    restore)
        restore_checkpoint "$ARG1"
        ;;
    list)
        list_checkpoints
        ;;
    info)
        show_info "$ARG1"
        ;;
    *)
        echo "FDD Git-Integrated Checkpoint System"
        echo ""
        echo "Usage:"
        echo "  checkpoint-git.sh create [iteration] [feature_set] [message]"
        echo "  checkpoint-git.sh restore <checkpoint_name|latest>"
        echo "  checkpoint-git.sh list"
        echo "  checkpoint-git.sh info <checkpoint_name>"
        exit 1
        ;;
esac
