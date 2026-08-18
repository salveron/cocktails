/// The sharing seam (ADR 22): each transport gets only the methods it has.
library;

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

abstract interface class BarChannel {
  Transport get transport;

  /// Every refresh; null is nothing asked (a picker dismissed), not [Unreachable].
  Future<Outcome<BarPayload>?> fetch(BarSource source);
}
