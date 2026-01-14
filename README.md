# FDD is All You Need

[![npm version](https://badge.fury.io/js/fdd-is-all-you-need.svg)](https://www.npmjs.com/package/fdd-is-all-you-need)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A systematic multi-agent development workflow based on Feature-Driven Development (FDD) principles, designed to run within Claude Code.

## Philosophy: Repeatable Precision

Quality comes from **process and accumulated context**, not genius one-shots. FDD provides structured workflows, quality gates, and iterative improvement loops to achieve consistent, high-quality results.

## Installation

### Via npm (Recommended)

```bash
# Install globally
npm install -g fdd-is-all-you-need

# Install in your project
npx fdd-is-all-you-need install

# Or specify a directory
npx fdd-is-all-you-need install ./my-project
```

### Via npx (No installation)

```bash
npx fdd-is-all-you-need install ./my-project
```

### Manual Installation

```bash
git clone https://github.com/changeroa/FDD-is-all-you-need.git
cd FDD-is-all-you-need
bash install.sh /path/to/your/project
```

## Quick Start

After installation, start Claude Code in your project:

```bash
cd your-project
claude
```

Then use the slash commands:

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

## Project Structure

After installation, your project will have:

```
your-project/
├── .claude/
│   ├── commands/           # Slash command definitions
│   │   ├── FDD.md
│   │   ├── FDD-init.md
│   │   ├── FDD-analyze.md
│   │   ├── FDD-plan.md
│   │   ├── FDD-design.md
│   │   ├── FDD-develop.md
│   │   ├── FDD-status.md
│   │   └── FDD-resume.md
│   └── settings.json       # Hook configuration
├── .FDD/
│   ├── config.yaml         # Project configuration
│   ├── feature_map.yaml    # Feature Map (source of truth)
│   ├── hooks/              # Utility scripts
│   ├── iterations/         # Iteration artifacts
│   ├── checkpoints/        # Resume points
│   └── logs/               # Event logs
└── CLAUDE.md               # Workflow guidelines
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
quality_check:
  enabled: true
  max_retries: 3

artifact_quality:
  max_iterations: 3

approval_gates:
  design_document: true
  feature_map: true
  detailed_design: true

feature_development:
  max_parallel_features: 3
```

## Parallel Execution

Independent Feature Sets are developed in parallel:

```
Iteration 1: [FS-001, FS-002] (no dependencies)
Iteration 2: [FS-003, FS-004] (depend on FS-001)
Iteration 3: [FS-005] (depends on FS-002, FS-003)
```

## Checkpointing & Resume

Checkpoints are automatically saved after each iteration. Resume from interruption:

```
/FDD resume
```

## CLI Commands

```bash
# Show help
npx fdd-is-all-you-need help

# Install to current directory
npx fdd-is-all-you-need install

# Or use the short alias
fdd install ./my-project
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Links

- [npm package](https://www.npmjs.com/package/fdd-is-all-you-need)
- [GitHub repository](https://github.com/changeroa/FDD-is-all-you-need)
- [Issue tracker](https://github.com/changeroa/FDD-is-all-you-need/issues)
