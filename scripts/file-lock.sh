#!/bin/bash
# FDD File Lock Utility v2.0
# Agent ID based + TTL mechanism for multi-agent environment
#
# Key improvements over v1:
# - Agent ID based locking (not PID based)
# - TTL (Time To Live) for automatic stale lock cleanup
# - Force release capability for admin recovery
# - Lock status includes age information
#
# Usage:
#   file-lock.sh acquire <file_path> <agent_id> [timeout_seconds] [ttl_seconds]
#   file-lock.sh release <file_path> <agent_id>
#   file-lock.sh status <file_path>
#   file-lock.sh force-release <file_path>
#   file-lock.sh cleanup [directory]  # Clean all stale locks

set -e

ACTION="$1"
FILE_PATH="$2"
AGENT_ID="$3"
TIMEOUT="${4:-30}"
TTL="${5:-300}"  # Default 5 minutes TTL

if [ -z "$FILE_PATH" ] && [ "$ACTION" != "cleanup" ]; then
    echo "Usage: file-lock.sh <acquire|release|status|force-release|cleanup> <file_path> [agent_id] [timeout] [ttl]"
    exit 1
fi

LOCK_DIR="${FILE_PATH}.lockdir"
LOCK_INFO="${LOCK_DIR}/info.json"

# JSON-safe string escaping
json_escape() {
    local str="$1"
    printf '%s' "$str" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}

# Get current timestamp in seconds since epoch
get_timestamp() {
    date +%s
}

# Get ISO timestamp
get_iso_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Create lock info JSON safely
create_lock_info() {
    local agent_id="$1"
    local ttl="$2"
    local timestamp=$(get_timestamp)
    local iso_time=$(get_iso_timestamp)
    local expires_at=$((timestamp + ttl))

    python3 -c "
import json
info = {
    'agent_id': '''$agent_id''',
    'created_at': '''$iso_time''',
    'timestamp': $timestamp,
    'ttl': $ttl,
    'expires_at': $expires_at
}
print(json.dumps(info, indent=2))
"
}

# Read lock info
read_lock_info() {
    if [ -f "$LOCK_INFO" ]; then
        cat "$LOCK_INFO"
    else
        echo "{}"
    fi
}

# Check if lock is expired based on TTL
is_lock_expired() {
    if [ ! -f "$LOCK_INFO" ]; then
        return 0  # No info file = expired/invalid
    fi

    local expires_at=$(python3 -c "
import json
try:
    with open('$LOCK_INFO') as f:
        info = json.load(f)
    print(info.get('expires_at', 0))
except:
    print(0)
")
    local current=$(get_timestamp)

    if [ "$current" -ge "$expires_at" ]; then
        return 0  # Expired
    else
        return 1  # Not expired
    fi
}

# Get lock holder agent ID
get_lock_holder() {
    if [ -f "$LOCK_INFO" ]; then
        python3 -c "
import json
try:
    with open('$LOCK_INFO') as f:
        info = json.load(f)
    print(info.get('agent_id', 'unknown'))
except:
    print('unknown')
"
    else
        echo "unknown"
    fi
}

# Get lock age in seconds
get_lock_age() {
    if [ -f "$LOCK_INFO" ]; then
        python3 -c "
import json
import time
try:
    with open('$LOCK_INFO') as f:
        info = json.load(f)
    created = info.get('timestamp', 0)
    age = int(time.time()) - created
    print(age)
except:
    print(-1)
"
    else
        echo "-1"
    fi
}

acquire_lock() {
    local agent_id="$1"
    local timeout="$2"
    local ttl="$3"
    local start_time=$(get_timestamp)

    if [ -z "$agent_id" ]; then
        echo "[Lock] Error: agent_id is required for acquire"
        exit 1
    fi

    while true; do
        # Try to create lock directory atomically
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            # Successfully created lock directory
            create_lock_info "$agent_id" "$ttl" > "$LOCK_INFO"
            echo "[Lock] Acquired lock on $FILE_PATH (Agent: $agent_id, TTL: ${ttl}s)"
            return 0
        fi

        # Lock exists - check if expired
        if is_lock_expired; then
            local old_holder=$(get_lock_holder)
            local age=$(get_lock_age)
            echo "[Lock] Removing expired lock (Agent: $old_holder, Age: ${age}s)"
            rm -rf "$LOCK_DIR"
            continue
        fi

        # Check if we already own the lock (re-entrant)
        local holder=$(get_lock_holder)
        if [ "$holder" = "$agent_id" ]; then
            # Refresh TTL
            create_lock_info "$agent_id" "$ttl" > "$LOCK_INFO"
            echo "[Lock] Refreshed existing lock on $FILE_PATH (Agent: $agent_id)"
            return 0
        fi

        # Check timeout
        local current_time=$(get_timestamp)
        local elapsed=$((current_time - start_time))

        if [ "$elapsed" -ge "$timeout" ]; then
            local age=$(get_lock_age)
            echo "[Lock] Timeout waiting for lock on $FILE_PATH"
            echo "[Lock] Current holder: $holder (Age: ${age}s)"
            return 1
        fi

        # Wait and retry
        sleep 0.5
    done
}

release_lock() {
    local agent_id="$1"

    if [ ! -d "$LOCK_DIR" ]; then
        echo "[Lock] No lock to release on $FILE_PATH"
        return 0
    fi

    local holder=$(get_lock_holder)

    # Check ownership
    if [ -n "$agent_id" ] && [ "$holder" != "$agent_id" ] && [ "$holder" != "unknown" ]; then
        echo "[Lock] Warning: Lock owned by '$holder', not '$agent_id'"
        echo "[Lock] Use 'force-release' if you need to override"
        return 1
    fi

    rm -rf "$LOCK_DIR"
    echo "[Lock] Released lock on $FILE_PATH"
    return 0
}

force_release_lock() {
    if [ -d "$LOCK_DIR" ]; then
        local holder=$(get_lock_holder)
        local age=$(get_lock_age)
        rm -rf "$LOCK_DIR"
        echo "[Lock] Force released lock on $FILE_PATH (was held by: $holder, age: ${age}s)"
    else
        echo "[Lock] No lock exists on $FILE_PATH"
    fi
    return 0
}

check_status() {
    if [ -d "$LOCK_DIR" ]; then
        if is_lock_expired; then
            local holder=$(get_lock_holder)
            local age=$(get_lock_age)
            echo "[Lock] EXPIRED (Agent: $holder, Age: ${age}s)"
            return 2
        else
            local holder=$(get_lock_holder)
            local age=$(get_lock_age)
            local info=$(read_lock_info)
            local ttl=$(echo "$info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('ttl', 0))")
            local remaining=$((ttl - age))
            echo "[Lock] LOCKED"
            echo "  Agent: $holder"
            echo "  Age: ${age}s"
            echo "  TTL remaining: ${remaining}s"
            return 1
        fi
    else
        echo "[Lock] UNLOCKED"
        return 0
    fi
}

cleanup_stale_locks() {
    local dir="${1:-.}"
    local count=0

    echo "[Lock] Scanning for stale locks in: $dir"

    # Find all .lockdir directories
    while IFS= read -r -d '' lockdir; do
        local info_file="$lockdir/info.json"
        if [ -f "$info_file" ]; then
            # Check if expired
            local expires_at=$(python3 -c "
import json
try:
    with open('$info_file') as f:
        info = json.load(f)
    print(info.get('expires_at', 0))
except:
    print(0)
")
            local current=$(get_timestamp)

            if [ "$current" -ge "$expires_at" ]; then
                local holder=$(python3 -c "
import json
try:
    with open('$info_file') as f:
        print(json.load(f).get('agent_id', 'unknown'))
except:
    print('unknown')
")
                echo "[Lock] Removing stale lock: $lockdir (Agent: $holder)"
                rm -rf "$lockdir"
                ((count++)) || true
            fi
        else
            # No info file - remove orphaned lock
            echo "[Lock] Removing orphaned lock: $lockdir"
            rm -rf "$lockdir"
            ((count++)) || true
        fi
    done < <(find "$dir" -name "*.lockdir" -type d -print0 2>/dev/null)

    echo "[Lock] Cleanup complete. Removed $count stale lock(s)"
}

case "$ACTION" in
    acquire)
        acquire_lock "$AGENT_ID" "$TIMEOUT" "$TTL"
        ;;
    release)
        release_lock "$AGENT_ID"
        ;;
    force-release)
        force_release_lock
        ;;
    status)
        check_status
        ;;
    cleanup)
        cleanup_stale_locks "$FILE_PATH"
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Usage: file-lock.sh <acquire|release|status|force-release|cleanup> <file_path> [agent_id] [timeout] [ttl]"
        exit 1
        ;;
esac
