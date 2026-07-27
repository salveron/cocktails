/// A validation issue bound to its place in the store file. Its own module
/// because both the codec's Rejected and the store's Corrupt carry it
/// (docs/components.md#data-contracts).
library;

import 'package:cocktails/domain/domain.dart';

final class SourcedIssue {
  final ValidationIssue issue;

  /// 1-based line in the YAML source, null when unresolvable.
  final int? line;

  SourcedIssue(this.issue, this.line);

  @override
  bool operator ==(Object other) =>
      other is SourcedIssue && other.issue == issue && other.line == line;

  @override
  int get hashCode => Object.hash(issue, line);

  @override
  String toString() => line == null ? '$issue' : 'line $line: $issue';
}
