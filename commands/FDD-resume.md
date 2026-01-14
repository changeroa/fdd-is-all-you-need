# FDD Resume

Resume development from the last checkpoint.

## Prerequisites
- FDD must be initialized
- At least one checkpoint must exist

## Instructions

### Phase 1: Find Latest Checkpoint
1. List files in `.FDD/checkpoints/`
2. Sort by timestamp (filename contains timestamp)
3. Select most recent checkpoint
4. If no checkpoints found, inform user and suggest starting fresh

### Phase 2: Load Checkpoint State
1. Read checkpoint file (YAML format)
2. Extract:
   - Feature Map state at checkpoint time
   - Iteration number
   - Feature Set that was being processed

### Phase 3: Analyze Current State
1. Compare checkpoint state with current `.FDD/feature_map.yaml`
2. Identify:
   - Features completed since checkpoint
   - Features that were in progress
   - Features still pending

### Phase 4: Determine Resume Point
```
Resume Strategy:
1. If Feature Set was in_progress → Resume that Feature Set
2. If iteration was complete → Start next iteration
3. If blocked features exist → Report and ask for guidance
```

### Phase 5: Display Resume Summary
```markdown
## Resume Summary

### Checkpoint Information
- Checkpoint File: [path]
- Created At: [timestamp]
- Iteration: X

### State at Checkpoint
- Completed Feature Sets: [list]
- In Progress: [Feature Set name]
- Remaining: [count]

### Resume Action
Will resume from: [specific point]
Next steps:
1. [Step 1]
2. [Step 2]

Proceed with resume? (Y/n)
```

### Phase 6: Execute Resume
If user confirms:
1. Restore Feature Map to checkpoint state (if needed)
2. Update any stale statuses
3. Call the appropriate continuation:
   - If in development phase → Continue `/FDD develop`
   - If in design phase → Continue `/FDD design`

### Error Handling
- **No checkpoints**: "No checkpoints found. Run `/FDD status` to see current state."
- **Corrupted checkpoint**: "Checkpoint file corrupted. Using feature_map.yaml as source of truth."
- **Missing dependencies**: "Some files referenced in checkpoint are missing. Manual intervention required."

## Output
- Resumed workflow from checkpoint
- Log resume event to `.FDD/logs/events.jsonl`
- Continue with normal development flow
