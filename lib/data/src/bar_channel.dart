/// The sharing seam (ADR 22): each transport gets only the methods it has.
library;

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

abstract interface class BarChannel {
  Transport get transport;

  /// Every refresh; null is nothing asked (a picker dismissed), not [Unreachable].
  Future<Outcome<BarContent>?> fetch(BarSource source);
}

/// The guest's half of finding, which only the LAN has: a file arrives by hand
/// and the cloud is asked by name. Asked while a reader looks, never left
/// running (ADR 22).
abstract interface class BarFinder {
  Transport get transport;

  Future<List<Found>> nearby();
}

/// The owner's half, which only some transports have (FR-BAR-6): a file is
/// handed over rather than offered, so there is nothing to withdraw after it.
abstract interface class BarOfferings {
  Transport get transport;

  /// Offering a bar already offered is how it is renamed, the way it is
  /// reached staying as it was.
  Future<void> offer(String barId, String name);

  /// Stops the offer and nothing else: a guest keeps what it holds, and its
  /// next refresh is what tells it the source is gone.
  Future<void> withdraw(String barId);
}
