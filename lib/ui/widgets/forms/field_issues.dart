/// The [ValidationIssue] path contract (ADR 05) that every form follows.
library;

import 'package:cocktails/domain/domain.dart';

/// The first issue's message, but none while the field is untouched (empty).
String? fieldError(String text, List<ValidationIssue> issues) =>
    text.isEmpty || issues.isEmpty ? null : issues.first.message;

/// The issues under [key]; null is the name, whose issues have no path.
List<ValidationIssue> issuesUnder(
  List<ValidationIssue> issues, [
  String? key,
]) => [
  for (final issue in issues)
    if (key == null
        ? issue.path.isEmpty
        : issue.path.isNotEmpty && issue.path.first == key)
      issue,
];

/// First issue per field wins, in reading order; unplaced issues are left out.
Map<K, String> firstIssuePerField<K extends Object>(
  List<ValidationIssue> issues,
  K? Function(ValidationIssue issue) fieldOf,
) {
  final problems = <K, String>{};
  for (final issue in issues) {
    final field = fieldOf(issue);
    if (field != null) problems.putIfAbsent(field, () => issue.message);
  }
  return problems;
}
