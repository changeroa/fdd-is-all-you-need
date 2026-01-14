#!/bin/bash
# FDD File Lock Utility
# Provides atomic file locking for concurrent access to shared files
# Usage:
#   file-lock.sh acquire <file_path> [timeout_seconds]
#   file-lock.sh release <file_path>
#   file-lock.sh status <file_path>

set -e

ACTION="$1"
FILE_PATH="$2"
TIMEOUT="${3:-30}"

if [ -z "$FILE_PATH" ]; then
    echo "Usage: file-lock.sh <acquire|release|status> <file_path> [timeout]"
    exit 1
fi

LOCK_FILE="${FILE_PATH}.lock"
PID_FILE="${FILE_PATH}.lock.pid"

acquire_lock() {
    local start_time=$(date +%s)
    local my_pid=$$

    while true; do
        # Try to create lock file atomically
        if (set -o noclobber; echo "$my_pid" > "$LOCK_FILE") 2>/dev/null; then
            echo "$my_pid" > "$PID_FILE"
            echo "[Lock] Acquired lock on $FILE_PATH (PID: $my_pid)"
            return 0
        fi

        # Check if lock holder is still alive
        if [ -f "$PID_FILE" ]; then
            local holder_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
            if [ -n "$holder_pid" ] && ! kill -0 "$holder_pid" 2>/dev/null; then
                # Lock holder is dead, remove stale lock
                echo "[Lock] Removing stale lock (dead PID: $holder_pid)"
                rm -f "$LOCK_FILE" "$PID_FILE"
                continue
            fi
        fi

        # Check timeout
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [ "$elapsed" -ge "$TIMEOUT" ]; then
            echo "[Lock] Timeout waiting for lock on $FILE_PATH"
            return 1
        fi

        # Wait and retry
        sleep 0.5
    done
}

release_lock() {
    local my_pid=$$

    if [ -f "$PID_FILE" ]; then
        local holder_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")

        # Only release if we own the lock
        if [ "$holder_pid" = "$my_pid" ] || [ -z "$holder_pid" ]; then
            rm -f "$LOCK_FILE" "$PID_FILE"
            echo "[Lock] Released lock on $FILE_PATH"
            return 0
        else
            echo "[Lock] Cannot release lock owned by PID $holder_pid"
            return 1
        fi
    else
        # No lock exists, remove any stale files
        rm -f "$LOCK_FILE"
        echo "[Lock] No lock to release"
        return 0
    fi
}

check_status() {
    if [ -f "$LOCK_FILE" ]; then
        if [ -f "$PID_FILE" ]; then
            local holder_pid=$(cat "$PID_FILE" 2>/dev/null || echo "unknown")
            if kill -0 "$holder_pid" 2>/dev/null; then
                echo "[Lock] LOCKED by PID $holder_pid"
                return 1
            else
                echo "[Lock] STALE (dead PID: $holder_pid)"
                return 2
            fi
        else
            echo "[Lock] LOCKED (unknown holder)"
            return 1
        fi
    else
        echo "[Lock] UNLOCKED"
        return 0
    fi
}

case "$ACTION" in
    acquire)
        acquire_lock
        ;;
    release)
        release_lock
        ;;
    status)
        check_status
        ;;
    *)
        echo "Unknown action: $ACTION"
        echo "Usage: file-lock.sh <acquire|release|status> <file_path> [timeout]"
        exit 1
        ;;
esac
