/// Shelf edits as pure derivations; kept separate so shelf.dart holds shape
/// only. An edit naming no bar returns the shelf unchanged, as a collection
/// edit naming no entry does; writing the wrong kind of bar throws.
library;

import 'collection.dart';
import 'list_edits.dart';
import 'shelf.dart';

extension ShelfEdits on Shelf {
  /// The open bar's collection, replaced and the record restamped [at]. Every
  /// collection edit ends here, so a guest bar is refused once
  /// ([ADR 23](../../../docs/adr/23-nothing-writes-a-guest-bar.md)).
  Shelf withCollection(Collection collection, DateTime at) {
    final bar = open;
    if (bar == null) {
      throw ArgumentError('No bar is open to write to');
    }
    if (!bar.isOwned) {
      throw ArgumentError('A guest bar is read-only: "${bar.name}"');
    }
    return withBar(
      bar.summarised(collection, at: at),
    ).copyWith(collection: collection);
  }

  /// Adds [bar], or replaces the record standing under its id.
  Shelf withBar(Bar bar) =>
      copyWith(bars: upserted(bars, bar, [(b) => b.id == bar.id]));

  /// FR-BAR-2: closing is [Shelf]'s own default state, so this names no field.
  Shelf withoutBar(String id) {
    final remaining = without(bars, (bar) => bar.id == id);
    if (remaining.length == bars.length) return this;
    return openId == id ? Shelf(bars: remaining) : copyWith(bars: remaining);
  }

  /// The switch: the record and the bytes at once (ADR-20).
  Shelf opening(String id, Collection collection) =>
      copyWith(openId: id, collection: collection);

  /// FR-BAR-5: the owner's collection replaced, stamped [at]. Never [Bar.name]
  /// or [Bar.display], the reader's picks (ADR-21).
  Shelf refreshedWith(String id, BarPayload payload, DateTime at) {
    final bar = barWithId(id);
    if (bar == null) return this;
    if (bar.isOwned) {
      throw ArgumentError('An owned bar refreshes from nothing: "${bar.name}"');
    }
    final shelf = withBar(bar.refreshedAt(payload.collection, at));
    return id == openId
        ? shelf.copyWith(collection: payload.collection)
        : shelf;
  }
}
