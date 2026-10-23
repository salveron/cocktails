/// Shelf validation: the index's own record, never a bar's contents (ADR-21).
library;

import '../issues.dart';
import '../shopping/shopping_settings.dart';
import 'bar.dart';
import 'shelf.dart';

/// Checks the parts of a would-be [Shelf] against the rules its constructor
/// keeps, reported rather than thrown. Paths follow the index's keys, `device`
/// and `open` before `bars` as the file writes them.
List<ValidationIssue> validateShelf({
  required List<Bar> bars,
  String? openId,
  String? deviceName,
}) {
  final structural = shelfProblems(bars: bars, openId: openId);
  final issues = <ValidationIssue>[
    ...deviceNameProblems(deviceName),
    for (final problem in structural)
      if (problem.path.first == 'open') _issueOf(const [], problem),
  ];
  for (var i = 0; i < bars.length; i++) {
    _checkBar(issues, bars[i], i, [
      for (final problem in structural)
        if (problem.path.first == 'bars' && problem.path[1] == i)
          _issueOf(const [], problem),
    ]);
  }
  return issues;
}

/// A bar's name before it goes on the shelf, for a form to show (FR-BAR-1): the
/// rules every name keeps, and for an [owned] bar's, no other owned bar's name.
/// [except] is the bar being renamed or replaced, so it never collides with
/// itself; a guest's name is a label on this device and collides with nothing.
List<ValidationIssue> validateBarName(
  String name, {
  required Iterable<Bar> bars,
  required bool owned,
  String? except,
}) => checkName(
  'bar',
  name,
  isDuplicate: owned && ownedNameTaken(bars, name, except: except),
);

/// One bar's id when empty, the [repeats] [shelfProblems] found at it, its
/// name, and the half of its record its mode allows it.
void _checkBar(
  List<ValidationIssue> issues,
  Bar bar,
  int index,
  List<ValidationIssue> repeats,
) {
  if (bar.id.isEmpty) {
    issues.add(
      ValidationIssue(
        ['bars', index, 'id'],
        ValidationIssueKind.emptyName,
        'Empty bar id',
      ),
    );
  }
  issues.addAll(repeats);
  issues.addAll(
    checkName(
      'bar',
      bar.name,
      isDuplicate: false,
      basePath: ['bars', index, 'name'],
    ),
  );
  issues.addAll(_checkRecord(bar, ['bars', index]));
}

ValidationIssue _issueOf(
  List<Object> basePath,
  ({List<Object> path, String message, bool duplicate}) problem,
) => ValidationIssue(
  [...basePath, ...problem.path],
  problem.duplicate
      ? ValidationIssueKind.duplicateName
      : ValidationIssueKind.malformedValue,
  problem.message,
);

/// The half of a record its mode allows it (FR-BAR-3/6, [coherenceProblems]),
/// plus the one rule that is validation's alone: an owner's budget and basket
/// count are each picked from a fixed few on their screen (FR-SET-2), so a
/// stored value outside them would leave that screen with nothing selected.
List<ValidationIssue> _checkRecord(Bar bar, List<Object> basePath) {
  final issues = [
    for (final problem in coherenceProblems(bar)) _issueOf(basePath, problem),
  ];
  final shopping = bar.shopping;
  if (bar.isOwned && shopping != null) {
    addProblems(
      issues,
      [...basePath, 'shopping'],
      [
        budgets.contains(shopping.budget)
            ? null
            : (
                kind: ValidationIssueKind.malformedValue,
                message:
                    'Budget must be one of ${budgets.join(', ')}: "${bar.name}"',
              ),
        basketCounts.contains(shopping.keptPerSize)
            ? null
            : (
                kind: ValidationIssueKind.malformedValue,
                message:
                    'Baskets must be one of ${basketCounts.join(', ')}: '
                    '"${bar.name}"',
              ),
      ],
    );
  }
  return issues;
}
