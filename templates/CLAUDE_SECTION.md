
## FDD Workflow

This project uses **FDD** (Feature-Driven Development) workflow for systematic software development.

### Quick Start

```
/FDD init          # Initialize project
/FDD analyze       # Create design document from requirements
/FDD plan          # Generate Feature Map
/FDD design        # Create detailed designs
/FDD develop       # Execute feature development
/FDD status        # Check current progress
/FDD resume        # Resume from checkpoint
```

### Workflow Phases

1. **Initialization** (`/FDD init`)
   - Configure project settings
   - Set up directory structure

2. **Analysis** (`/FDD analyze`)
   - Review requirements/documentation
   - Generate design document
   - Quality validation loop (max 3 iterations)

3. **Planning** (`/FDD plan`)
   - Decompose into Feature Sets
   - Build dependency DAG
   - Quality validation loop

4. **Detailed Design** (`/FDD design`)
   - Create implementation specs per Feature Set
   - Define interfaces and contracts
   - Quality validation loop

5. **Development** (`/FDD develop`)
   - Parallel feature development
   - Automatic quality checks via hooks
   - Iterative improvement cycles

### Feature Map Structure

The Feature Map (`.FDD/feature_map.yaml`) contains:
- **Business Context**: Objectives, constraints, success criteria
- **Design Context**: Architecture, patterns, technologies
- **Feature Sets**: Grouped features with dependencies

### Quality Assurance

- **Code Quality**: PostToolUse hooks run automatic checks on Write/Edit
- **Artifact Quality**: Validator/Improver loops for design documents
- **Human Gates**: Approval points at major milestones

### Available Skills

**Validation Skills** (invoked by workflow commands):
- `/FDD-validate-map` - Validate Feature Map structure
- `/FDD-validate-design` - Validate design document
- `/FDD-validate-detail` - Validate detailed design
- `/FDD-improve` - Run quality improvement loop

**State Management Skills**:
- `/FDD-update-status` - Update feature status
- `/FDD-get-executable` - Find ready-to-execute features
- `/FDD-checkpoint` - Save checkpoint

### State Management

All state is stored in `.FDD/`:
- `config.yaml` - Project configuration
- `feature_map.yaml` - Feature Map (source of truth)
- `iterations/` - Iteration artifacts
- `checkpoints/` - Resume points
- `logs/` - Event and audit logs

### Resuming Work

Use `/FDD resume` to continue from the last checkpoint. The system will:
1. Load the latest Feature Map state
2. Identify pending/blocked features
3. Continue execution from where it stopped
