/// Shelf edits as pure derivations; kept separate so shelf.dart holds shape
/// only. An edit naming no bar returns the shelf unchanged, as a collection
/// edit naming no entry does; writing the wrong kind of bar throws.
library;

import 'collection.dart';
import 'shelf.dart';

extension ShelfEdits on Shelf {
  /// The open bar's collection, replaced. Every collection edit ends here, so
  /// a guest bar — whose contents are its owner's — is refused once
  /// ([ADR 23](../../../docs/adr/23-nothing-writes-a-guest-bar.md)).
  Shelf withCollection(Collection collection) {
    final bar = open;
    if (bar == null) {
      throw ArgumentError('No bar is open to write to');
    }
    if (!bar.isOwned) {
      throw ArgumentError('A guest bar is read-only: "${bar.name}"');
    }
    return Shelf(bars: bars, openId: openId, collection: collection);
  }

  /// Adds [bar], or replaces the record standing under its id: a rename, an
  /// offer taken up or withdrawn, a source moved.
  Shelf withBar(Bar bar) {
    final index = bars.indexWhere((entry) => entry.id == bar.id);
    return Shelf(
      bars: index < 0 ? [...bars, bar] : ([...bars]..[index] = bar),
      openId: openId,
      collection: collection,
    );
  }

  /// FR-BAR-2. Deleting the open bar leaves none open and nothing resident.
  Shelf withoutBar(String id) {
    final remaining = [
      for (final bar in bars)
        if (bar.id != id) bar,
    ];
    if (remaining.length == bars.length) return this;
    final keptOpen = openId != id;
    return Shelf(
      bars: remaining,
      openId: keptOpen ? openId : null,
      collection: keptOpen ? collection : Collection(),
    );
  }

  /// The switch: the record and the bytes at once (ADR-20). An [id] naming no
  /// bar throws through Shelf's own constructor, where that rule lives.
  Shelf opening(String id, Collection collection) =>
      Shelf(bars: bars, openId: id, collection: collection);

  /// FR-BAR-5: the owner's name and collection replaced, stamped [at]. Never
  /// [Bar.display], which is the reader's pick (ADR-21). The collection moves
  /// only for the open bar; refreshing another is a record edit here and a
  /// file write in the store.
  Shelf refreshedWith(String id, BarPayload payload, DateTime at) {
    final bar = barWithId(id);
    if (bar == null) return this;
    if (bar.isOwned) {
      throw ArgumentError('An owned bar refreshes from nothing: "${bar.name}"');
    }
    final shelf = withBar(bar.refreshedAt(payload.name, at));
    return id == openId
        ? Shelf(
            bars: shelf.bars,
            openId: openId,
            collection: payload.collection,
          )
        : shelf;
  }
}
