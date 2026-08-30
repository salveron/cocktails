/// Work in flight on the owner's side: an offer outlives the gesture that made
/// it, and the screens are told what it is doing only through here
/// (docs/components.md#work-in-flight).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a bar's sharing is doing, or what its last change came to (FR-BAR-6).
sealed class SharingState {
  const SharingState();
}

/// An offer is going up.
final class Announcing extends SharingState {
  const Announcing();
}

/// A withdrawal is going down.
final class Silencing extends SharingState {
  const Silencing();
}

/// The offer stands and nothing announces it: the intent rides on the record,
/// so a failure is reported rather than quietly un-offering the bar (ADR 22).
final class SharingFailed extends SharingState {
  final String message;
  final DateTime at;

  const SharingFailed(this.message, this.at);

  @override
  String toString() => 'SharingFailed($message)';
}

/// By bar id, holding only bars with a change out or a last one that failed.
final sharingProvider = NotifierProvider<Sharing, Map<String, SharingState>>(
  Sharing.new,
);

final class Sharing extends Notifier<Map<String, SharingState>> {
  @override
  Map<String, SharingState> build() => const {};

  /// For a caller holding the notifier across an `await` of its own.
  SharingState? standing(String id) => state[id];

  void announcing(String id) => _setStanding(id, const Announcing());

  void silencing(String id) => _setStanding(id, const Silencing());

  /// What the change came to — [failure], or nothing where it landed.
  void settled(String id, [SharingState? failure]) => _setStanding(id, failure);

  /// The reader has heard it.
  void told(String id) => _setStanding(id, null);

  void _setStanding(String id, SharingState? standing) {
    if (standing == null && !state.containsKey(id)) return;
    final next = {...state}..remove(id);
    if (standing != null) next[id] = standing;
    state = Map.unmodifiable(next);
  }
}
