#!/bin/bash
# FDD Quality Check Hook
# Called by PostToolUse hook after Write/Edit operations
# Usage: bash quality-check.sh <file_path>
#
# NOTE: This script MUST remain as bash because PostToolUse hooks
# only support shell command execution, not skill invocation.

set -e

FILE_PATH="$1"
FDD_DIR=".FDD"
LOG_FILE="$FDD_DIR/logs/events.jsonl"

# Ensure log directory exists
mkdir -p "$FDD_DIR/logs"

log_event() {
    local event_type="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"event\":\"$event_type\",\"file\":\"$FILE_PATH\",\"message\":\"$message\"}" >> "$LOG_FILE"
}

# Skip if file doesn't exist or is in .FDD directory
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

if [[ "$FILE_PATH" == *".FDD"* ]]; then
    exit 0
fi

# Determine file type and run appropriate checks
EXTENSION="${FILE_PATH##*.}"
ERRORS=()

log_event "quality_check_start" "Starting quality check"

case "$EXTENSION" in
    ts|tsx)
        # TypeScript checks
        if command -v npx &> /dev/null; then
            if [ -f "tsconfig.json" ]; then
                if ! npx tsc --noEmit "$FILE_PATH" 2>/dev/null; then
                    ERRORS+=("TypeScript type check failed")
                fi
            fi
        fi
        ;;
    js|jsx)
        # JavaScript checks
        if command -v npx &> /dev/null && [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ]; then
            if ! npx eslint "$FILE_PATH" --quiet 2>/dev/null; then
                ERRORS+=("ESLint check failed")
            fi
        fi
        ;;
    py)
        # Python checks
        if command -v python3 &> /dev/null; then
            if ! python3 -m py_compile "$FILE_PATH" 2>/dev/null; then
                ERRORS+=("Python syntax check failed")
            fi
        fi
        if command -v ruff &> /dev/null; then
            if ! ruff check "$FILE_PATH" --quiet 2>/dev/null; then
                ERRORS+=("Ruff lint check failed")
            fi
        fi
        ;;
    go)
        # Go checks
        if command -v go &> /dev/null; then
            DIR=$(dirname "$FILE_PATH")
            if ! go vet "$DIR" 2>/dev/null; then
                ERRORS+=("Go vet check failed")
            fi
        fi
        ;;
    rs)
        # Rust checks
        if command -v cargo &> /dev/null && [ -f "Cargo.toml" ]; then
            if ! cargo check --quiet 2>/dev/null; then
                ERRORS+=("Cargo check failed")
            fi
        fi
        ;;
    yaml|yml)
        # YAML syntax check
        if command -v python3 &> /dev/null; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$FILE_PATH'))" 2>/dev/null; then
                ERRORS+=("YAML syntax check failed")
            fi
        fi
        ;;
    json)
        # JSON syntax check
        if command -v python3 &> /dev/null; then
            if ! python3 -c "import json; json.load(open('$FILE_PATH'))" 2>/dev/null; then
                ERRORS+=("JSON syntax check failed")
            fi
        fi
        ;;
esac

# Report results
if [ ${#ERRORS[@]} -eq 0 ]; then
    log_event "quality_check_pass" "All checks passed"
    echo "[FDD] Quality check passed: $FILE_PATH"
    exit 0
else
    log_event "quality_check_fail" "Checks failed: ${ERRORS[*]}"
    echo "[FDD] Quality check failed for $FILE_PATH:"
    for error in "${ERRORS[@]}"; do
        echo "  - $error"
    done
    exit 1
fi
