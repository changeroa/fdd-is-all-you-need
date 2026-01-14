# FDD ID Format Conventions

This document defines the identifier formats used in FDD Feature Maps.

## Overview

FDD uses structured identifiers to uniquely identify Feature Sets and Features.
These IDs are used throughout the workflow for tracking, dependencies, and status updates.

## ID Formats

### Feature Set ID: `FS-XXX`

| Component | Description | Example |
|-----------|-------------|---------|
| `FS` | Prefix indicating Feature Set | - |
| `-` | Separator | - |
| `XXX` | 3-digit sequential number (001-999) | FS-001 |

**Examples:**
- `FS-001` - First Feature Set
- `FS-002` - Second Feature Set
- `FS-015` - Fifteenth Feature Set

### Feature ID: `F-XXX-YYY`

| Component | Description | Example |
|-----------|-------------|---------|
| `F` | Prefix indicating Feature | - |
| `-` | Separator | - |
| `XXX` | Parent Feature Set number | 001 |
| `-` | Separator | - |
| `YYY` | Feature number within set (001-999) | 001 |

**Examples:**
- `F-001-001` - First feature in FS-001
- `F-001-002` - Second feature in FS-001
- `F-003-005` - Fifth feature in FS-003

## ID Assignment Rules

### Sequential Assignment
```
When creating Feature Sets:
  Next ID = max(existing FS IDs) + 1
  If no existing: Start at FS-001

When creating Features in FS-XXX:
  Next ID = F-XXX-{max(existing feature numbers) + 1}
  If no existing: Start at F-XXX-001
```

### ID Stability
- **IDs are immutable** - Once assigned, an ID never changes
- **IDs are never reused** - Deleted items leave gaps in sequence
- **Dependencies reference IDs** - ID changes would break relationships

## Validation Patterns

Use these regex patterns to validate IDs:

```regex
Feature Set ID: ^FS-[0-9]{3}$
Feature ID:     ^F-[0-9]{3}-[0-9]{3}$
```

## Usage in Feature Map

```yaml
feature_sets:
  - id: FS-001
    name: "User Authentication"
    status: pending
    dependencies: []  # References other FS-XXX IDs
    features:
      - id: F-001-001
        name: "Login Form"
        status: pending
        dependencies: []  # References other F-XXX-YYY IDs (within same set)
      - id: F-001-002
        name: "Registration Form"
        status: pending
        dependencies: [F-001-001]  # Depends on Login Form

  - id: FS-002
    name: "Dashboard"
    dependencies: [FS-001]  # Depends on User Authentication
    features:
      - id: F-002-001
        name: "Dashboard Layout"
        status: pending
```

## Dependency Scope

| Dependency Type | Scope | Example |
|-----------------|-------|---------|
| Feature Set → Feature Set | Cross-set | `FS-002` depends on `FS-001` |
| Feature → Feature | Within same set | `F-001-002` depends on `F-001-001` |

**Note:** Cross-Feature-Set feature dependencies are not supported. If a feature in FS-002 needs functionality from FS-001, declare the dependency at the Feature Set level.

## Rationale

This ID format was chosen over semantic IDs (like `set-auth`, `feat-login`) for:

1. **Predictability** - Sequential numbers are deterministic
2. **Uniqueness** - No naming conflicts possible
3. **Parsability** - Easy to extract parent-child relationships from ID
4. **Stability** - Renaming features doesn't break references
5. **Tooling** - Simple regex validation and sorting

## Migration from Other Formats

If you have existing IDs in a different format, create a mapping:

```yaml
id_mapping:
  # Old format -> New format
  "set-auth": "FS-001"
  "feat-login": "F-001-001"
```

Then update all references using find-replace.
