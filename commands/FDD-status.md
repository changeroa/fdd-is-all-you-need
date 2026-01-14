# FDD Status

Display current progress and state of the FDD workflow.

## Instructions

### 1. Check Initialization
- Verify `.FDD/` directory exists
- If not initialized, suggest `/FDD init`

### 2. Load State Files
Read the following if they exist:
- `.FDD/config.yaml`
- `.FDD/feature_map.yaml`
- `.FDD/logs/events.jsonl` (last 10 events)

### 3. Display Status Report

```markdown
## FDD Status Report

### Project
- Name: [from config]
- Initialized: [date]

### Current Phase
[One of: Not Started | Analyzing | Planning | Designing | Developing | Completed]

### Feature Map Summary
- Total Feature Sets: X
- Completed: Y
- In Progress: Z
- Pending: W
- Blocked: V

### Feature Sets Status
| ID | Name | Status | Progress |
|----|------|--------|----------|
| FS-001 | [Name] | completed | 5/5 features |
| FS-002 | [Name] | in_progress | 2/4 features |
| FS-003 | [Name] | pending | 0/3 features |
| FS-004 | [Name] | blocked | 0/2 features (waiting on FS-002) |

### Execution Progress
- Current Iteration: X
- Last Checkpoint: [timestamp]
- Parallel Capacity: [from config]

### Recent Activity
[Last 5 events from logs]

### Next Actions
- [What needs to happen next]
```

### 4. Check for Issues
- Identify blocked Feature Sets
- Check for stale checkpoints
- Report any quality check failures from logs

### 5. Recommendations
Based on current state, suggest next action:
- If not initialized: `/FDD init`
- If no design doc: `/FDD analyze`
- If no Feature Map: `/FDD plan`
- If no detailed designs: `/FDD design`
- If development pending: `/FDD develop`
- If interrupted: `/FDD resume`

## Output Format
Display the status report in a clear, readable format.
Show progress bars where appropriate:
```
Feature Set Progress: [████████░░] 80%
```
