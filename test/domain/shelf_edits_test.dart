import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shelf_test.dart' show aSource, anHourAgo, guestBar, ownedBar;

final _gin = Collection(ingredients: [Ingredient('gin')]);
final _rum = Collection(ingredients: [Ingredient('rum')]);

/// A shelf of one owned and one guest bar, [openId] naming which is on show.
Shelf shelfOf({String? openId, Collection? collection}) => Shelf(
  bars: [
    ownedBar(),
    guestBar(refreshed: anHourAgo),
  ],
  openId: openId,
  collection: collection,
);

final _at = DateTime.utc(2026, 5, 4, 9);

void main() {
  group('withCollection', () {
    test('replaces the open owned bar\'s collection', () {
      final shelf = shelfOf(openId: '5f2c9a').withCollection(_gin, _at);
      expect(shelf.collection, _gin);
      expect(shelf.openId, '5f2c9a');
      expect(shelf.barWithId('b3e1d7'), guestBar(refreshed: anHourAgo));
    });

    test('restamps the bar it wrote, and only that one', () {
      final shelf = shelfOf(openId: '5f2c9a').withCollection(_gin, _at);
      final written = shelf.barWithId('5f2c9a')!;
      expect(written.updated, _at);
      expect(written.holds, holdingsOf(_gin));
      expect(shelf.barWithId('b3e1d7')!.updated, isNull);
    });

    test('throws on a guest bar, whose contents are its owner\'s (ADR 23)', () {
      expect(
        () => shelfOf(openId: 'b3e1d7').withCollection(_gin, _at),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('read-only'),
          ),
        ),
      );
    });

    test('throws where no bar is open, there being nothing to write to', () {
      expect(() => shelfOf().withCollection(_gin, _at), throwsArgumentError);
    });
  });

  group('withBar', () {
    test('adds a record the shelf does not hold', () {
      final shelf = shelfOf().withBar(ownedBar(id: 'c7a2', name: 'Beach bar'));
      expect(shelf.bars.map((bar) => bar.id), ['5f2c9a', 'b3e1d7', 'c7a2']);
    });

    test('replaces the record of an id where it already stands', () {
      final shelf = shelfOf().withBar(ownedBar(name: 'Kitchen bar'));
      expect(shelf.bars.map((bar) => bar.name), ['Kitchen bar', 'Ada\'s bar']);
    });

    test('leaves the open bar and its collection where they were', () {
      final shelf = shelfOf(
        openId: '5f2c9a',
        collection: _gin,
      ).withBar(ownedBar(offers: const [(via: Transport.lan, guests: [])]));
      expect(shelf.openId, '5f2c9a');
      expect(shelf.collection, _gin);
      expect(shelf.open?.offers, hasLength(1));
    });

    test('still refuses a record the shelf cannot hold', () {
      expect(
        () => shelfOf().withBar(guestBar(id: 'c7a2', source: null)),
        throwsArgumentError,
      );
    });
  });

  group('withoutBar', () {
    test('drops the bar of that id, the rest in place (FR-BAR-2)', () {
      final shelf = shelfOf(openId: '5f2c9a', collection: _gin);
      expect(shelf.withoutBar('b3e1d7').bars.map((bar) => bar.id), ['5f2c9a']);
      expect(shelf.withoutBar('b3e1d7').collection, _gin, reason: 'open kept');
      expect(shelf.withoutBar('b3e1d7').openId, '5f2c9a');
    });

    test('deleting the open bar leaves none open and nothing resident', () {
      final shelf = shelfOf(
        openId: '5f2c9a',
        collection: _gin,
      ).withoutBar('5f2c9a');
      expect(shelf.openId, isNull);
      expect(shelf.open, isNull);
      expect(shelf.collection, Collection());
      expect(shelf.bars.map((bar) => bar.id), ['b3e1d7']);
    });

    test('an id the shelf does not hold changes nothing', () {
      final shelf = shelfOf(openId: '5f2c9a', collection: _gin);
      expect(shelf.withoutBar('nothing'), same(shelf));
    });

    test('the last bar out leaves an empty shelf', () {
      final shelf = Shelf(bars: [ownedBar()], openId: '5f2c9a');
      expect(shelf.withoutBar('5f2c9a'), Shelf());
    });
  });

  group('opening', () {
    test('moves the record and the bytes at once', () {
      final shelf = shelfOf(
        openId: '5f2c9a',
        collection: _gin,
      ).opening('b3e1d7', _rum);
      expect(shelf.openId, 'b3e1d7');
      expect(shelf.open?.name, 'Ada\'s bar');
      expect(shelf.collection, _rum);
    });

    test('throws on an id naming no bar', () {
      expect(() => shelfOf().opening('nothing', _gin), throwsArgumentError);
    });
  });

  group('refreshedWith', () {
    final payload = (
      name: 'Ada\'s cocktails',
      display: FixedUnit.oz,
      collection: _rum,
    );
    final now = DateTime.utc(2026, 8, 12, 9);

    test('takes the owner\'s collection, and stamps the answer', () {
      final shelf = shelfOf(
        openId: 'b3e1d7',
        collection: _gin,
      ).refreshedWith('b3e1d7', payload, now);
      expect(shelf.open?.refreshed, now);
      expect(shelf.collection, _rum);
    });

    test('never the name or the unit, which are the reader\'s (ADR 21)', () {
      final standing = guestBar(display: FixedUnit.ml);
      final shelf = Shelf(
        bars: [standing],
        openId: 'b3e1d7',
      ).refreshedWith('b3e1d7', payload, now);
      expect(shelf.open?.display, FixedUnit.ml);
      expect(shelf.open?.name, standing.name);
    });

    test('a bar that is not the one open keeps the resident collection', () {
      final shelf = shelfOf(
        openId: '5f2c9a',
        collection: _gin,
      ).refreshedWith('b3e1d7', payload, now);
      expect(shelf.collection, _gin);
      expect(shelf.barWithId('b3e1d7')?.holds, holdingsOf(_rum));
      expect(shelf.barWithId('b3e1d7')?.refreshed, now);
    });

    test('counts what arrived, the open bar and another alike', () {
      for (final openId in ['b3e1d7', '5f2c9a']) {
        final shelf = shelfOf(
          openId: openId,
          collection: _gin,
        ).refreshedWith('b3e1d7', payload, now);
        expect(shelf.barWithId('b3e1d7')?.holds, holdingsOf(_rum));
      }
    });

    test('the source it refreshed from stays with it', () {
      final shelf = shelfOf(
        openId: 'b3e1d7',
      ).refreshedWith('b3e1d7', payload, now);
      expect(shelf.open?.source, aSource);
    });

    test('an id the shelf does not hold changes nothing', () {
      final shelf = shelfOf(openId: '5f2c9a', collection: _gin);
      expect(shelf.refreshedWith('nothing', payload, now), same(shelf));
    });

    test('throws on an owned bar, which refreshes from nothing', () {
      expect(
        () => shelfOf(openId: '5f2c9a').refreshedWith('5f2c9a', payload, now),
        throwsArgumentError,
      );
    });
  });
}
