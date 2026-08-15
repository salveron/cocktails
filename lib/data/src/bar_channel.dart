/// The sharing seam: how a bar reaches this device, whatever way it travelled
/// (ADR 22). A fetch answers and never throws; offering and finding land with
/// the transports that have them, so the file channel is one method wide.
library;

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

sealed class FetchOutcome {}

final class Fetched extends FetchOutcome {
  final BarPayload payload;

  Fetched(this.payload);
}

/// Reached, and what came back failed the import's own judgement (FR-DAT-4).
final class Refused extends FetchOutcome {
  final List<SourcedIssue> issues;

  Refused(List<SourcedIssue> issues) : issues = List.unmodifiable(issues);
}

final class Unreachable extends FetchOutcome {
  final UnreachableReason why;

  Unreachable(this.why);
}

abstract interface class BarChannel {
  Transport get transport;

  /// The add, and every refresh after. Null where no fetch happened at all —
  /// the file transport's reader dismissing the picker, and nothing else: a
  /// source asked and silent is [Unreachable].
  Future<FetchOutcome?> fetch(BarSource source);
}
