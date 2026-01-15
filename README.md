# FDD is All You Need

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/changeroa/fdd-is-all-you-need/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-purple.svg)](https://github.com/anthropics/claude-code)

A systematic multi-agent development workflow based on Feature-Driven Development (FDD) principles, designed as a Claude Code plugin.

## Philosophy: Repeatable Precision

Quality comes from **process and accumulated context**, not genius one-shots. FDD provides structured workflows, quality gates, and iterative improvement loops to achieve consistent, high-quality results.

## Installation

### Via Plugin Marketplace

```bash
# Add marketplace
/plugin marketplace add changeroa/fdd-is-all-you-need

# Install plugin
/plugin install fdd-is-all-you-need
```

### Manual Installation

```bash
git clone https://github.com/changeroa/fdd-is-all-you-need.git
# Then add to your Claude Code plugins directory
```

## Quick Start

After installation, use the slash commands in Claude Code:

```
/FDD init          # Initialize project
/FDD analyze       # Create design document from requirements
/FDD plan          # Generate Feature Map
/FDD design        # Create detailed designs
/FDD develop       # Execute feature development
/FDD status        # Check current progress
/FDD resume        # Resume from checkpoint
```

## Features

- **Feature-Driven Development**: Systematic decomposition of requirements into Feature Sets
- **3-Layer Context**: Business → Design → Implementation context propagation
- **Parallel Execution**: Independent features developed simultaneously
- **Quality Gates**: Automatic code quality checks via PostToolUse hooks
- **Validator/Improver Loops**: Iterative artifact improvement (max 3 iterations)
- **Checkpointing**: Automatic state saving with resume capability
- **Human-in-the-Loop**: Approval gates at major milestones

## Workflow Phases

### 1. Initialization (`/FDD init`)
- Creates `.FDD/` directory structure
- Initializes configuration and Feature Map templates

### 2. Analysis (`/FDD analyze`)
- Reviews requirements/documentation
- Generates comprehensive design document
- Runs Validator/Improver loop (max 3 iterations)
- Human approval gate

### 3. Planning (`/FDD plan`)
- Decomposes requirements into Feature Sets
- Builds dependency DAG (Directed Acyclic Graph)
- Validates dependency integrity
- Human approval gate

### 4. Detailed Design (`/FDD design`)
- Creates implementation specs per Feature Set
- Defines interfaces and contracts
- Validates technical accuracy

### 5. Development (`/FDD develop`)
- Parallel feature development using Task tool
- Automatic quality checks via PostToolUse hooks
- Iterative improvement with checkpointing

## Plugin Structure

```
fdd-is-all-you-need/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata
│   └── marketplace.json     # Marketplace definition
├── commands/                # Slash commands (16 commands)
├── agents/                  # Subagents (4 agents)
│   ├── fdd-orchestrator.md  # Central coordinator (Opus)
│   ├── fdd-designer.md      # Detailed design (Sonnet)
│   ├── fdd-developer.md     # Implementation (Sonnet)
│   └── fdd-improver.md      # Artifact improvement (Sonnet)
├── scripts/                 # Utility scripts (7 scripts)
│   ├── quality-check.sh     # PostToolUse code quality hook
│   ├── file-lock.sh         # Concurrent access protection
│   ├── atomic-write.sh      # Safe file write operations
│   ├── checkpoint-git.sh    # Git-based checkpointing
│   ├── timeout-monitor.sh   # Task timeout monitoring
│   ├── validate-deps.sh     # Dependency validation
│   └── validate-consistency.sh  # Artifact consistency check
├── templates/               # Configuration templates
└── docs/                    # Documentation
    ├── SPECIFICATION.md     # Full FDD specification
    ├── ID_CONVENTIONS.md    # ID naming conventions
    └── IMPLEMENTATION_PLAN.md
```

## Project Structure (After `/FDD init`)

```
your-project/
├── .claude/
│   └── settings.json       # Hook configuration
├── .FDD/
│   ├── config.yaml         # Project configuration
│   ├── feature_map.yaml    # Feature Map (source of truth)
│   ├── scripts/            # Utility scripts
│   ├── iterations/         # Iteration artifacts
│   ├── checkpoints/        # Resume points
│   └── logs/               # Event logs
└── CLAUDE.md               # FDD workflow guidelines (appended)
```

## Feature Map Structure

The Feature Map uses 3-layer context:

1. **Business Context**: Objectives, constraints, success criteria
2. **Design Context**: Architecture, patterns, technologies
3. **Implementation Context**: Files, interfaces, dependencies

```yaml
feature_sets:
  - id: FS-001
    name: "User Authentication"
    status: pending
    dependencies: []
    features:
      - id: F-001-001
        name: "Login Form"
        status: pending
```

## Quality Assurance

### Code Quality (Automatic)
PostToolUse hooks run after every Write/Edit:
- TypeScript/JavaScript: Type checking, ESLint
- Python: Syntax check, Ruff
- Go: go vet
- Rust: cargo check
- YAML/JSON: Syntax validation

### Artifact Quality (Validator/Improver Loop)
- Design document: Completeness, clarity, consistency
- Feature Map: Dependency validity, coverage, granularity
- Detailed design: Technical accuracy, feasibility

## Configuration

Edit `.FDD/config.yaml`:

```yaml
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

## Parallel Execution

Independent Feature Sets are developed in parallel:

```
Wave 1: [FS-001, FS-002] (no dependencies)
Wave 2: [FS-003, FS-004] (depend on FS-001)
Wave 3: [FS-005] (depends on FS-002, FS-003)
```

## Checkpointing & Resume

Checkpoints are automatically saved after each wave. Resume from interruption:

```
/FDD resume
```

## Available Commands

| Command | Description |
|---------|-------------|
| `/FDD` | Show help and available commands |
| `/FDD init` | Initialize FDD in current project |
| `/FDD analyze` | Analyze requirements, create design document |
| `/FDD plan` | Generate Feature Map |
| `/FDD design` | Create detailed designs |
| `/FDD develop` | Execute parallel development |
| `/FDD status` | Show current progress |
| `/FDD resume` | Resume from checkpoint |
| `/FDD-validate-map` | Validate Feature Map |
| `/FDD-validate-design` | Validate design document |
| `/FDD-validate-detail` | Validate detailed design |
| `/FDD-update-status` | Update feature status |
| `/FDD-get-executable` | Find executable feature sets |
| `/FDD-checkpoint` | Save checkpoint |
| `/FDD-improve` | Run Validator/Improver loop |
| `/FDD-rollback` | Rollback to checkpoint |

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [GitHub repository](https://github.com/changeroa/fdd-is-all-you-need)
- [Issue tracker](https://github.com/changeroa/fdd-is-all-you-need/issues)
