# FDD Validate Detailed Design

Validate technical accuracy, feasibility, and interface consistency of detailed design documents.

## Usage
```
/FDD-validate-detail <path>
```
- `path`: Required. Path to the detailed design file (e.g., `.FDD/iterations/design_FS-001.md`)

## Instructions

### 1. Load Detailed Design
Read the specified detailed design markdown file.

### 2. Required Sections Check

Verify these sections exist:

| Section | Purpose |
|---------|---------|
| Overview | Feature Set summary and goals |
| Architecture | Component structure and interactions |
| Feature Specifications | Detailed specs for each feature |
| Implementation Order | Recommended build sequence |

### 3. Technical Validation

**Feature ID References**:
- Document must reference Feature IDs from the Feature Map
- Pattern: `F-XXX-YYY` (e.g., `F-001-001`)
- Flag if no Feature IDs found

**Code Blocks**:
- Should contain interface definitions (code blocks with ```)
- Types, function signatures, API contracts

**File References**:
- Should reference specific file paths
- Patterns: `.ts`, `.js`, `.py`, `.go`, `.rs`, `.java`

**Test Cases**:
- Should mention testing approach
- Keywords: "test", "spec", "verify"

### 4. Content Quality

**Minimum Content**:
- Document should contain at least 100 words
- Flag if too brief

**Incomplete Markers**:
- Search for: `TODO`, `TBD`, `FIXME`
- Report as warnings if found

### 5. Output Results

```markdown
=== Detailed Design Validation ===
File: .FDD/iterations/design_FS-001.md

[If all pass]
✓ Validation PASSED

[If warnings only]
Warnings:
  ⚠ No code blocks found - consider adding interface definitions
  ⚠ No test cases mentioned
  ⚠ Document contains TODO markers

⚠ Validation PASSED with warnings

[If errors]
Issues:
  ✗ Missing section: Implementation Order
  ✗ No Feature IDs found - should reference features from Feature Map
  ✗ Document seems too brief (80 words)

✗ Validation FAILED - X issue(s) found
```

### 6. Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{"timestamp":"ISO8601","event":"validation","artifact":"detailed_design","file":"<path>","result":"pass|fail|pass_with_warnings"}
```

## Return Values
- **PASS**: All sections present, technical content adequate
- **PASS_WITH_WARNINGS**: Structure valid, recommendations exist
- **FAIL**: Missing critical sections or inadequate technical detail

## Improvement Guidance

If validation fails, suggest:
- Add missing technical specifications
- Include code interface definitions
- Add test case descriptions
- Reference specific file paths
- Link features to Feature Map IDs

## Called By
- `/FDD-design` (after detailed design generation)
- `/FDD-improve` (during quality loop)
