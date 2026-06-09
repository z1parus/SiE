import '../models/planning.dart';

/// Returns set of SubGoal IDs that are visible under Fog of War rules.
///
/// Rules:
/// 1. Level-1 (direct children of Goal) always visible.
/// 2. If SubGoal N is completed → SubGoal N+1 (by order in list) becomes visible.
/// 3. If a SubGoal has ≥1 completed task → its direct children become visible (recursive).
/// 4. IDs in [scoutedIds] are always visible (manually revealed by user).
///
/// When [fogEnabled] is false, returns IDs of every sub-goal in the tree.
Set<String> computeFogVisibleIds(
  List<SubGoal> topLevel,
  Set<String> scoutedIds,
  bool fogEnabled,
) {
  if (!fogEnabled) {
    return _allIds(topLevel);
  }

  final visible = <String>{};

  // Rule 1: Level-1 always visible
  for (final sg in topLevel) {
    visible.add(sg.id);
  }

  // Rule 3 (level-1): if level-1 sub-goal has ≥1 completed task, its children visible
  for (final sg in topLevel) {
    if (sg.tasks.any((t) => t.isCompleted)) {
      for (final child in sg.children) {
        visible.add(child.id);
      }
    }
  }

  // Rule 2: sub-goal N completed → sub-goal N+1 visible (level-1 siblings)
  for (int i = 0; i < topLevel.length - 1; i++) {
    if (topLevel[i].isCompleted) {
      visible.add(topLevel[i + 1].id);
    }
  }

  // Recurse down the tree applying rules 2 & 3 for all visible nodes
  for (final sg in topLevel) {
    if (visible.contains(sg.id)) {
      _expandVisibleChildren(sg, visible);
    }
  }

  visible.addAll(scoutedIds);
  return visible;
}

void _expandVisibleChildren(SubGoal parent, Set<String> visible) {
  // Rule 2: child N completed → child N+1 visible
  for (int i = 0; i < parent.children.length - 1; i++) {
    if (parent.children[i].isCompleted) {
      visible.add(parent.children[i + 1].id);
    }
  }

  // Rule 3: if this parent has ≥1 completed task, its direct children visible
  if (parent.tasks.any((t) => t.isCompleted)) {
    for (final child in parent.children) {
      visible.add(child.id);
    }
  }

  // Recurse into visible children
  for (final child in parent.children) {
    if (visible.contains(child.id)) {
      _expandVisibleChildren(child, visible);
    }
  }
}

Set<String> _allIds(List<SubGoal> sgs) {
  final result = <String>{};
  void visit(SubGoal sg) {
    result.add(sg.id);
    for (final child in sg.children) visit(child);
  }
  for (final sg in sgs) visit(sg);
  return result;
}
