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
    spawning fdd-developer agents in parallel where possible."
)
```

The orchestrator will:
1. Analyze dependency graph
2. Spawn `fdd-developer` agents in parallel waves
3. Track progress and update statuses
4. Save checkpoints after each wave
5. Handle errors and deadlocks

---

### Manual Mode (Alternative)

If you prefer direct control:

#### Phase 1: Load Execution Plan
1. Read `.FDD/feature_map.yaml`
2. Identify parallel execution groups using `/FDD-get-executable`:
   ```
   /FDD-get-executable 3
   ```

#### Phase 2: Spawn Developer Agents

For independent Feature Sets, spawn in parallel:
```
Task(subagent_type: "fdd-is-all-you-need:fdd-developer",
     prompt: "Implement FS-001: User Auth
              Design: .FDD/iterations/design_FS-001.md")
Task(subagent_type: "fdd-is-all-you-need:fdd-developer",
     prompt: "Implement FS-002: Database
              Design: .FDD/iterations/design_FS-002.md")
# Both run in parallel
```

#### Phase 3: Handle Completion
- Update status: `/FDD-update-status FS-XXX completed`
- Save checkpoint: `/FDD-checkpoint [iteration] FS-XXX`
- Get next batch: `/FDD-get-executable`

### Phase 3: Quality Enforcement

The PostToolUse hook automatically runs quality checks:
- On every Write/Edit operation
- Runs `.FDD/scripts/quality-check.sh`
- If check fails, the agent must fix before proceeding

### Phase 4: Iteration Loop

Repeat until all Feature Sets are completed:

```
while (pending_feature_sets > 0):
    # Get executable Feature Sets using /FDD-get-executable
    executable = /FDD-get-executable [max_parallel]

    if executable.length == 0 and pending > 0:
        # Deadlock detected
        report_blocked_features()
        ask_user_for_intervention()
        break

    # Execute in parallel (spawn developer agents)
    parallel_execute(executable)

    # Update status for each completed Feature Set
    for each completed FS:
        /FDD-update-status FS-XXX completed

    # Save checkpoint using /FDD-checkpoint
    /FDD-checkpoint [iteration_number]

    iteration_number++
```

### Phase 5: Completion

When all Feature Sets are completed:
1. Update `feature_map.yaml`:
   - Set all statuses to `completed`
   - Update `metadata.completed_features`
2. Log completion event
3. Present summary to user:
   - Total features implemented
   - Total iterations
   - Any issues encountered

## Parallel Execution Strategy

```
Iteration 1: [FS-001, FS-002] (no dependencies)
Iteration 2: [FS-003, FS-004] (depend on FS-001)
Iteration 3: [FS-005] (depends on FS-002, FS-003)
...
```

## Output
- Implemented codebase
- Updated `.FDD/feature_map.yaml`
- Checkpoints in `.FDD/checkpoints/`
- Logs in `.FDD/logs/`

## Recovery
If interrupted, use `/FDD resume` to continue from last checkpoint.
