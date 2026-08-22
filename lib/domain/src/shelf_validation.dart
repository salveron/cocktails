/// Shelf validation: the index's own record, never a bar's contents (ADR-21).
library;

import 'optimizer.dart';
import 'shelf.dart';
import 'validation.dart';

/// Checks the parts of a would-be [Shelf] against the rules its constructor
/// keeps, reported rather than thrown. Names go unchecked for uniqueness: two
/// bars may carry one (FR-BAR-1). Paths follow the index's keys, `open`
/// before `bars` as the file writes them.
List<ValidationIssue> validateShelf({required List<Bar> bars, String? openId}) {
  final issues = <ValidationIssue>[];
  final ids = {for (final bar in bars) bar.id};
  if (openId != null && !ids.contains(openId)) {
    issues.add(
      ValidationIssue(
        const ['open'],
        ValidationIssueKind.malformedValue,
        'open names no bar on the shelf: "$openId"',
      ),
    );
  }
  final seen = <String>{};
  for (var i = 0; i < bars.length; i++) {
    _checkBar(issues, bars[i], i, seen);
  }
  return issues;
}

/// One bar's id (empty, and duplicate among ids minted rather than written —
/// compared exactly, ADR-08's fold being a rule for names, not ids), its name,
/// and the half of its record its mode allows it.
void _checkBar(
  List<ValidationIssue> issues,
  Bar bar,
  int index,
  Set<String> seenIds,
) {
  addProblems(
    issues,
    ['bars', index, 'id'],
    [
      bar.id.isEmpty
          ? (kind: ValidationIssueKind.emptyName, message: 'Empty bar id')
          : null,
      seenIds.add(bar.id)
          ? null
          : (
              kind: ValidationIssueKind.duplicateName,
              message: 'Duplicate bar id: "${bar.id}"',
            ),
    ],
  );
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

/// The half of a record its mode allows it (FR-BAR-3/6, [coherenceProblems]),
/// plus the one rule that is validation's alone: budget and basket count are
/// each picked from a fixed few on their screen (FR-SET-2), so a stored value
/// outside them would leave that screen with nothing selected.
List<ValidationIssue> _checkRecord(Bar bar, List<Object> basePath) {
  final issues = [
    for (final problem in coherenceProblems(bar))
      ValidationIssue(
        [...basePath, ...problem.path],
        problem.duplicate
            ? ValidationIssueKind.duplicateName
            : ValidationIssueKind.malformedValue,
        problem.message,
      ),
  ];
  addProblems(
    issues,
    [...basePath, 'shopping'],
    [
      budgets.contains(bar.shopping.budget)
          ? null
          : (
              kind: ValidationIssueKind.malformedValue,
              message:
                  'Budget must be one of ${budgets.join(', ')}: "${bar.name}"',
            ),
      basketCounts.contains(bar.shopping.keptPerSize)
          ? null
          : (
              kind: ValidationIssueKind.malformedValue,
              message:
                  'Baskets must be one of ${basketCounts.join(', ')}: '
                  '"${bar.name}"',
            ),
    ],
  );
  return issues;
}
