/// Shelf edits as pure derivations; kept separate so shelf.dart holds shape
/// only. An edit naming no bar returns the shelf unchanged, as a collection
/// edit naming no entry does; writing the wrong kind of bar throws.
library;

import '../collection/collection.dart';
import '../list_edits.dart';
import 'bar.dart';
import 'sharing.dart';
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

  /// FR-BAR-8: what this device announces itself as, the reader's to choose
  /// (ADR 28) and judged by [Shelf] under the rules every name keeps.
  Shelf namingDevice(String name) =>
      name == deviceName ? this : copyWith(deviceName: name);

  /// FR-BAR-6: [id] offered by [via], every other way left standing. Offering
  /// one already offered changes nothing: one offer per transport is coherence.
  Shelf offering(String id, Transport via) {
    final bar = _sharable(id);
    if (bar == null || bar.offers.any((offer) => offer.via == via)) return this;
    return withBar(
      bar.copyWith(offers: [...bar.offers, (via: via, guests: const [])]),
    );
  }

  /// FR-BAR-6: the offer by [via] dropped and nothing else — every other way
  /// stays open, and what a guest already holds stays theirs.
  Shelf withdrawing(String id, Transport via) {
    final bar = _sharable(id);
    if (bar == null) return this;
    final left = without(bar.offers, (offer) => offer.via == via);
    if (left.length == bar.offers.length) return this;
    return withBar(bar.copyWith(offers: left));
  }

  /// The bar [id] names, or null where none does. A guest bar is its owner's
  /// to share, so asking here is the mistake a throw names (ADR 23).
  Bar? _sharable(String id) {
    final bar = barWithId(id);
    if (bar != null && !bar.isOwned) {
      throw ArgumentError('A guest bar is shared by its owner: "${bar.name}"');
    }
    return bar;
  }

  /// FR-BAR-5: the owner's collection replaced, stamped [at]. Never [Bar.name]
  /// or [Bar.display], the reader's picks (ADR-21).
  Shelf refreshedWith(String id, BarContent payload, DateTime at) {
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
