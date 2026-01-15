#!/bin/bash
# FDD Atomic Write Utility
# Ensures safe file writes by using temp file + rename pattern
# Prevents data corruption from partial writes or crashes
#
# Usage:
#   atomic-write.sh write <file_path>       # Read from stdin, write atomically
#   atomic-write.sh copy <source> <dest>    # Atomic copy
#   atomic-write.sh update <file_path>      # Read from stdin, atomic update with backup

set -e

ACTION="$1"
FILE_PATH="$2"
SOURCE_PATH="$2"
DEST_PATH="$3"

FDD_DIR=".FDD"
BACKUP_DIR="$FDD_DIR/backups"
LOG_FILE="$FDD_DIR/logs/events.jsonl"

# Ensure directories exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$FDD_DIR/logs/x")"

# JSON-safe logging
log_event() {
    local event_type="$1"
    local file="$2"
    local message="$3"

    if [ -d "$FDD_DIR/logs" ]; then
        python3 -c "
import json
from datetime import datetime, timezone

event = {
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'event': 'atomic_write',
    'type': '''$event_type''',
    'file': '''$file''',
    'message': '''$message'''
}
print(json.dumps(event))
" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# Generate temp file path in same directory (for atomic rename)
get_temp_path() {
    local target="$1"
    local dir=$(dirname "$target")
    local base=$(basename "$target")
    local timestamp=$(date +%s%N)
    echo "${dir}/.${base}.tmp.${timestamp}"
}

# Atomic write from stdin
atomic_write() {
    local target="$1"
    local temp_path=$(get_temp_path "$target")
    local target_dir=$(dirname "$target")

    # Ensure target directory exists
    mkdir -p "$target_dir"

    # Write to temp file
    if ! cat > "$temp_path"; then
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to write temp file"
        log_event "error" "$target" "Failed to write temp file"
        exit 1
    fi

    # Validate temp file exists and has content
    if [ ! -f "$temp_path" ]; then
        echo "[AtomicWrite] Error: Temp file not created"
        log_event "error" "$target" "Temp file not created"
        exit 1
    fi

    # Atomic rename
    if mv "$temp_path" "$target"; then
        echo "[AtomicWrite] Successfully wrote: $target"
        log_event "success" "$target" "Atomic write completed"
        return 0
    else
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to rename temp file"
        log_event "error" "$target" "Failed to rename temp file"
        exit 1
    fi
}

# Atomic copy
atomic_copy() {
    local source="$1"
    local dest="$2"
    local temp_path=$(get_temp_path "$dest")
    local dest_dir=$(dirname "$dest")

    if [ ! -f "$source" ]; then
        echo "[AtomicWrite] Error: Source file not found: $source"
        exit 1
    fi

    # Ensure destination directory exists
    mkdir -p "$dest_dir"

    # Copy to temp file
    if ! cp "$source" "$temp_path"; then
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to copy to temp file"
        exit 1
    fi

    # Atomic rename
    if mv "$temp_path" "$dest"; then
        echo "[AtomicWrite] Successfully copied: $source -> $dest"
        log_event "success" "$dest" "Atomic copy from $source"
        return 0
    else
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to rename temp file"
        exit 1
    fi
}

# Atomic update with backup
atomic_update() {
    local target="$1"
    local temp_path=$(get_temp_path "$target")
    local backup_path=""

    # Create backup if file exists
    if [ -f "$target" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local base=$(basename "$target")
        backup_path="$BACKUP_DIR/${base}.${timestamp}.bak"

        if ! cp "$target" "$backup_path"; then
            echo "[AtomicWrite] Warning: Failed to create backup"
        else
            echo "[AtomicWrite] Backup created: $backup_path"
        fi
    fi

    # Ensure target directory exists
    mkdir -p "$(dirname "$target")"

    # Write to temp file
    if ! cat > "$temp_path"; then
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to write temp file"
        log_event "error" "$target" "Failed to write temp file during update"
        exit 1
    fi

    # Validate YAML/JSON if applicable
    local ext="${target##*.}"
    case "$ext" in
        yaml|yml)
            if ! python3 -c "import yaml; yaml.safe_load(open('$temp_path'))" 2>/dev/null; then
                rm -f "$temp_path"
                echo "[AtomicWrite] Error: Invalid YAML content"
                log_event "error" "$target" "Invalid YAML content"
                exit 1
            fi
            ;;
        json)
            if ! python3 -c "import json; json.load(open('$temp_path'))" 2>/dev/null; then
                rm -f "$temp_path"
                echo "[AtomicWrite] Error: Invalid JSON content"
                log_event "error" "$target" "Invalid JSON content"
                exit 1
            fi
            ;;
    esac

    # Atomic rename
    if mv "$temp_path" "$target"; then
        echo "[AtomicWrite] Successfully updated: $target"
        log_event "success" "$target" "Atomic update completed, backup: $backup_path"
        return 0
    else
        rm -f "$temp_path"
        echo "[AtomicWrite] Error: Failed to rename temp file"

        # Attempt to restore from backup
        if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
            echo "[AtomicWrite] Restoring from backup..."
            cp "$backup_path" "$target"
        fi

        log_event "error" "$target" "Failed to rename, restored from backup"
        exit 1
    fi
}

# Clean old backups (keep last 10)
clean_backups() {
    local file_pattern="$1"

    if [ -d "$BACKUP_DIR" ]; then
        # Keep only last 10 backups per file pattern
        ls -t "$BACKUP_DIR"/${file_pattern}*.bak 2>/dev/null | tail -n +11 | xargs -r rm -f
        echo "[AtomicWrite] Cleaned old backups for: $file_pattern"
    fi
}

case "$ACTION" in
    write)
        if [ -z "$FILE_PATH" ]; then
            echo "Usage: atomic-write.sh write <file_path>"
            exit 1
        fi
        atomic_write "$FILE_PATH"
        ;;
    copy)
        if [ -z "$SOURCE_PATH" ] || [ -z "$DEST_PATH" ]; then
            echo "Usage: atomic-write.sh copy <source> <dest>"
            exit 1
        fi
        atomic_copy "$SOURCE_PATH" "$DEST_PATH"
        ;;
    update)
        if [ -z "$FILE_PATH" ]; then
            echo "Usage: atomic-write.sh update <file_path>"
            exit 1
        fi
        atomic_update "$FILE_PATH"
        ;;
    clean)
        if [ -z "$FILE_PATH" ]; then
            clean_backups "*"
        else
            clean_backups "$(basename "$FILE_PATH")"
        fi
        ;;
    *)
        echo "FDD Atomic Write Utility"
        echo ""
        echo "Usage:"
        echo "  atomic-write.sh write <file_path>       # Write from stdin atomically"
        echo "  atomic-write.sh copy <source> <dest>    # Atomic copy"
        echo "  atomic-write.sh update <file_path>      # Update with backup"
        echo "  atomic-write.sh clean [file_pattern]    # Clean old backups"
        exit 1
        ;;
esac
