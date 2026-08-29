/// The shelf: every bar the device holds, which one is open, and that one's
/// collection — the open bar's is the only one resident, which is what makes
/// "nothing crosses" (FR-BAR-1) a fact rather than a rule
/// ([ADR 20](../../../../docs/adr/20-the-app-holds-many-bars.md)).
library;

import '../collection/collection.dart';
import '../names.dart';
import 'bar.dart';

/// Every bar the device holds, which one is open, and that one's collection.
final class Shelf {
  final List<Bar> bars;

  /// The bar on show; null on a first run and once the last bar is deleted.
  final String? openId;

  /// The open bar's, and an empty collection while none is open — a state no
  /// screen can read, the shell offering no destination without a bar.
  final Collection collection;

  Shelf({List<Bar> bars = const [], this.openId, Collection? collection})
    : bars = List.unmodifiable(bars),
      collection = collection ?? Collection() {
    final problems = shelfProblems(bars: this.bars, openId: openId);
    if (problems.isNotEmpty) {
      throw ArgumentError(problems.first.message);
    }
    for (final bar in this.bars) {
      final coherence = coherenceProblems(bar);
      if (coherence.isNotEmpty) {
        throw ArgumentError(coherence.first.message);
      }
    }
  }

  Bar? get open {
    final id = openId;
    return id == null ? null : barWithId(id);
  }

  Bar? barWithId(String id) => _barsById[id];

  /// What a copy may change, and nothing else: null means "keep". Closing the
  /// shelf — [openId] cleared, [collection] reset — is [Shelf]'s own default
  /// state rather than a copy's to reach; `withoutBar` builds that directly.
  Shelf copyWith({List<Bar>? bars, String? openId, Collection? collection}) =>
      Shelf(
        bars: bars ?? this.bars,
        openId: openId ?? this.openId,
        collection: collection ?? this.collection,
      );

  late final Map<String, Bar> _barsById = {for (final bar in bars) bar.id: bar};

  @override
  bool operator ==(Object other) =>
      other is Shelf &&
      listEquals(other.bars, bars) &&
      other.openId == openId &&
      other.collection == collection;

  @override
  int get hashCode => Object.hash(Object.hashAll(bars), openId, collection);

  @override
  String toString() => 'Shelf(${bars.length} bars, open: $openId)';
}

/// The shelf's own coherence, beyond any one bar's ([coherenceProblems]): no
/// two bars share an id — compared exactly, ADR-08's fold being a rule for
/// names, not ids — and the open bar, if any, is one of them. The [Shelf]
/// constructor throws the first; shelf_validation.dart's `validateShelf`
/// reports every one, so the rule and its wording live once for both.
List<({List<Object> path, String message, bool duplicate})> shelfProblems({
  required List<Bar> bars,
  String? openId,
}) {
  final problems = <({List<Object> path, String message, bool duplicate})>[];
  final seen = <String>{};
  for (var i = 0; i < bars.length; i++) {
    if (!seen.add(bars[i].id)) {
      problems.add((
        path: ['bars', i, 'id'],
        message: 'Duplicate bar id: "${bars[i].id}"',
        duplicate: true,
      ));
    }
  }
  if (openId != null && !seen.contains(openId)) {
    problems.add((
      path: const ['open'],
      message: 'Open bar is not on the shelf: "$openId"',
      duplicate: false,
    ));
  }
  return problems;
}
