# FDD Validate Design Document

Validate the completeness, clarity, and consistency of the design document.

## Usage
```
/FDD-validate-design [path]
```
- `path`: Optional. Default: `.FDD/iterations/design_document.md`

## Instructions

### 1. Load Design Document
Read the design document markdown file.

### 2. Required Sections Check

Verify these sections exist (case-insensitive search):

| Section | Purpose |
|---------|---------|
| Executive Summary | High-level project overview |
| Business Context | Objectives and constraints |
| Objectives | Specific goals |
| Constraints | Limitations and boundaries |
| Functional Requirements | What the system must do |
| Non-Functional Requirements | Quality attributes (performance, security) |
| Technical Architecture | System design overview |

### 3. Content Quality Checks

**Minimum Content**:
- Document should contain at least 200 words
- Flag if too brief

**Empty Sections**:
- Detect headers immediately followed by another header (empty sections)
- Example pattern: `## Section\n\n## Next Section` (empty)

**Incomplete Markers**:
- Search for: `TODO`, `TBD`, `FIXME`, `[placeholder]`
- Report as warnings if found

### 4. Consistency Checks

- Requirements should have IDs: `FR-XXX`, `NFR-XXX`
- Success criteria should be measurable
- Constraints should align with technical architecture

### 5. Output Results

```markdown
=== Design Document Validation ===
File: .FDD/iterations/design_document.md

[If all pass]
✓ Validation PASSED

[If warnings only]
Warnings:
  ⚠ Document contains TODO markers that need resolution
  ⚠ Some sections appear to be empty

⚠ Validation PASSED with warnings

[If errors]
Issues:
  ✗ Missing section: Non-Functional Requirements
  ✗ Document seems too brief (150 words). Expected at least 200 words.

✗ Validation FAILED - X issue(s) found
```

### 6. Log Event

Append to `.FDD/logs/events.jsonl`:
```json
{"timestamp":"ISO8601","event":"validation","artifact":"design_document","result":"pass|fail|pass_with_warnings","issues":[]}
```

## Return Values
- **PASS**: All required sections present, adequate content
- **PASS_WITH_WARNINGS**: Structure valid, minor issues
- **FAIL**: Missing critical sections or inadequate content

## Improvement Guidance

If validation fails, suggest:
- Add missing sections
- Expand brief sections with more detail
- Resolve TODO/TBD markers
- Ensure clarity and consistency

## Called By
- `/FDD-analyze` (after design document generation)
- `/FDD-improve` (during quality loop)
