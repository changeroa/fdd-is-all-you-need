#!/bin/bash
# FDD State-Code Consistency Validator
# Validates that Feature Map status matches actual code implementation
#
# Features:
# - Checks if files specified in implementation_context exist
# - Validates completed features have corresponding code
# - Detects orphaned code (code without Feature Map entry)
# - Reports inconsistencies for manual review
#
# Usage:
#   validate-consistency.sh check [feature_map_path]
#   validate-consistency.sh files [feature_map_path]       # List all tracked files
#   validate-consistency.sh orphans [feature_map_path]     # Find untracked code files
#   validate-consistency.sh fix [feature_map_path]         # Auto-fix simple issues

set -e

ACTION="${1:-check}"
FEATURE_MAP="${2:-.FDD/feature_map.yaml}"

FDD_DIR=".FDD"
LOG_FILE="$FDD_DIR/logs/events.jsonl"

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
    'event': 'consistency_check',
    'type': '''$event_type''',
    'message': '''$message'''
}
print(json.dumps(event))
" >> "$LOG_FILE"
}

# Main validation logic
validate_consistency() {
    export FEATURE_MAP

    python3 << 'PYTHON_EOF'
import yaml
import os
import glob
from pathlib import Path

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

# Load feature map
try:
    with open(feature_map_path) as f:
        data = yaml.safe_load(f) or {}
except Exception as e:
    print(f"Error loading feature map: {e}")
    exit(1)

print("═══════════════════════════════════════════════════")
print("[FDD Consistency Validator] Checking state vs code")
print(f"Feature Map: {feature_map_path}")
print("═══════════════════════════════════════════════════")
print()

errors = []
warnings = []
tracked_files = set()

# Check each feature set
for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')
    fs_name = fs.get('name', 'Unknown')
    fs_status = fs.get('status', 'pending')

    for feature in fs.get('features', []):
        f_id = feature.get('id')
        f_name = feature.get('name', 'Unknown')
        f_status = feature.get('status', 'pending')
        impl_context = feature.get('implementation_context', {})
        files = impl_context.get('files', [])

        # Track all specified files
        for file_path in files:
            tracked_files.add(file_path)

        # Check completed features
        if f_status == 'completed':
            if not files:
                warnings.append(f"{f_id}: Marked completed but no files specified")
            else:
                missing = []
                for file_path in files:
                    if not os.path.exists(file_path):
                        missing.append(file_path)

                if missing:
                    errors.append({
                        'feature': f_id,
                        'name': f_name,
                        'issue': 'Missing files',
                        'files': missing
                    })

        # Check in_progress features
        elif f_status == 'in_progress':
            # Some files should exist or be in progress
            existing = [f for f in files if os.path.exists(f)]
            if files and not existing:
                warnings.append(f"{f_id}: In progress but no specified files exist yet")

        # Check pending features shouldn't have implementation
        elif f_status == 'pending':
            existing = [f for f in files if os.path.exists(f)]
            if existing:
                warnings.append(f"{f_id}: Marked pending but files already exist: {existing}")

# Report results
if errors:
    print("✗ Errors (status/code mismatch):")
    for err in errors:
        print(f"\n  {err['feature']}: {err['name']}")
        print(f"    Issue: {err['issue']}")
        for f in err.get('files', []):
            print(f"      - {f}")
    print()

if warnings:
    print("⚠ Warnings:")
    for w in warnings:
        print(f"  - {w}")
    print()

# Summary
total_features = sum(len(fs.get('features', [])) for fs in data.get('feature_sets', []))
completed = sum(1 for fs in data.get('feature_sets', [])
                for f in fs.get('features', [])
                if f.get('status') == 'completed')

print("Summary:")
print(f"  Total features: {total_features}")
print(f"  Completed: {completed}")
print(f"  Tracked files: {len(tracked_files)}")
print()

if errors:
    print("═══════════════════════════════════════════════════")
    print("VALIDATION FAILED - Fix the errors above")
    print("═══════════════════════════════════════════════════")
    exit(1)
elif warnings:
    print("═══════════════════════════════════════════════════")
    print("VALIDATION PASSED (with warnings)")
    print("═══════════════════════════════════════════════════")
else:
    print("═══════════════════════════════════════════════════")
    print("✓ VALIDATION PASSED - State and code are consistent")
    print("═══════════════════════════════════════════════════")
PYTHON_EOF
}

# List all tracked files
list_tracked_files() {
    export FEATURE_MAP

    python3 << 'PYTHON_EOF'
import yaml
import os

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

with open(feature_map_path) as f:
    data = yaml.safe_load(f) or {}

print("═══════════════════════════════════════════════════")
print("[FDD] Tracked Files")
print("═══════════════════════════════════════════════════")
print()

for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')
    fs_name = fs.get('name', 'Unknown')
    fs_status = fs.get('status', 'pending')

    fs_files = []
    for feature in fs.get('features', []):
        impl_context = feature.get('implementation_context', {})
        files = impl_context.get('files', [])
        fs_files.extend(files)

    if fs_files:
        status_symbol = {'completed': '✓', 'in_progress': '→', 'pending': '○', 'blocked': '✗'}.get(fs_status, '?')
        print(f"{status_symbol} {fs_id}: {fs_name}")
        for f in fs_files:
            exists = os.path.exists(f)
            file_status = "✓" if exists else "✗"
            print(f"  {file_status} {f}")
        print()

print("═══════════════════════════════════════════════════")
PYTHON_EOF
}

# Find orphaned code files
find_orphans() {
    export FEATURE_MAP

    python3 << 'PYTHON_EOF'
import yaml
import os
import glob
from pathlib import Path

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

with open(feature_map_path) as f:
    data = yaml.safe_load(f) or {}

# Collect all tracked files
tracked_files = set()
for fs in data.get('feature_sets', []):
    for feature in fs.get('features', []):
        impl_context = feature.get('implementation_context', {})
        files = impl_context.get('files', [])
        tracked_files.update(files)

# Find source files in common directories
source_patterns = [
    'src/**/*.ts', 'src/**/*.tsx', 'src/**/*.js', 'src/**/*.jsx',
    'src/**/*.py', 'src/**/*.go', 'src/**/*.rs',
    'lib/**/*.ts', 'lib/**/*.js', 'lib/**/*.py',
    'app/**/*.ts', 'app/**/*.tsx', 'app/**/*.js',
    'tests/**/*.ts', 'tests/**/*.py', 'test/**/*.ts', 'test/**/*.py',
    '*.ts', '*.js', '*.py'
]

all_source_files = set()
for pattern in source_patterns:
    all_source_files.update(glob.glob(pattern, recursive=True))

# Exclude common non-feature files
exclude_patterns = [
    '**/node_modules/**', '**/.git/**', '**/.FDD/**',
    '**/dist/**', '**/build/**', '**/__pycache__/**',
    '**/venv/**', '**/.venv/**',
    'package.json', 'tsconfig.json', 'setup.py', '*.config.js',
    '*.config.ts', 'jest.config.*', 'webpack.config.*'
]

def should_exclude(file_path):
    from fnmatch import fnmatch
    for pattern in exclude_patterns:
        if fnmatch(file_path, pattern):
            return True
    return False

source_files = {f for f in all_source_files if not should_exclude(f)}

# Find orphans
orphans = source_files - tracked_files

print("═══════════════════════════════════════════════════")
print("[FDD] Orphan Detection")
print("═══════════════════════════════════════════════════")
print()

if orphans:
    print("⚠ Untracked source files found:")
    for f in sorted(orphans):
        print(f"  ? {f}")
    print()
    print(f"Total: {len(orphans)} untracked file(s)")
    print()
    print("These files are not associated with any Feature.")
    print("Consider adding them to the Feature Map or removing them.")
else:
    print("✓ No orphaned files found")
    print("All source files are tracked in the Feature Map.")

print()
print("═══════════════════════════════════════════════════")
PYTHON_EOF
}

# Auto-fix simple issues
auto_fix() {
    export FEATURE_MAP

    python3 << 'PYTHON_EOF'
import yaml
import os

feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

with open(feature_map_path) as f:
    data = yaml.safe_load(f) or {}

fixes = []

for fs in data.get('feature_sets', []):
    fs_id = fs.get('id')

    for feature in fs.get('features', []):
        f_id = feature.get('id')
        f_status = feature.get('status', 'pending')
        impl_context = feature.get('implementation_context', {})
        files = impl_context.get('files', [])

        # Fix: pending with existing files -> mark as completed if all exist
        if f_status == 'pending' and files:
            all_exist = all(os.path.exists(f) for f in files)
            if all_exist and len(files) > 0:
                feature['status'] = 'completed'
                fixes.append(f"{f_id}: pending → completed (all files exist)")

        # Fix: completed with no files -> keep completed but warn
        # (We don't auto-change this, just report)

print("═══════════════════════════════════════════════════")
print("[FDD] Auto-Fix Results")
print("═══════════════════════════════════════════════════")
print()

if fixes:
    with open(feature_map_path, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print("Applied fixes:")
    for fix in fixes:
        print(f"  ✓ {fix}")
    print()
    print(f"Total: {len(fixes)} fix(es) applied")
else:
    print("No automatic fixes needed.")

print()
print("═══════════════════════════════════════════════════")
PYTHON_EOF

    log_event "auto_fix" "Applied automatic consistency fixes"
}

case "$ACTION" in
    check)
        validate_consistency
        ;;
    files)
        list_tracked_files
        ;;
    orphans)
        find_orphans
        ;;
    fix)
        auto_fix
        ;;
    *)
        echo "FDD State-Code Consistency Validator"
        echo ""
        echo "Usage:"
        echo "  validate-consistency.sh check [feature_map_path]"
        echo "  validate-consistency.sh files [feature_map_path]"
        echo "  validate-consistency.sh orphans [feature_map_path]"
        echo "  validate-consistency.sh fix [feature_map_path]"
        exit 1
        ;;
esac
