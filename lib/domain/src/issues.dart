/// One violation becomes an issue: the shape collection_validation.dart and
/// shelf_validation.dart both report through (FR-DAT-4). Paths mirror
/// data-format keys for YAML/form mapping.
library;

import 'names.dart';

/// Issue rules; switch on this instead of the message.
enum ValidationIssueKind {
  emptyName,
  whitespaceInName,
  lineBreakInName,
  commaInAlias,
  duplicateName,
  reservedSuffix,
  separatorInName,
  unitSizeNotPositive,
  missingUnit,
  unknownUnit,
  unknownIngredient,
  unknownTag,
  duplicateTag,
  duplicateAlternative,
  amountNotPositive,
  rangeOutOfOrder,
  noRequiredLine,
  unsupportedFormat,
  malformedLine,
  malformedValue,
}

/// One violation: path, rule, and offending value.
final class ValidationIssue {
  final List<Object> path;
  final ValidationIssueKind kind;
  final String message;

  ValidationIssue(List<Object> path, this.kind, this.message)
    : path = List.unmodifiable(path);

  /// [path] as dotted-indexed form, e.g. `recipes[0].lines[2]`.
  String get location {
    final buffer = StringBuffer();
    for (final segment in path) {
      if (segment is int) {
        buffer.write('[$segment]');
      } else {
        if (buffer.isNotEmpty) {
          buffer.write('.');
        }
        buffer.write(segment);
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is ValidationIssue &&
      listEquals(other.path, path) &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(Object.hashAll(path), kind, message);

  @override
  String toString() => '$location: $message';
}

/// A violation before it gains a path.
typedef Problem = ({ValidationIssueKind kind, String message});

/// Single home of name rules, whether from list or form.
List<ValidationIssue> checkName(
  String entity,
  String name, {
  required bool isDuplicate,
  Problem? Function(String name)? extraRule,
  List<Object> basePath = const [],
}) {
  final issues = <ValidationIssue>[];
  addProblems(issues, basePath, [
    _nameProblem(entity, name),
    isDuplicate ? _duplicateProblem(entity, name) : null,
    extraRule?.call(name),
  ]);
  return issues;
}

Problem _duplicateProblem(String entity, String name) => (
  kind: ValidationIssueKind.duplicateName,
  message: duplicateNameMessage(entity, name),
);

/// All non-null problems as issues sharing one [path].
void addProblems(
  List<ValidationIssue> issues,
  List<Object> path,
  List<Problem?> problems,
) {
  for (final problem in problems) {
    if (problem != null) {
      issues.add(ValidationIssue(path, problem.kind, problem.message));
    }
  }
}

Problem? _nameProblem(String entity, String name) {
  if (name.isEmpty) {
    return (kind: ValidationIssueKind.emptyName, message: 'Empty $entity name');
  }
  if (name.trim() != name) {
    return (
      kind: ValidationIssueKind.whitespaceInName,
      message: 'Surrounding whitespace in $entity name: "$name"',
    );
  }
  if (name.contains('\n') || name.contains('\r')) {
    return (
      kind: ValidationIssueKind.lineBreakInName,
      message: 'Line break in $entity name: "$name"',
    );
  }
  return null;
}
