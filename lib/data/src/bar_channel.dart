library;

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

abstract interface class BarChannel {
  Transport get transport;

  /// Null is nothing asked (a picker dismissed), not [Unreachable].
  Future<Outcome<BarContent>?> fetch(BarSource source);
}

/// Answers as each device is found, and closes when the search ends (ADR 22).
abstract interface class BarFinder {
  Transport get transport;

  Stream<List<Found>> nearby();
}

/// The sharing half, which only some transports have (FR-BAR-6).
abstract interface class BarOfferings {
  Transport get transport;

  /// Offering a bar again renames it.
  Future<void> offer(String barId, String name);

  Future<void> withdraw(String barId);
}
