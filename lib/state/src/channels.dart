/// Work in flight: a refresh outlives the gesture that started it, and the
/// screens are told what it is doing only through here (components.md).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seams.dart';

/// The ways a bar travels, by transport — composed from the seams beside it
/// and replaced wholesale by fakes, so nothing above learns what a network is.
/// A transport absent here has no adapter in this build, which is how
/// `Transport.cloud` waits without blocking anything (ADR 22).
final channelsProvider = Provider<Map<Transport, BarChannel>>(
  (ref) => Map.unmodifiable({
    Transport.file: FileBarChannel(ref.watch(filePickerProvider)),
  }),
);

/// What a bar's refresh is doing, or what its last one came to (FR-BAR-5).
sealed class RefreshState {
  const RefreshState();
}

/// A fetch is out. No screen awaits one (NFR-2).
final class Reaching extends RefreshState {
  const Reaching();
}

/// Judged as an import is, and described as the startup banner describes one:
/// `ui/` never meets a [SourcedIssue] (FR-DAT-4).
final class RefreshRefused extends RefreshState {
  final List<String> issues;
  final DateTime at;

  RefreshRefused(List<String> issues, this.at)
    : issues = List.unmodifiable(issues);

  @override
  String toString() => 'RefreshRefused(${issues.length} issues)';
}

final class RefreshUnreachable extends RefreshState {
  final UnreachableReason why;
  final DateTime at;

  const RefreshUnreachable(this.why, this.at);

  @override
  String toString() => 'RefreshUnreachable(${why.name})';
}

/// By bar id, holding only bars a refresh is out for or last failed on.
final refreshesProvider =
    NotifierProvider<Refreshes, Map<String, RefreshState>>(Refreshes.new);

final class Refreshes extends Notifier<Map<String, RefreshState>> {
  /// The newest ask per bar, so a late answer is dropped whole rather than
  /// landing behind a newer one. Off the state: a screen rebuilding because a
  /// token was minted would be a rebuild for nothing.
  final _tokens = <String, int>{};

  @override
  Map<String, RefreshState> build() => const {};

  /// Marks [id] reaching, clearing what its last ask came to, and answers the
  /// token this one is known by.
  int ask(String id) {
    final token = (_tokens[id] ?? 0) + 1;
    _tokens[id] = token;
    _stand(id, const Reaching());
    return token;
  }

  /// What the ask known by [token] came to — [failure], or nothing where it
  /// landed or the reader stood down. Answers whether it counted at all.
  bool settled(String id, int token, [RefreshState? failure]) {
    if (_tokens[id] != token) return false;
    _tokens.remove(id);
    _stand(id, failure);
    return true;
  }

  void _stand(String id, RefreshState? standing) {
    final next = {...state}..remove(id);
    if (standing != null) next[id] = standing;
    state = Map.unmodifiable(next);
  }
}
