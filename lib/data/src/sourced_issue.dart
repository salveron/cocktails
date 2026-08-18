/// A validation issue bound to its place in the store file, and [Outcome]:
/// the one shape a load, a decode and a fetch each answer with
/// (docs/components.md#data-contracts).
library;

import 'package:cocktails/domain/domain.dart';

final class SourcedIssue {
  final ValidationIssue issue;

  /// 1-based line in the YAML source, null when unresolvable.
  final int? line;

  SourcedIssue(this.issue, this.line);

  /// As a report reads it: no data-format path, unlike [toString] (FR-DAT-4).
  String get description => _placed(issue.message);

  String _placed(String text) => line == null ? text : 'line $line: $text';

  @override
  bool operator ==(Object other) =>
      other is SourcedIssue && other.issue == issue && other.line == line;

  @override
  int get hashCode => Object.hash(issue, line);

  @override
  String toString() => _placed('$issue');
}

/// What a load, a decode or a fetch comes to: one shape, three readings. A
/// load reaches every case; a decode only [Ok]/[Rejected]; a fetch every case
/// but [Empty].
sealed class Outcome<T> {
  const Outcome();
}

final class Ok<T> extends Outcome<T> {
  final T value;

  const Ok(this.value);
}

/// Nothing stored yet (a load only) — a first run, or a file never landed.
final class Empty<T> extends Outcome<T> {
  const Empty();
}

/// Reached, or read, but rejected (FR-DAT-4). [recovered] is a load's newest
/// backup that decoded; a decode or a fetch keeps none, and leaves it null.
final class Rejected<T> extends Outcome<T> {
  final List<SourcedIssue> issues;
  final T? recovered;

  Rejected(List<SourcedIssue> issues, {this.recovered})
    : issues = List.unmodifiable(issues);
}

/// Never reached at all (a fetch only) — no source answered, so there is
/// nothing to judge.
final class Unreachable<T> extends Outcome<T> {
  final UnreachableReason why;

  const Unreachable(this.why);
}
