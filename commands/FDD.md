# FDD - Feature-Driven Development Workflow

You are an AI assistant using the FDD (Feature-Driven Development) workflow. This is the main help command.

## Available Commands

### Workflow Commands
| Command | Description |
|---------|-------------|
| `/FDD init` | Initialize FDD in the current project |
| `/FDD analyze` | Analyze requirements and create design document |
| `/FDD plan` | Generate Feature Map from design document |
| `/FDD design` | Create detailed designs for Feature Sets |
| `/FDD develop` | Execute parallel feature development |
| `/FDD status` | Show current progress and state |
| `/FDD resume` | Resume from last checkpoint |

### Validation Skills
| Command | Description |
|---------|-------------|
| `/FDD-validate-map` | Validate Feature Map structure and dependencies |
| `/FDD-validate-design` | Validate design document completeness |
| `/FDD-validate-detail` | Validate detailed design technical accuracy |
| `/FDD-improve` | Run Validator/Improver quality loop |

### State Management Skills
| Command | Description |
|---------|-------------|
| `/FDD-update-status` | Update feature or feature set status |
| `/FDD-get-executable` | Find executable feature sets (dependencies satisfied) |
| `/FDD-checkpoint` | Save current state as checkpoint |
| `/FDD-rollback` | Rollback Feature Sets or restore from checkpoints |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `fdd-orchestrator` | Opus | Central coordinator - manages parallel execution, dependencies, checkpoints |
| `fdd-designer` | Sonnet | Creates detailed designs for Feature Sets |
| `fdd-developer` | Sonnet | Implements features according to designs |
| `fdd-improver` | Sonnet | Improves artifacts that fail validation |

### Agent Invocation
```
Task(
  subagent_type: "fdd-is-all-you-need:fdd-orchestrator",
  prompt: "Execute FDD development workflow..."
)
```

## Workflow Overview

1. **Initialize** → `/FDD init`
2. **Analyze** → `/FDD analyze` (creates design document)
3. **Plan** → `/FDD plan` (creates Feature Map)
4. **Design** → `/FDD design` (creates detailed designs)
5. **Develop** → `/FDD develop` (implements features)

## Core Principles

- **Repeatable Precision**: Quality comes from process, not one-shots
- **3-Layer Context**: Business → Design → Implementation
- **Parallel Execution**: Independent features developed simultaneously
- **Quality Gates**: Validator/Improver loops for all artifacts
- **Checkpointing**: Resume capability at any point

## State Files

- `.FDD/config.yaml` - Project configuration
- `.FDD/feature_map.yaml` - Feature Map (source of truth)
- `.FDD/iterations/` - Iteration artifacts
- `.FDD/checkpoints/` - Resume points
- `.FDD/logs/` - Event logs
- `.FDD/scripts/` - Utility scripts (locking, quality checks)

## ID Format Conventions

| Type | Format | Example |
|------|--------|---------|
| Feature Set | `FS-XXX` | FS-001, FS-002 |
| Feature | `F-XXX-YYY` | F-001-001, F-001-002 |

See `docs/ID_CONVENTIONS.md` for detailed documentation.

Display this help message to the user.
