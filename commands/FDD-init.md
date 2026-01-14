# FDD Initialize

Initialize the FDD workflow in the current project.

## Instructions

### 1. Check if Already Initialized
- Look for `.FDD/config.yaml`
- If exists, inform user and ask if they want to reinitialize

### 2. Create Directory Structure

Create the following directories:
```bash
mkdir -p .FDD/scripts .FDD/iterations .FDD/checkpoints .FDD/logs
```

Result:
```
.FDD/
├── scripts/           # Utility scripts
├── iterations/        # Design documents
├── checkpoints/       # State snapshots
└── logs/              # Event logs
```

### 3. Copy Scripts

Copy utility scripts from the plugin to `.FDD/scripts/`:

**quality-check.sh** - Runs after Write/Edit operations:
```bash
# Copy from plugin templates or create with this content:
# - TypeScript: npx tsc --noEmit
# - Python: python3 -m py_compile + ruff
# - Go: go vet
# - YAML/JSON: syntax validation
```

**file-lock.sh** - Concurrent access protection:
```bash
# Provides acquire/release/status commands for file locking
```

Make scripts executable:
```bash
chmod +x .FDD/scripts/*.sh
```

### 4. Initialize config.yaml

Create `.FDD/config.yaml`:
```yaml
project:
  name: "{PROJECT_NAME}"
  created_at: "{TIMESTAMP}"

settings:
  max_parallel_features: 3
  approval_gates:
    design_document: true
    feature_map: true
    detailed_design: false
  quality_checks:
    enabled: true
    on_write: true
    on_edit: true
```

### 5. Initialize feature_map.yaml

Create `.FDD/feature_map.yaml`:
```yaml
metadata:
  project_name: "{PROJECT_NAME}"
  version: "1.0.0"
  created_at: "{TIMESTAMP}"
  updated_at: "{TIMESTAMP}"
  total_features: 0
  completed_features: 0

business_context:
  objectives: []
  constraints: []
  success_criteria: []

design_context:
  architecture: ""
  patterns: []
  technologies: []

feature_sets: []

execution:
  current_iteration: 0
  last_checkpoint: ""
  blocked_features: []
```

### 6. Setup Hook Configuration

Create or update `.claude/settings.json`:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .FDD/scripts/quality-check.sh \"$CLAUDE_TOOL_USE_FILE_PATH\"",
            "timeout": 120000
          }
        ]
      }
    ]
  }
}
```

### 7. Initialize Log Files

Create empty log files:
```bash
touch .FDD/logs/events.jsonl
touch .FDD/logs/audit.jsonl
```

### 8. Output Summary

```
=== FDD Initialized ===

Project: {PROJECT_NAME}
Created: {TIMESTAMP}

Directory structure:
  .FDD/
  ├── config.yaml         ✓
  ├── feature_map.yaml    ✓
  ├── scripts/            ✓
  ├── iterations/         ✓
  ├── checkpoints/        ✓
  └── logs/               ✓

Hook configuration:
  .claude/settings.json   ✓

Next step: /FDD analyze
```

## Notes

- Ask user for project name if not obvious from context
- Use current directory name as default project name
- Timestamp format: ISO 8601 (e.g., 2024-01-14T12:00:00Z)
