# FDD Improve

Run the Validator/Improver quality loop on an artifact.

## Usage
```
/FDD-improve <artifact_type> <file_path> [max_iterations]
```

### Arguments
- `artifact_type`: One of `design_document`, `feature_map`, `detailed_design`
- `file_path`: Path to the artifact file
- `max_iterations`: Optional. Maximum improvement cycles. Default: 3

### Examples
```
/FDD-improve design_document .FDD/iterations/design_document.md
/FDD-improve feature_map .FDD/feature_map.yaml
/FDD-improve detailed_design .FDD/iterations/design_FS-001.md 2
```

## Instructions

### 1. Initialize Quality Loop

```
=== FDD Artifact Quality Loop ===
Artifact: design_document
File: .FDD/iterations/design_document.md
Max Iterations: 3
```

Log start:
```json
{"timestamp":"ISO8601","event":"quality_loop_start","artifact":"<type>","file":"<path>","max_iterations":3}
```

### 2. Validation Phase

Select and invoke the appropriate validation skill:

| Artifact Type | Validation Skill |
|---------------|------------------|
| design_document | `/FDD-validate-design` |
| feature_map | `/FDD-validate-map` |
| detailed_design | `/FDD-validate-detail` |

### 3. Quality Loop Execution

```
FOR iteration = 1 TO max_iterations:

  --- Iteration {iteration}/{max_iterations} ---

  RUN validation_skill(file_path)

  IF validation PASSES:
    Log: quality_loop_pass
    RETURN SUCCESS

  IF iteration == max_iterations:
    Log: quality_loop_max_reached
    RETURN FAILURE (manual intervention required)

  >>> IMPROVEMENT REQUIRED <<<

  INVOKE fdd-improver agent with:
    - Artifact type
    - File path
    - Validation feedback
    - Improvement guidance

  CONTINUE to next iteration
```

### 4. Improvement Guidance by Artifact Type

**design_document**:
- Add missing sections
- Expand brief sections with more detail
- Resolve TODO/TBD markers
- Ensure clarity and consistency

**feature_map**:
- Fix dependency references
- Resolve circular dependencies
- Adjust feature granularity
- Ensure all requirements are covered

**detailed_design**:
- Add missing technical specifications
- Include code interface definitions
- Add test case descriptions
- Reference specific file paths

### 5. Output Results

**On Success**:
```
--- Iteration 2/3 ---
[Validation output]

✓ Quality check PASSED at iteration 2
```

**On Failure (max iterations)**:
```
--- Iteration 3/3 ---
[Validation output]

✗ Maximum iterations reached. Manual intervention required.

Improvement suggestions:
- [Specific issues to fix]
```

### 6. Log Events

Track each iteration:
```json
{"timestamp":"ISO8601","event":"quality_loop_iteration","artifact":"<type>","iteration":1}
{"timestamp":"ISO8601","event":"quality_loop_fail","artifact":"<type>","iteration":1}
{"timestamp":"ISO8601","event":"quality_loop_pass","artifact":"<type>","iteration":2}
```

Or on failure:
```json
{"timestamp":"ISO8601","event":"quality_loop_max_reached","artifact":"<type>","message":"Max iterations reached without passing"}
```

## Agent Integration

This skill invokes the `fdd-improver` agent for complex improvements:

```
Task: fdd-improver
Prompt: |
  Improve the {artifact_type} at {file_path}

  Validation feedback:
  {validation_output}

  Focus areas:
  {improvement_guidance}

  Requirements:
  - Address all validation issues
  - Preserve existing valid content
  - Maintain document structure
```

## Return Values
- **SUCCESS**: Artifact passed validation
- **FAILURE**: Max iterations reached without passing

## Called By
- `/FDD-analyze` (design document quality loop)
- `/FDD-plan` (feature map quality loop)
- `/FDD-design` (detailed design quality loop)
