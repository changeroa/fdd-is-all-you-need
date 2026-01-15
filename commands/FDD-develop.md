# FDD Develop

Execute parallel feature development based on the Feature Map.

## Prerequisites
- Feature Map with populated `feature_sets`
- Detailed designs for all Feature Sets
- All design approvals obtained

## Instructions

### Execution Mode: Use Orchestrator (Recommended)

Invoke the `fdd-orchestrator` agent to handle the entire development process:

```
Task(
  subagent_type: "fdd-is-all-you-need:fdd-orchestrator",
  prompt: "Execute FDD development workflow.

    Mode: develop
    Feature Map: .FDD/feature_map.yaml
    Max parallel: 3

    Orchestrate the implementation of all Feature Sets,
    spawning fdd-developer agents in parallel where possible.

    Use the following scripts for safety:
    - file-lock.sh for locking
    - atomic-write.sh for safe file writes
    - checkpoint-git.sh for checkpoints
    - timeout-monitor.sh for stale detection
    - validate-consistency.sh for state validation"
)
```

The orchestrator will:
1. Validate dependencies using `validate-deps.sh`
2. Analyze dependency graph with priority ordering
3. Spawn `fdd-developer` agents in parallel waves
4. Track progress with timeout monitoring
5. Update statuses with proper locking
6. Save Git-integrated checkpoints after each wave
7. Validate state-code consistency
8. Handle errors and deadlocks

---

### Manual Mode (Alternative)

If you prefer direct control:

#### Phase 1: Pre-Development Validation

Before starting, validate the Feature Map:
```bash
bash .FDD/scripts/validate-deps.sh check .FDD/feature_map.yaml
```

This ensures:
- No circular dependencies
- All references are valid
- Execution order is determinable

#### Phase 2: Get Execution Plan

Get executable Feature Sets with priority ordering:
```bash
bash .FDD/scripts/validate-deps.sh waves .FDD/feature_map.yaml
```

Output shows parallel execution waves ordered by priority:
```
Wave 1:
  - FS-001: User Authentication [critical]
  - FS-002: Database Setup [high]

Wave 2:
  - FS-003: API Endpoints [medium]
  - FS-004: Frontend Base [medium]
```

Or use the skill:
```
/FDD-get-executable 3
```

#### Phase 3: Spawn Developer Agents

For independent Feature Sets, spawn in parallel with unique agent IDs:
```
Task(subagent_type: "fdd-is-all-you-need:fdd-developer",
     prompt: "Implement FS-001: User Auth
              Design: .FDD/iterations/design_FS-001.md
              Agent ID: fdd-dev-001")
Task(subagent_type: "fdd-is-all-you-need:fdd-developer",
     prompt: "Implement FS-002: Database
              Design: .FDD/iterations/design_FS-002.md
              Agent ID: fdd-dev-002")
# Both run in parallel
```

#### Phase 4: Monitor Progress

Start timeout monitoring:
```bash
bash .FDD/scripts/timeout-monitor.sh check
```

This detects:
- Stale `in_progress` Feature Sets (exceeded timeout)
- Active Feature Sets and their remaining time
- Potential deadlocks

If stale detected:
```bash
# Mark stale Feature Sets as blocked
bash .FDD/scripts/timeout-monitor.sh mark-stale

# Or reset specific Feature Set
bash .FDD/scripts/timeout-monitor.sh reset FS-003
```

#### Phase 5: Handle Completion

After each Feature Set completes:

1. **Update status** (with proper locking):
```
/FDD-update-status FS-XXX completed fdd-dev-001
```

2. **Validate consistency**:
```bash
bash .FDD/scripts/validate-consistency.sh check
```

3. **Save checkpoint** (with Git integration):
```bash
bash .FDD/scripts/checkpoint-git.sh create [iteration] FS-XXX "Completed FS-XXX"
```

4. **Get next batch**:
```
/FDD-get-executable
```

#### Phase 6: Quality Enforcement

The PostToolUse hook automatically runs quality checks:
- On every Write/Edit operation
- Runs `.FDD/scripts/quality-check.sh`
- **Project-wide type checking** (not single file)
- If check fails, the agent must fix before proceeding

#### Phase 7: Iteration Loop

Repeat until all Feature Sets are completed:

```python
while pending_feature_sets > 0:
    # Check for stale/timed out Feature Sets
    run("bash .FDD/scripts/timeout-monitor.sh mark-stale")

    # Get executable Feature Sets with priority
    executable = run("/FDD-get-executable [max_parallel]")

    if len(executable) == 0 and pending > 0:
        # Deadlock detected
        report_blocked_features()
        ask_user_for_intervention()
        break

    # Execute in parallel (spawn developer agents with unique IDs)
    for i, fs in enumerate(executable):
        spawn_agent(fs, agent_id=f"fdd-dev-{iteration}-{i}")

    # Update status with locking for each completed
    for fs in completed:
        run(f"/FDD-update-status {fs} completed {agent_id}")

    # Validate state-code consistency
    run("bash .FDD/scripts/validate-consistency.sh check")

    # Save Git-integrated checkpoint
    run(f"bash .FDD/scripts/checkpoint-git.sh create {iteration}")

    iteration++
```

#### Phase 8: Completion

When all Feature Sets are completed:

1. **Final consistency check**:
```bash
bash .FDD/scripts/validate-consistency.sh check
```

2. **Check for orphaned files**:
```bash
bash .FDD/scripts/validate-consistency.sh orphans
```

3. **Update Feature Map**:
   - Set all statuses to `completed`
   - Update `metadata.completed_features`

4. **Create final checkpoint**:
```bash
bash .FDD/scripts/checkpoint-git.sh create final complete "All features implemented"
```

5. **Clean up stale locks**:
```bash
bash .FDD/scripts/file-lock.sh cleanup .FDD/
```

6. **Present summary** to user:
   - Total features implemented
   - Total iterations
   - Any issues encountered

## Parallel Execution Strategy

With priority ordering:
```
Wave 1: [FS-001 (critical), FS-002 (high)]  - No dependencies
Wave 2: [FS-003 (medium), FS-004 (medium)]  - Depend on Wave 1
Wave 3: [FS-005 (low)]                       - Depends on Wave 2
```

## Timeout Configuration

Configure in `.FDD/config.yaml`:
```yaml
feature_development:
  default_timeout: 1800000  # 30 minutes in milliseconds
  max_parallel_features: 3
```

## Output
- Implemented codebase
- Updated `.FDD/feature_map.yaml`
- Git commits for each wave
- Git tags for each checkpoint
- Checkpoints in `.FDD/checkpoints/`
- Logs in `.FDD/logs/`

## Recovery

### From Timeout/Stale
```bash
# Check status
bash .FDD/scripts/timeout-monitor.sh check

# Reset stale Feature Set
bash .FDD/scripts/timeout-monitor.sh reset FS-XXX

# Resume development
/FDD-develop
```

### From State-Code Mismatch
```bash
# Check consistency
bash .FDD/scripts/validate-consistency.sh check

# Auto-fix simple issues
bash .FDD/scripts/validate-consistency.sh fix

# Resume development
/FDD-develop
```

### Full Rollback (State + Code)
```bash
# 1. Restore Feature Map state
bash .FDD/scripts/checkpoint-git.sh restore latest

# 2. Restore code
git checkout fdd-checkpoint_YYYYMMDD_HHMMSS_mmm
```

### Feature Map Only
Use `/FDD-resume` to continue from last checkpoint.
