import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/domain/src/shelf/bar.dart' show summaryOf;
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

/// Something for a summary to count, small enough that the four numbers it
/// answers with can be read at a glance.
final _twoIngredients = Collection(
  ingredients: [Ingredient('gin'), Ingredient('campari')],
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

    test('an owner defaults to its own optimizer settings', () {
      expect(ownedBar().shopping, const ShoppingSettings());
    });

    test('a guest carries no optimizer of its own (ADR 21, ADR 24)', () {
      expect(guestBar().shopping, isNull);
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

    final bar = guestBar(display: FixedUnit.ml, refreshed: anHourAgo);
    copyWithContract([
      (field: 'nothing named', apply: () => bar.copyWith(), expected: bar),
      (
        field: 'name',
        apply: () => bar.copyWith(name: 'Ada\'s other bar'),
        expected: guestBar(
          name: 'Ada\'s other bar',
          display: FixedUnit.ml,
          refreshed: anHourAgo,
        ),
      ),
      (
        field: 'display',
        apply: () => bar.copyWith(display: FixedUnit.oz),
        expected: guestBar(display: FixedUnit.oz, refreshed: anHourAgo),
      ),
    ]);

    test('refreshedAt is the one writer of the stamp (FR-BAR-5)', () {
      final now = DateTime.utc(2026, 3, 1, 18);
      final bar = guestBar(refreshed: anHourAgo);
      final landed = bar.refreshedAt(_twoIngredients, now);
      expect(landed.refreshed, now);
      expect(landed.summary, summaryOf(_twoIngredients));
      // The reader's two picks outlive what the owner sent (ADR 21), and where
      // the bar refreshes from is untouched by having refreshed.
      expect(landed.name, bar.name);
      expect(landed.display, bar.display);
      expect(landed.source, bar.source);
    });

    test('summarised counts the contents and dates them', () {
      final at = DateTime.utc(2026, 3, 1, 18);
      final bar = ownedBar().summarised(_twoIngredients, at: at);
      expect(bar.summary, summaryOf(_twoIngredients));
      expect(bar.updated, at);
    });

    test('a first summary is a count, not an edit, and dates nothing', () {
      final bar = ownedBar().summarised(_twoIngredients);
      expect(bar.summary, summaryOf(_twoIngredients));
      expect(bar.updated, isNull);
    });

    test('neither stamp is a copy\'s to move', () {
      final at = DateTime.utc(2026, 3, 1, 18);
      final bar = ownedBar().summarised(_twoIngredients, at: at);
      final renamed = bar.copyWith(name: 'Beach bar');
      expect(renamed.updated, at);
      expect(renamed.summary, bar.summary);
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
    });
  });

  group('summaryOf', () {
    test('counts each kind, and the four in the order a reader meets '
        'them', () {
      final collection = Collection(
        units: const [Unit('part'), Unit('dash')],
        ingredients: [Ingredient('gin'), Ingredient('campari')],
        recipeTags: const [Tag('classic', color: TagColor.rose)],
        ingredientTags: const [
          Tag('italian', color: TagColor.teal),
          Tag('juniper', color: TagColor.sand),
        ],
        recipes: [Recipe('Negroni')],
      );
      expect(summaryOf(collection).keys, Holding.values);
      // The tags of both vocabularies under one count, as the screen managing
      // them lists them (ADR 07).
      expect(summaryOf(collection), {
        Holding.recipe: 1,
        Holding.ingredient: 2,
        Holding.tag: 3,
        Holding.unit: 2,
      });
    });

    test('an empty collection still carries the units it opens with', () {
      expect(summaryOf(Collection()), {
        Holding.recipe: 0,
        Holding.ingredient: 0,
        Holding.tag: 0,
        Holding.unit: defaultUnits.length,
      });
    });

    test('every kind is named for the reader by its own noun', () {
      expect(
        [for (final holding in Holding.values) holding.noun],
        ['recipe', 'ingredient', 'tag', 'unit'],
      );
    });

    test('and written to the index under a token of its own (ADR 21)', () {
      // Declared rather than the identifier or the noun: a summary already in
      // an index must go on reading the same after either is renamed.
      expect(
        [for (final holding in Holding.values) holding.token],
        ['recipe', 'ingredient', 'tag', 'unit'],
      );
    });
  });
}
