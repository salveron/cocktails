import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
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

    test('rejects a guest bar naming an optimizer of its own (ADR 21/24)', () {
      expect(
        () => Shelf(
          bars: [
            Bar(
              id: 'a',
              name: 'Ada\'s bar',
              mode: BarMode.guest,
              source: aSource,
              shopping: const ShoppingSettings(),
            ),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('optimizer'),
          ),
        ),
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
