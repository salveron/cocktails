import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'collection_test.dart' show tokenVocabulary, valueEquality;

/// The source a guest bar refreshes from, as the index's own example writes it.
const aSource = BarSource(
  via: Transport.lan,
  at: '_cocktails._tcp/5f2c9a',
  from: 'Home bar (b3e)',
);

/// When a source last answered; UTC, as the index records it.
final anHourAgo = DateTime.utc(2026, 8, 9, 18, 22, 4);

/// Something for a summary to count, small enough that the four numbers it
/// answers with can be read at a glance.
final _twoIngredients = Collection(
  ingredients: [Ingredient('gin'), Ingredient('campari')],
);

/// The two kinds of record, built so a test names only what it is about. Shared
/// with shelf_edits_test.dart and validation_test.dart.
Bar ownedBar({
  String id = '5f2c9a',
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
  List<Offer> offers = const [],
  DateTime? updated,
  Map<Holding, int>? holds,
}) => Bar(
  id: id,
  name: name,
  mode: BarMode.owner,
  display: display,
  offers: offers,
  updated: updated,
  holds: holds,
);

Bar guestBar({
  String id = 'b3e1d7',
  String name = 'Ada\'s bar',
  FixedUnit display = FixedUnit.part,
  BarSource? source = aSource,
  DateTime? refreshed,
  Map<Holding, int>? holds,
}) => Bar(
  id: id,
  name: name,
  mode: BarMode.guest,
  display: display,
  source: source,
  refreshed: refreshed,
  holds: holds,
);

void main() {
  tokenVocabulary(
    'BarMode',
    values: BarMode.values,
    token: (value) => value.token,
    fromToken: BarMode.fromToken,
    tokens: const ['owner', 'guest'],
    unknown: 'reader',
  );

  tokenVocabulary(
    'Transport',
    values: Transport.values,
    token: (value) => value.token,
    fromToken: Transport.fromToken,
    tokens: const ['file', 'lan', 'cloud'],
    unknown: 'bluetooth',
  );

  group('BarSource', () {
    valueEquality(
      () => const BarSource(via: Transport.lan, at: 'a', from: 'b'),
      const {
        'via': BarSource(via: Transport.file, at: 'a', from: 'b'),
        'at': BarSource(via: Transport.lan, at: 'z', from: 'b'),
        'from': BarSource(via: Transport.lan, at: 'a', from: 'z'),
      },
    );
  });

  group('Bar', () {
    test('defaults to sharing nothing, and to reading in parts', () {
      final bar = ownedBar();
      expect(bar.offers, isEmpty);
      expect(bar.display, FixedUnit.part);
      expect(bar.source, isNull);
      expect(bar.refreshed, isNull);
    });

    test('the mode answers whose bar it is', () {
      expect(ownedBar().isOwned, isTrue);
      expect(guestBar().isOwned, isFalse);
    });

    valueEquality(ownedBar, {
      'id': ownedBar(id: 'other'),
      'name': ownedBar(name: 'Beach bar'),
      'mode': guestBar(id: '5f2c9a', name: 'Home bar'),
      'display': ownedBar(display: FixedUnit.ml),
      'offers': ownedBar(offers: const [(via: Transport.lan, guests: [])]),
    });

    valueEquality(guestBar, {
      'source': guestBar(
        source: const BarSource(via: Transport.file, at: '', from: 'a file'),
      ),
      'refreshed': guestBar(refreshed: DateTime.utc(2026)),
    });

    // A record holds its guest list by reference, so offers equal part for part
    // would read as different without shelf.dart comparing them itself.
    test('offers compare by their parts, not by list identity', () {
      Bar shared() => ownedBar(
        offers: [
          (via: Transport.cloud, guests: ['ada', 'grace']),
        ],
      );
      expect(shared(), shared());
      expect(shared().hashCode, shared().hashCode);
      expect(
        shared(),
        isNot(
          ownedBar(
            offers: [
              (via: Transport.cloud, guests: ['ada']),
            ],
          ),
        ),
      );
    });

    test('an id differing in case is another bar, names being ADR 08\'s', () {
      expect(ownedBar(id: '5f2c9a'), isNot(ownedBar(id: '5F2C9A')));
      expect(ownedBar(name: 'Home bar'), isNot(ownedBar(name: 'home bar')));
    });

    test('copyWith replaces one field and carries the rest', () {
      final bar = guestBar(display: FixedUnit.ml, refreshed: anHourAgo);
      expect(bar.copyWith(), bar, reason: 'nothing named');
      expect(
        bar.copyWith(name: 'Ada\'s other bar').name,
        'Ada\'s other bar',
        reason: 'name',
      );
      expect(
        bar.copyWith(name: 'Ada\'s other bar').refreshed,
        anHourAgo,
        reason: 'the rest rides along',
      );
      expect(
        bar.copyWith(display: FixedUnit.oz),
        guestBar(display: FixedUnit.oz, refreshed: anHourAgo),
        reason: 'display',
      );
    });

    test('refreshedAt is the one writer of the stamp (FR-BAR-5)', () {
      final now = DateTime.utc(2026, 3, 1, 18);
      final bar = guestBar(refreshed: anHourAgo);
      final landed = bar.refreshedAt(_twoIngredients, now);
      expect(landed.refreshed, now);
      expect(landed.holds, holdingsOf(_twoIngredients));
      // The reader's two picks outlive what the owner sent (ADR 21), and where
      // the bar refreshes from is untouched by having refreshed.
      expect(landed.name, bar.name);
      expect(landed.display, bar.display);
      expect(landed.source, bar.source);
    });

    test('summarised counts the contents and dates them', () {
      final at = DateTime.utc(2026, 3, 1, 18);
      final bar = ownedBar().summarised(_twoIngredients, at: at);
      expect(bar.holds, holdingsOf(_twoIngredients));
      expect(bar.updated, at);
    });

    test('a first summary is a count, not an edit, and dates nothing', () {
      final bar = ownedBar().summarised(_twoIngredients);
      expect(bar.holds, holdingsOf(_twoIngredients));
      expect(bar.updated, isNull);
    });

    test('neither stamp is a copy\'s to move', () {
      final at = DateTime.utc(2026, 3, 1, 18);
      final bar = ownedBar().summarised(_twoIngredients, at: at);
      final renamed = bar.copyWith(name: 'Beach bar');
      expect(renamed.updated, at);
      expect(renamed.holds, bar.holds);
    });

    test('a summary cannot be changed from outside', () {
      expect(
        () => ownedBar().summarised(_twoIngredients).holds!.clear(),
        throwsUnsupportedError,
      );
    });

    test(
      'two bars counted apart compare equal, and a bar uncounted does not',
      () {
        expect(
          ownedBar().summarised(_twoIngredients),
          ownedBar().summarised(_twoIngredients),
        );
        expect(ownedBar().summarised(Collection()), isNot(ownedBar()));
      },
    );

    test('the offers cannot be changed from outside', () {
      final offers = <Offer>[(via: Transport.lan, guests: [])];
      final bar = ownedBar(offers: offers);
      offers.add((via: Transport.cloud, guests: []));
      expect(bar.offers, hasLength(1));
      expect(
        () => bar.offers.add((via: Transport.file, guests: [])),
        throwsUnsupportedError,
      );
    });
  });

  group('Shelf', () {
    test('starts empty, with no bar open and nothing resident', () {
      final shelf = Shelf();
      expect(shelf.bars, isEmpty);
      expect(shelf.openId, isNull);
      expect(shelf.open, isNull);
      expect(shelf.collection, Collection());
    });

    test('answers with the bar of an id, and the one on show', () {
      final shelf = Shelf(bars: [ownedBar(), guestBar()], openId: 'b3e1d7');
      expect(shelf.barWithId('5f2c9a')?.name, 'Home bar');
      expect(shelf.open, guestBar());
      expect(shelf.barWithId('nothing'), isNull);
    });

    test('two bars may carry one name (FR-BAR-1)', () {
      final shelf = Shelf(
        bars: [
          ownedBar(),
          guestBar(name: 'Home bar'),
        ],
      );
      expect(shelf.bars.map((bar) => bar.name), ['Home bar', 'Home bar']);
    });

    test('rejects two bars of one id', () {
      expect(
        () => Shelf(
          bars: [
            ownedBar(),
            guestBar(id: '5f2c9a'),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Duplicate bar id'), contains('5f2c9a')),
          ),
        ),
      );
    });

    test('rejects an open bar that is not on the shelf', () {
      expect(
        () => Shelf(bars: [ownedBar()], openId: 'b3e1d7'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('b3e1d7'),
          ),
        ),
      );
      expect(() => Shelf(openId: '5f2c9a'), throwsArgumentError);
    });

    test('rejects a guest bar with no source to refresh from', () {
      expect(
        () => Shelf(bars: [guestBar(source: null)]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('source'),
          ),
        ),
      );
    });

    test('rejects an owned bar carrying a source or a refresh time', () {
      for (final bar in [
        Bar(id: 'a', name: 'Home bar', mode: BarMode.owner, source: aSource),
        Bar(
          id: 'a',
          name: 'Home bar',
          mode: BarMode.owner,
          refreshed: anHourAgo,
        ),
      ]) {
        expect(() => Shelf(bars: [bar]), throwsArgumentError, reason: '$bar');
      }
    });

    test('rejects a guest bar dating a change of its own', () {
      expect(
        () => Shelf(
          bars: [
            Bar(
              id: 'a',
              name: 'Ada\'s bar',
              mode: BarMode.guest,
              source: aSource,
              updated: anHourAgo,
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('refreshes'),
          ),
        ),
      );
    });

    test('rejects a guest bar offering what is not this device\'s to give', () {
      expect(
        () => Shelf(
          bars: [
            Bar(
              id: 'a',
              name: 'Ada\'s bar',
              mode: BarMode.guest,
              source: aSource,
              offers: const [(via: Transport.lan, guests: [])],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects one bar offered twice by one transport', () {
      expect(
        () => Shelf(
          bars: [
            ownedBar(
              offers: const [
                (via: Transport.lan, guests: []),
                (via: Transport.lan, guests: ['ada']),
              ],
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('lan'),
          ),
        ),
      );
    });

    test('takes one bar offered by each of several transports', () {
      final shelf = Shelf(
        bars: [
          ownedBar(
            offers: const [
              (via: Transport.lan, guests: []),
              (via: Transport.cloud, guests: ['ada']),
            ],
          ),
        ],
      );
      expect(shelf.bars.single.offers, hasLength(2));
    });

    test('the bars cannot be changed from outside', () {
      final shelf = Shelf(bars: [ownedBar()]);
      expect(() => shelf.bars.add(guestBar()), throwsUnsupportedError);
    });

    valueEquality(() => Shelf(bars: [ownedBar()], openId: '5f2c9a'), {
      'bars': Shelf(
        bars: [ownedBar(name: 'Beach bar')],
        openId: '5f2c9a',
      ),
      'openId': Shelf(bars: [ownedBar()]),
      'collection': Shelf(
        bars: [ownedBar()],
        openId: '5f2c9a',
        collection: Collection(ingredients: [Ingredient('gin')]),
      ),
    });
  });
}
