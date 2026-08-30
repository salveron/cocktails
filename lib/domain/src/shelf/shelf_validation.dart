/// Shelf validation: the index's own record, never a bar's contents (ADR-21).
library;

import '../issues.dart';
import '../shopping/shopping_settings.dart';
import 'bar.dart';
import 'shelf.dart';

/// Checks the parts of a would-be [Shelf] against the rules its constructor
/// keeps, reported rather than thrown. Names go unchecked for uniqueness: two
/// bars may carry one (FR-BAR-1). Paths follow the index's keys, `device` and
/// `open` before `bars` as the file writes them.
List<ValidationIssue> validateShelf({
  required List<Bar> bars,
  String? openId,
  String? deviceName,
}) {
  final structural = shelfProblems(bars: bars, openId: openId);
  final issues = <ValidationIssue>[
    ...deviceNameProblems(deviceName),
    for (final problem in structural)
      if (problem.path.first == 'open')
        ValidationIssue(
          problem.path,
          ValidationIssueKind.malformedValue,
          problem.message,
        ),
  ];
  final duplicateIds = {
    for (final problem in structural)
      if (problem.path.first == 'bars') problem.path[1] as int: problem.message,
  };
  for (var i = 0; i < bars.length; i++) {
    _checkBar(issues, bars[i], i, duplicateIds[i]);
  }
  return issues;
}

/// One bar's id (empty, and duplicate among ids minted rather than written —
/// [shelfProblems] already found which), its name, and the half of its
/// record its mode allows it.
void _checkBar(
  List<ValidationIssue> issues,
  Bar bar,
  int index,
  String? duplicateIdMessage,
) {
  addProblems(
    issues,
    ['bars', index, 'id'],
    [
      bar.id.isEmpty
          ? (kind: ValidationIssueKind.emptyName, message: 'Empty bar id')
          : null,
      duplicateIdMessage == null
          ? null
          : (
              kind: ValidationIssueKind.duplicateName,
              message: duplicateIdMessage,
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
/// plus the one rule that is validation's alone: an owner's budget and basket
/// count are each picked from a fixed few on their screen (FR-SET-2), so a
/// stored value outside them would leave that screen with nothing selected.
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
