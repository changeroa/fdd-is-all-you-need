# FDD Initialize

Initialize the FDD workflow in the current project.

## Instructions

### 1. Check if Already Initialized
- Look for `.FDD/config.yaml`
- If exists, inform user and ask if they want to reinitialize

### 2. Create Directory Structure

Create the following directories:
```bash
mkdir -p .FDD/scripts .FDD/iterations .FDD/checkpoints .FDD/logs .FDD/backups
```

Result:
```
.FDD/
├── scripts/           # Utility scripts
├── iterations/        # Design documents
├── checkpoints/       # State snapshots
├── logs/              # Event logs
└── backups/           # Automatic backups
```

### 3. Copy Scripts from Plugin

Copy ALL utility scripts from the plugin to `.FDD/scripts/`:

```bash
# Copy from plugin directory
cp /path/to/fdd-is-all-you-need/scripts/*.sh .FDD/scripts/
```

Scripts included:
| Script | Purpose |
|--------|---------|
| `quality-check.sh` | Project-wide quality checks (TypeScript, Python, Go, etc.) |
| `file-lock.sh` | Agent ID + TTL based locking mechanism |
| `atomic-write.sh` | Safe file writes with backup |
| `validate-deps.sh` | Dependency validation & circular detection |
| `checkpoint-git.sh` | Git-integrated checkpoints |
| `timeout-monitor.sh` | Stale progress detection |
| `validate-consistency.sh` | State-code consistency validation |

Make scripts executable:
```bash
chmod +x .FDD/scripts/*.sh
```

### 4. Initialize config.yaml

Create `.FDD/config.yaml`:
```yaml
project:
  name: "{PROJECT_NAME}"
  description: ""
  created_at: "{TIMESTAMP}"

feature_development:
  max_parallel_features: 3
  default_timeout: 1800000  # 30 minutes

quality_check:
  enabled: true
  checks:
    - linting
    - type_check
  max_retries: 3
  project_wide: true

artifact_quality:
  enabled: true
  max_iterations: 3
  validators:
    - design_document
    - feature_map
    - detailed_design

approval_gates:
  design_document: true
  feature_map: true
  detailed_design: true
  feature_completion: false

agents:
  orchestrator:
    model: opus
  designer:
    model: sonnet
  developer:
    model: sonnet
  improver:
    model: sonnet

locking:
  acquire_timeout: 30
  ttl: 300

git:
  enabled: true
  auto_commit: true
  create_tags: true
  commit_prefix: "[FDD]"

logging:
  events_file: ".FDD/logs/events.jsonl"
  audit_enabled: true
  level: info
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
# Example structure:
# - id: FS-001
#   name: "User Authentication"
#   status: pending
#   priority: high  # critical, high, medium, low
#   dependencies: []
#   features:
#     - id: F-001-001
#       name: "Login Form"
#       status: pending
#       implementation_context:
#         files: []
#         interfaces: []

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
  },
  "permissions": {
    "allow": [
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(bash .FDD/scripts/*)",
      "Bash(python3 *)",
      "Bash(go *)",
      "Bash(cargo *)",
      "Bash(git *)",
      "Read(.FDD/**)",
      "Write(.FDD/**)",
      "Edit(.FDD/**)"
    ]
  }
}
```

### 7. Initialize Log Files

Create empty log files:
```bash
touch .FDD/logs/events.jsonl
```

### 8. Verify Git Repository

Check if in a Git repository:
```bash
git rev-parse --git-dir > /dev/null 2>&1
```

If yes, add `.FDD/` patterns to `.gitignore` (optional):
```
# FDD temporary files (checkpoints and logs are tracked)
.FDD/.project-type-cache
.FDD/.progress-state.json
.FDD/backups/
*.lockdir/
```

### 9. Output Summary

```
═══════════════════════════════════════════════════
[FDD] Project Initialized
═══════════════════════════════════════════════════

Project: {PROJECT_NAME}
Created: {TIMESTAMP}

Directory structure:
  .FDD/
  ├── config.yaml              ✓
  ├── feature_map.yaml         ✓
  ├── scripts/
  │   ├── quality-check.sh     ✓ (project-wide checks)
  │   ├── file-lock.sh         ✓ (agent ID + TTL locking)
  │   ├── atomic-write.sh      ✓ (safe file writes)
  │   ├── validate-deps.sh     ✓ (dependency validation)
  │   ├── checkpoint-git.sh    ✓ (Git integration)
  │   ├── timeout-monitor.sh   ✓ (stale detection)
  │   └── validate-consistency.sh ✓ (state-code sync)
  ├── iterations/              ✓
  ├── checkpoints/             ✓
  ├── logs/                    ✓
  └── backups/                 ✓

Hook configuration:
  .claude/settings.json        ✓

Git integration:
  Repository detected          {YES/NO}
  Auto-commit enabled          {YES/NO}

═══════════════════════════════════════════════════
Next step: /FDD analyze
═══════════════════════════════════════════════════
```

## Notes

- Ask user for project name if not obvious from context
- Use current directory name as default project name
- Timestamp format: ISO 8601 (e.g., 2024-01-14T12:00:00Z)
- Scripts are copied from plugin, not symlinked, for portability
