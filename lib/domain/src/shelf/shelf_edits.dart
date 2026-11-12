/// Shelf edits as pure derivations, so shelf.dart holds shape only.
library;

import '../collection/collection.dart';
import '../list_edits.dart';
import 'bar.dart';
import 'sharing.dart';
import 'shelf.dart';

extension ShelfEdits on Shelf {
  /// Every collection edit ends here, refusing a guest bar once
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

  Shelf withBar(Bar bar) =>
      copyWith(bars: upserted(bars, bar, [(b) => b.id == bar.id]));

  /// FR-BAR-2: closing is Shelf's own default state, so no field is named.
  Shelf withoutBar(String id) {
    final remaining = without(bars, (bar) => bar.id == id);
    if (remaining.length == bars.length) return this;
    return openId == id ? Shelf(bars: remaining) : copyWith(bars: remaining);
  }

  /// The record and the bytes change together (ADR-20).
  Shelf opening(String id, Collection collection) =>
      copyWith(openId: id, collection: collection);

  /// FR-BAR-8: the reader chooses this device's announced name (ADR 28).
  Shelf namingDevice(String name) =>
      name == deviceName ? this : copyWith(deviceName: name);

  /// FR-BAR-6: one offer per transport, so offering twice changes nothing.
  Shelf offering(String id, Transport via) {
    final bar = barWithId(id);
    if (bar == null || bar.offeredBy(via)) return this;
    return withBar(
      bar.copyWith(offers: [...bar.offers, (via: via, guests: const [])]),
    );
  }

  /// FR-BAR-6: drops only this offer; guests keep what they already hold.
  Shelf withdrawing(String id, Transport via) {
    final bar = barWithId(id);
    if (bar == null) return this;
    final left = without(bar.offers, (offer) => offer.via == via);
    if (left.length == bar.offers.length) return this;
    return withBar(bar.copyWith(offers: left));
  }

  /// FR-BAR-5: a refresh spares the reader's name and display (ADR-21).
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
