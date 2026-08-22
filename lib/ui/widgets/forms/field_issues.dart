/// The one reading of the [ValidationIssue] path contract (ADR 05) every form
/// puts under a field.
library;

import 'package:cocktails/domain/domain.dart';

/// Show first issue or nothing if empty (untouched field not an error).
String? fieldError(String text, List<ValidationIssue> issues) =>
    text.isEmpty || issues.isEmpty ? null : issues.first.message;

/// The issues one field owns: [key] is the entry key leading to it, left out
/// for the name, whose issues carry no path at all.
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

/// The message each field shows, keyed as [fieldOf] names it: the first issue
/// naming a field wins, since the rules are reported in the order they are
/// meant to be read. An issue [fieldOf] places nowhere is left out — its
/// caller has its own way of reporting one.
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
