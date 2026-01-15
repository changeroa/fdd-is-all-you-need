#!/bin/bash
# FDD Quality Check Hook v2.0
# Called by PostToolUse hook after Write/Edit operations
#
# Key improvements over v1:
# - Project-wide type checking (not single file)
# - JSON-safe logging
# - Cached project type detection
# - Better error messages
#
# Usage: bash quality-check.sh <file_path>

set -e

FILE_PATH="$1"
FDD_DIR=".FDD"
LOG_FILE="$FDD_DIR/logs/events.jsonl"
CACHE_FILE="$FDD_DIR/.project-type-cache"

# Ensure log directory exists
mkdir -p "$FDD_DIR/logs"

# JSON-safe logging function
log_event() {
    local event_type="$1"
    local message="$2"
    local status="${3:-info}"

    python3 -c "
import json
import sys
from datetime import datetime, timezone

event = {
    'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'event': 'quality_check',
    'type': '''$event_type''',
    'file': '''$FILE_PATH''',
    'message': '''$message''',
    'status': '''$status'''
}
print(json.dumps(event))
" >> "$LOG_FILE"
}

# Skip conditions
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

if [[ "$FILE_PATH" == *".FDD"* ]] || [[ "$FILE_PATH" == *".git"* ]]; then
    exit 0
fi

# Determine file type
EXTENSION="${FILE_PATH##*.}"
ERRORS=()
WARNINGS=()

# Detect project type (cached for performance)
get_project_type() {
    if [ -f "$CACHE_FILE" ]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
        if [ "$cache_age" -lt 300 ]; then  # Cache valid for 5 minutes
            cat "$CACHE_FILE"
            return
        fi
    fi

    local project_type="unknown"

    if [ -f "package.json" ]; then
        if [ -f "tsconfig.json" ]; then
            project_type="typescript"
        else
            project_type="javascript"
        fi
    elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        project_type="python"
    elif [ -f "go.mod" ]; then
        project_type="go"
    elif [ -f "Cargo.toml" ]; then
        project_type="rust"
    fi

    echo "$project_type" > "$CACHE_FILE"
    echo "$project_type"
}

PROJECT_TYPE=$(get_project_type)

log_event "start" "Starting quality check for $EXTENSION file" "info"

# TypeScript/JavaScript - Project-wide check
check_typescript() {
    if [ ! -f "tsconfig.json" ]; then
        WARNINGS+=("No tsconfig.json found, skipping TypeScript check")
        return
    fi

    # Run project-wide type check (not single file)
    local output
    if ! output=$(npx tsc --noEmit 2>&1); then
        # Filter errors related to the current file for better UX
        local file_errors=$(echo "$output" | grep -E "^${FILE_PATH}|error TS" | head -20)
        if [ -n "$file_errors" ]; then
            ERRORS+=("TypeScript errors found:")
            ERRORS+=("$file_errors")
        else
            # Show general errors
            ERRORS+=("TypeScript project has errors:")
            ERRORS+=("$(echo "$output" | head -10)")
        fi
    fi
}

check_javascript() {
    # Check for ESLint config
    local eslint_config=""
    for config in .eslintrc.js .eslintrc.json .eslintrc.yaml .eslintrc.yml eslint.config.js eslint.config.mjs; do
        if [ -f "$config" ]; then
            eslint_config="$config"
            break
        fi
    done

    if [ -z "$eslint_config" ]; then
        WARNINGS+=("No ESLint config found, skipping lint check")
        return
    fi

    local output
    if ! output=$(npx eslint "$FILE_PATH" --format compact 2>&1); then
        ERRORS+=("ESLint errors:")
        ERRORS+=("$(echo "$output" | head -20)")
    fi
}

# Python checks
check_python() {
    # Syntax check
    local output
    if ! output=$(python3 -m py_compile "$FILE_PATH" 2>&1); then
        ERRORS+=("Python syntax error:")
        ERRORS+=("$output")
        return  # Stop if syntax error
    fi

    # Ruff lint (if available)
    if command -v ruff &> /dev/null; then
        if ! output=$(ruff check "$FILE_PATH" 2>&1); then
            # Ruff errors are warnings by default
            WARNINGS+=("Ruff lint warnings:")
            WARNINGS+=("$(echo "$output" | head -10)")
        fi
    fi

    # Type check with mypy (if configured)
    if [ -f "mypy.ini" ] || [ -f "pyproject.toml" ]; then
        if command -v mypy &> /dev/null; then
            if ! output=$(mypy "$FILE_PATH" --ignore-missing-imports 2>&1); then
                WARNINGS+=("MyPy type warnings:")
                WARNINGS+=("$(echo "$output" | head -10)")
            fi
        fi
    fi
}

# Go checks
check_go() {
    local dir=$(dirname "$FILE_PATH")
    local output

    # Go vet for the package
    if ! output=$(go vet "$dir/..." 2>&1); then
        ERRORS+=("Go vet errors:")
        ERRORS+=("$output")
    fi

    # Go build check
    if ! output=$(go build -o /dev/null "$dir/..." 2>&1); then
        ERRORS+=("Go build errors:")
        ERRORS+=("$(echo "$output" | head -10)")
    fi
}

# Rust checks
check_rust() {
    if [ ! -f "Cargo.toml" ]; then
        WARNINGS+=("No Cargo.toml found, skipping Rust check")
        return
    fi

    local output
    if ! output=$(cargo check --message-format short 2>&1); then
        ERRORS+=("Cargo check errors:")
        ERRORS+=("$(echo "$output" | grep -E "^error" | head -10)")
    fi
}

# YAML syntax check
check_yaml() {
    local output
    if ! output=$(python3 -c "
import yaml
import sys
try:
    with open('$FILE_PATH', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except yaml.YAMLError as e:
    print(f'YAML syntax error: {e}')
    sys.exit(1)
" 2>&1); then
        ERRORS+=("$output")
    fi
}

# JSON syntax check
check_json() {
    local output
    if ! output=$(python3 -c "
import json
import sys
try:
    with open('$FILE_PATH', 'r') as f:
        json.load(f)
    sys.exit(0)
except json.JSONDecodeError as e:
    print(f'JSON syntax error at line {e.lineno}: {e.msg}')
    sys.exit(1)
" 2>&1); then
        ERRORS+=("$output")
    fi
}

# Run appropriate checks based on file extension
case "$EXTENSION" in
    ts|tsx)
        if command -v npx &> /dev/null; then
            check_typescript
        fi
        ;;
    js|jsx|mjs)
        if command -v npx &> /dev/null; then
            check_javascript
        fi
        ;;
    py)
        check_python
        ;;
    go)
        if command -v go &> /dev/null; then
            check_go
        fi
        ;;
    rs)
        if command -v cargo &> /dev/null; then
            check_rust
        fi
        ;;
    yaml|yml)
        check_yaml
        ;;
    json)
        check_json
        ;;
esac

# Report results
echo ""
echo "═══════════════════════════════════════════════════"
echo "[FDD Quality Check] $FILE_PATH"
echo "═══════════════════════════════════════════════════"

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo ""
    echo "⚠ Warnings:"
    for warning in "${WARNINGS[@]}"; do
        echo "  $warning"
    done
    log_event "warning" "$(IFS='; '; echo "${WARNINGS[*]}")" "warning"
fi

if [ ${#ERRORS[@]} -eq 0 ]; then
    echo ""
    echo "✓ All checks passed"
    echo ""
    log_event "pass" "All checks passed" "success"
    exit 0
else
    echo ""
    echo "✗ Errors found:"
    for error in "${ERRORS[@]}"; do
        echo "  $error"
    done
    echo ""
    echo "Please fix these errors before proceeding."
    echo "═══════════════════════════════════════════════════"
    log_event "fail" "$(IFS='; '; echo "${ERRORS[*]}")" "error"
    exit 1
fi
