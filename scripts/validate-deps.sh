#!/bin/bash
# FDD Dependency Validation Script
# Validates Feature Map dependencies and detects issues
#
# Features:
# - Circular dependency detection (DFS-based)
# - Missing dependency reference detection
# - Topological sort generation
# - Execution wave calculation
#
# Usage:
#   validate-deps.sh check [feature_map_path]     # Full validation
#   validate-deps.sh cycles [feature_map_path]    # Circular dependency check only
#   validate-deps.sh order [feature_map_path]     # Generate execution order
#   validate-deps.sh waves [feature_map_path]     # Show parallel execution waves

set -e

ACTION="${1:-check}"
FEATURE_MAP="${2:-.FDD/feature_map.yaml}"

if [ ! -f "$FEATURE_MAP" ]; then
    echo "[ValidateDeps] Error: Feature map not found: $FEATURE_MAP"
    exit 1
fi

# Main validation logic in Python for reliable parsing
python3 << 'PYTHON_SCRIPT'
import yaml
import sys
import json
from collections import defaultdict, deque
from typing import Dict, List, Set, Tuple, Optional

def load_feature_map(path: str) -> dict:
    """Load and parse feature map YAML"""
    try:
        with open(path, 'r') as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        print(f"[ValidateDeps] Error: Invalid YAML in feature map: {e}")
        sys.exit(1)

def extract_feature_sets(data: dict) -> Dict[str, dict]:
    """Extract feature sets as id -> feature_set mapping"""
    feature_sets = {}
    for fs in data.get('feature_sets', []):
        fs_id = fs.get('id')
        if fs_id:
            feature_sets[fs_id] = fs
    return feature_sets

def build_dependency_graph(feature_sets: Dict[str, dict]) -> Dict[str, List[str]]:
    """Build adjacency list for dependency graph"""
    graph = defaultdict(list)
    for fs_id, fs in feature_sets.items():
        deps = fs.get('dependencies', [])
        if deps:
            for dep in deps:
                graph[fs_id].append(dep)
        else:
            graph[fs_id] = []  # Ensure all nodes are in graph
    return dict(graph)

def detect_cycles(graph: Dict[str, List[str]]) -> List[List[str]]:
    """Detect circular dependencies using DFS"""
    cycles = []
    visited = set()
    rec_stack = set()
    path = []

    def dfs(node: str) -> bool:
        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                if dfs(neighbor):
                    return True
            elif neighbor in rec_stack:
                # Found cycle - extract it
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                cycles.append(cycle)
                return True

        path.pop()
        rec_stack.remove(node)
        return False

    for node in graph:
        if node not in visited:
            dfs(node)

    return cycles

def validate_references(feature_sets: Dict[str, dict]) -> List[str]:
    """Check that all dependency references are valid"""
    errors = []
    valid_ids = set(feature_sets.keys())

    for fs_id, fs in feature_sets.items():
        for dep in fs.get('dependencies', []):
            if dep not in valid_ids:
                errors.append(f"Feature Set '{fs_id}' references non-existent dependency '{dep}'")

    return errors

def topological_sort(graph: Dict[str, List[str]], feature_sets: Dict[str, dict]) -> Tuple[List[str], bool]:
    """Generate topological order for execution"""
    # Calculate in-degrees
    in_degree = defaultdict(int)
    all_nodes = set(graph.keys())

    for deps in graph.values():
        for dep in deps:
            all_nodes.add(dep)

    for node in all_nodes:
        in_degree[node] = 0

    for node, deps in graph.items():
        for dep in deps:
            in_degree[node] += 1  # node depends on dep

    # BFS-based topological sort
    queue = deque([node for node in all_nodes if in_degree[node] == 0])
    result = []

    while queue:
        node = queue.popleft()
        result.append(node)

        # Find nodes that depend on this node
        for other_node, deps in graph.items():
            if node in deps:
                in_degree[other_node] -= 1
                if in_degree[other_node] == 0:
                    queue.append(other_node)

    success = len(result) == len(all_nodes)
    return result, success

def calculate_waves(graph: Dict[str, List[str]], feature_sets: Dict[str, dict]) -> List[List[str]]:
    """Calculate parallel execution waves based on priority and dependencies"""
    waves = []
    remaining = set(graph.keys())
    completed = set()

    # Priority ordering (higher priority first within each wave)
    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}

    while remaining:
        # Find all feature sets whose dependencies are all completed
        wave = []
        for fs_id in remaining:
            deps = set(graph.get(fs_id, []))
            if deps.issubset(completed):
                fs = feature_sets.get(fs_id, {})
                priority = priority_order.get(fs.get('priority', 'medium'), 2)
                wave.append((priority, fs_id))

        if not wave:
            # Deadlock - remaining items have unresolvable dependencies
            break

        # Sort wave by priority
        wave.sort(key=lambda x: x[0])
        wave_ids = [fs_id for _, fs_id in wave]

        waves.append(wave_ids)
        for fs_id in wave_ids:
            remaining.discard(fs_id)
            completed.add(fs_id)

    return waves

def check_status_consistency(feature_sets: Dict[str, dict]) -> List[str]:
    """Check for status inconsistencies"""
    warnings = []

    for fs_id, fs in feature_sets.items():
        fs_status = fs.get('status', 'pending')
        features = fs.get('features', [])

        if fs_status == 'completed':
            # All features should be completed
            for f in features:
                if f.get('status') != 'completed':
                    warnings.append(
                        f"Feature Set '{fs_id}' is completed but feature '{f.get('id')}' is {f.get('status')}"
                    )

        elif fs_status == 'pending':
            # No features should be in_progress or completed
            for f in features:
                if f.get('status') in ['in_progress', 'completed']:
                    warnings.append(
                        f"Feature Set '{fs_id}' is pending but feature '{f.get('id')}' is {f.get('status')}"
                    )

    return warnings

def main():
    import os
    action = os.environ.get('ACTION', 'check')
    feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

    data = load_feature_map(feature_map_path)
    feature_sets = extract_feature_sets(data)

    if not feature_sets:
        print("[ValidateDeps] No feature sets found in feature map")
        sys.exit(0)

    graph = build_dependency_graph(feature_sets)

    if action == 'cycles':
        cycles = detect_cycles(graph)
        if cycles:
            print("[ValidateDeps] Circular dependencies detected:")
            for cycle in cycles:
                print(f"  ✗ {' → '.join(cycle)}")
            sys.exit(1)
        else:
            print("[ValidateDeps] No circular dependencies found")
            sys.exit(0)

    elif action == 'order':
        order, success = topological_sort(graph, feature_sets)
        if success:
            print("[ValidateDeps] Execution order:")
            for i, fs_id in enumerate(order, 1):
                fs = feature_sets.get(fs_id, {})
                name = fs.get('name', 'Unknown')
                print(f"  {i}. {fs_id}: {name}")
        else:
            print("[ValidateDeps] Cannot generate execution order (circular dependencies exist)")
            sys.exit(1)

    elif action == 'waves':
        waves = calculate_waves(graph, feature_sets)
        if waves:
            print("[ValidateDeps] Parallel execution waves:")
            for i, wave in enumerate(waves, 1):
                print(f"\n  Wave {i}:")
                for fs_id in wave:
                    fs = feature_sets.get(fs_id, {})
                    name = fs.get('name', 'Unknown')
                    priority = fs.get('priority', 'medium')
                    print(f"    - {fs_id}: {name} [{priority}]")

            remaining = set(graph.keys()) - set(fs_id for wave in waves for fs_id in wave)
            if remaining:
                print(f"\n  ⚠ Unreachable (blocked): {', '.join(remaining)}")
        else:
            print("[ValidateDeps] No executable feature sets")

    else:  # 'check' - full validation
        errors = []
        warnings = []

        print("═══════════════════════════════════════════════════")
        print("[ValidateDeps] Feature Map Dependency Validation")
        print("═══════════════════════════════════════════════════")
        print(f"File: {feature_map_path}")
        print(f"Feature Sets: {len(feature_sets)}")
        print()

        # Check references
        ref_errors = validate_references(feature_sets)
        errors.extend(ref_errors)

        # Check cycles
        cycles = detect_cycles(graph)
        for cycle in cycles:
            errors.append(f"Circular dependency: {' → '.join(cycle)}")

        # Check status consistency
        status_warnings = check_status_consistency(feature_sets)
        warnings.extend(status_warnings)

        # Granularity checks
        for fs_id, fs in feature_sets.items():
            feature_count = len(fs.get('features', []))
            if feature_count > 10:
                warnings.append(f"Feature Set '{fs_id}' has {feature_count} features (consider splitting)")
            elif feature_count < 2:
                warnings.append(f"Feature Set '{fs_id}' has only {feature_count} feature(s) (consider merging)")

        # Report results
        if warnings:
            print("⚠ Warnings:")
            for w in warnings:
                print(f"  - {w}")
            print()

        if errors:
            print("✗ Errors:")
            for e in errors:
                print(f"  - {e}")
            print()
            print("═══════════════════════════════════════════════════")
            print("VALIDATION FAILED")
            print("═══════════════════════════════════════════════════")
            sys.exit(1)
        else:
            print("✓ All dependency checks passed")
            print()

            # Show execution preview
            waves = calculate_waves(graph, feature_sets)
            if waves:
                print("Execution preview:")
                for i, wave in enumerate(waves, 1):
                    print(f"  Wave {i}: {', '.join(wave)}")

            print()
            print("═══════════════════════════════════════════════════")
            if warnings:
                print("VALIDATION PASSED (with warnings)")
            else:
                print("VALIDATION PASSED")
            print("═══════════════════════════════════════════════════")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT

# Export variables for Python script
export ACTION="$ACTION"
export FEATURE_MAP="$FEATURE_MAP"

# Execute Python script
python3 << 'PYTHON_SCRIPT'
import yaml
import sys
import os
from collections import defaultdict, deque
from typing import Dict, List, Set, Tuple

def load_feature_map(path: str) -> dict:
    try:
        with open(path, 'r') as f:
            return yaml.safe_load(f) or {}
    except yaml.YAMLError as e:
        print(f"[ValidateDeps] Error: Invalid YAML in feature map: {e}")
        sys.exit(1)

def extract_feature_sets(data: dict) -> Dict[str, dict]:
    feature_sets = {}
    for fs in data.get('feature_sets', []):
        fs_id = fs.get('id')
        if fs_id:
            feature_sets[fs_id] = fs
    return feature_sets

def build_dependency_graph(feature_sets: Dict[str, dict]) -> Dict[str, List[str]]:
    graph = defaultdict(list)
    for fs_id, fs in feature_sets.items():
        deps = fs.get('dependencies', [])
        if deps:
            for dep in deps:
                graph[fs_id].append(dep)
        else:
            graph[fs_id] = []
    return dict(graph)

def detect_cycles(graph: Dict[str, List[str]]) -> List[List[str]]:
    cycles = []
    visited = set()
    rec_stack = set()
    path = []

    def dfs(node: str) -> bool:
        visited.add(node)
        rec_stack.add(node)
        path.append(node)

        for neighbor in graph.get(node, []):
            if neighbor not in visited:
                if dfs(neighbor):
                    return True
            elif neighbor in rec_stack:
                cycle_start = path.index(neighbor)
                cycle = path[cycle_start:] + [neighbor]
                cycles.append(cycle)
                return True

        path.pop()
        rec_stack.remove(node)
        return False

    for node in graph:
        if node not in visited:
            dfs(node)

    return cycles

def validate_references(feature_sets: Dict[str, dict]) -> List[str]:
    errors = []
    valid_ids = set(feature_sets.keys())

    for fs_id, fs in feature_sets.items():
        for dep in fs.get('dependencies', []):
            if dep not in valid_ids:
                errors.append(f"Feature Set '{fs_id}' references non-existent dependency '{dep}'")

    return errors

def topological_sort(graph: Dict[str, List[str]]) -> Tuple[List[str], bool]:
    in_degree = defaultdict(int)
    all_nodes = set(graph.keys())

    for deps in graph.values():
        for dep in deps:
            all_nodes.add(dep)

    for node in all_nodes:
        in_degree[node] = 0

    for node, deps in graph.items():
        for dep in deps:
            in_degree[node] += 1

    queue = deque([node for node in all_nodes if in_degree[node] == 0])
    result = []

    while queue:
        node = queue.popleft()
        result.append(node)

        for other_node, deps in graph.items():
            if node in deps:
                in_degree[other_node] -= 1
                if in_degree[other_node] == 0:
                    queue.append(other_node)

    success = len(result) == len(all_nodes)
    return result, success

def calculate_waves(graph: Dict[str, List[str]], feature_sets: Dict[str, dict]) -> List[List[str]]:
    waves = []
    remaining = set(graph.keys())
    completed = set()

    priority_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}

    while remaining:
        wave = []
        for fs_id in remaining:
            deps = set(graph.get(fs_id, []))
            if deps.issubset(completed):
                fs = feature_sets.get(fs_id, {})
                priority = priority_order.get(fs.get('priority', 'medium'), 2)
                wave.append((priority, fs_id))

        if not wave:
            break

        wave.sort(key=lambda x: x[0])
        wave_ids = [fs_id for _, fs_id in wave]

        waves.append(wave_ids)
        for fs_id in wave_ids:
            remaining.discard(fs_id)
            completed.add(fs_id)

    return waves

def check_status_consistency(feature_sets: Dict[str, dict]) -> List[str]:
    warnings = []

    for fs_id, fs in feature_sets.items():
        fs_status = fs.get('status', 'pending')
        features = fs.get('features', [])

        if fs_status == 'completed':
            for f in features:
                if f.get('status') != 'completed':
                    warnings.append(
                        f"Feature Set '{fs_id}' is completed but feature '{f.get('id')}' is {f.get('status')}"
                    )

        elif fs_status == 'pending':
            for f in features:
                if f.get('status') in ['in_progress', 'completed']:
                    warnings.append(
                        f"Feature Set '{fs_id}' is pending but feature '{f.get('id')}' is {f.get('status')}"
                    )

    return warnings

action = os.environ.get('ACTION', 'check')
feature_map_path = os.environ.get('FEATURE_MAP', '.FDD/feature_map.yaml')

data = load_feature_map(feature_map_path)
feature_sets = extract_feature_sets(data)

if not feature_sets:
    print("[ValidateDeps] No feature sets found in feature map")
    sys.exit(0)

graph = build_dependency_graph(feature_sets)

if action == 'cycles':
    cycles = detect_cycles(graph)
    if cycles:
        print("[ValidateDeps] Circular dependencies detected:")
        for cycle in cycles:
            print(f"  ✗ {' → '.join(cycle)}")
        sys.exit(1)
    else:
        print("[ValidateDeps] No circular dependencies found")
        sys.exit(0)

elif action == 'order':
    order, success = topological_sort(graph)
    if success:
        print("[ValidateDeps] Execution order:")
        for i, fs_id in enumerate(order, 1):
            fs = feature_sets.get(fs_id, {})
            name = fs.get('name', 'Unknown')
            print(f"  {i}. {fs_id}: {name}")
    else:
        print("[ValidateDeps] Cannot generate execution order (circular dependencies exist)")
        sys.exit(1)

elif action == 'waves':
    waves = calculate_waves(graph, feature_sets)
    if waves:
        print("[ValidateDeps] Parallel execution waves:")
        for i, wave in enumerate(waves, 1):
            print(f"\n  Wave {i}:")
            for fs_id in wave:
                fs = feature_sets.get(fs_id, {})
                name = fs.get('name', 'Unknown')
                priority = fs.get('priority', 'medium')
                print(f"    - {fs_id}: {name} [{priority}]")

        remaining = set(graph.keys()) - set(fs_id for wave in waves for fs_id in wave)
        if remaining:
            print(f"\n  ⚠ Unreachable (blocked): {', '.join(remaining)}")
    else:
        print("[ValidateDeps] No executable feature sets")

else:  # check
    errors = []
    warnings = []

    print("═══════════════════════════════════════════════════")
    print("[ValidateDeps] Feature Map Dependency Validation")
    print("═══════════════════════════════════════════════════")
    print(f"File: {feature_map_path}")
    print(f"Feature Sets: {len(feature_sets)}")
    print()

    ref_errors = validate_references(feature_sets)
    errors.extend(ref_errors)

    cycles = detect_cycles(graph)
    for cycle in cycles:
        errors.append(f"Circular dependency: {' → '.join(cycle)}")

    status_warnings = check_status_consistency(feature_sets)
    warnings.extend(status_warnings)

    for fs_id, fs in feature_sets.items():
        feature_count = len(fs.get('features', []))
        if feature_count > 10:
            warnings.append(f"Feature Set '{fs_id}' has {feature_count} features (consider splitting)")
        elif feature_count < 2:
            warnings.append(f"Feature Set '{fs_id}' has only {feature_count} feature(s) (consider merging)")

    if warnings:
        print("⚠ Warnings:")
        for w in warnings:
            print(f"  - {w}")
        print()

    if errors:
        print("✗ Errors:")
        for e in errors:
            print(f"  - {e}")
        print()
        print("═══════════════════════════════════════════════════")
        print("VALIDATION FAILED")
        print("═══════════════════════════════════════════════════")
        sys.exit(1)
    else:
        print("✓ All dependency checks passed")
        print()

        waves = calculate_waves(graph, feature_sets)
        if waves:
            print("Execution preview:")
            for i, wave in enumerate(waves, 1):
                print(f"  Wave {i}: {', '.join(wave)}")

        print()
        print("═══════════════════════════════════════════════════")
        if warnings:
            print("VALIDATION PASSED (with warnings)")
        else:
            print("VALIDATION PASSED")
        print("═══════════════════════════════════════════════════")
PYTHON_SCRIPT
