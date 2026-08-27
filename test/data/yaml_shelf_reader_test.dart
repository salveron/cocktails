/// The shelf index read into the parts it carries: which bars this device
/// holds, which one is open, and what each was last counted as. Device state
/// rather than an export, written by the same emitter and judged by
/// `validateShelf` (docs/architecture.md#data-format).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  group('the index', () {
    final home = Bar(id: '5f2c9a', name: 'Home bar', mode: BarMode.owner);
    final guest = Bar(
      id: 'b3e1d7',
      name: 'Home bar',
      mode: BarMode.guest,
      display: FixedUnit.ml,
      refreshed: DateTime.utc(2026, 8, 9, 18, 22, 4),
      source: const BarSource(
        via: Transport.lan,
        at: '_cocktails._tcp/x',
        from: 'Home bar (b3e)',
      ),
    );

    ShelfIndex indexOf(String yaml) {
      final result = codec.decodeIndex(yaml);
      if (result is Rejected<ShelfIndex>) {
        fail('expected Ok, got:\n${result.issues.join('\n')}');
      }
      return (result as Ok<ShelfIndex>).value;
    }

    List<SourcedIssue> indexRejected(String yaml) {
      final result = codec.decodeIndex(yaml);
      expect(result, isA<Rejected<ShelfIndex>>(), reason: 'expected Rejected');
      return (result as Rejected<ShelfIndex>).issues;
    }

    test('writes an owner as one line, its absent halves left off', () {
      expect(codec.encodeIndex((bars: [home], openId: home.id)), '''
format: 2
open: 5f2c9a

bars:
  - {id: 5f2c9a, name: Home bar, mode: owner, display: part}
''');
    });

    test('an offer and its guests ride on the record (FR-BAR-6)', () {
      final shared = home.copyWith(
        offers: const [
          (via: Transport.lan, guests: ['ada']),
          (via: Transport.file, guests: []),
        ],
      );
      expect(
        codec.encodeIndex((bars: [shared], openId: null)),
        contains('offers: [{via: lan, guests: [ada]}, {via: file}]'),
      );
    });

    test('a guest carries where it came from and when it answered', () {
      expect(
        codec.encodeIndex((bars: [guest], openId: null)),
        contains(
          'refreshed: "2026-08-09T18:22:04.000Z", '
          'source: {via: lan, at: _cocktails._tcp/x, from: Home bar (b3e)}',
        ),
      );
    });

    test('an owner carries when it changed and what it holds', () {
      final summarised = home.summarised(
        Collection(ingredients: [Ingredient('gin')]),
        at: DateTime.utc(2026, 8, 9, 18, 22, 4),
      );
      expect(
        codec.encodeIndex((bars: [summarised], openId: null)),
        contains(
          'updated: "2026-08-09T18:22:04.000Z", '
          'holds: {recipe: 0, ingredient: 1, tag: 0, '
          'unit: ${defaultUnits.length}}',
        ),
      );
    });

    test('a summary and its stamp survive the round trip', () {
      final counted = [
        home.summarised(
          Collection(recipes: [Recipe('Negroni')]),
          at: DateTime.utc(2026, 8, 9, 18, 22, 4),
        ),
        guest.summarised(Collection()),
      ];
      expect(
        indexOf(codec.encodeIndex((bars: counted, openId: null))).bars,
        counted,
      );
    });

    test('an index written before summaries existed reads as uncounted', () {
      // The one state the reader repairs by counting the bar afresh, so it
      // must survive decoding rather than being refused (ADR 20).
      final records = indexOf(
        'format: 2\n'
        'open: 5f2c9a\n\n'
        'bars:\n'
        '  - {id: 5f2c9a, name: Home bar, mode: owner}\n',
      );
      expect(records.bars.single.summary, isNull);
      expect(records.bars.single.updated, isNull);
    });

    test('a summary missing a kind is dropped, not patched with zeroes', () {
      final records = indexOf(
        'format: 2\n'
        'open: 5f2c9a\n\n'
        'bars:\n'
        '  - {id: 5f2c9a, name: Home bar, mode: owner, '
        'holds: {recipe: 3, ingredient: 4}}\n',
      );
      // A partial count read as a whole one would say the bar holds no tags.
      expect(records.bars.single.summary, isNull);
    });

    test('a count that is not one is refused', () {
      for (final holds in ['{recipe: -1}', '{recipe: many}', 'plenty']) {
        expect(
          indexRejected(
            'format: 2\n'
            'open: 5f2c9a\n\n'
            'bars:\n'
            '  - {id: 5f2c9a, name: Home bar, mode: owner, holds: $holds}\n',
          ),
          isNotEmpty,
          reason: holds,
        );
      }
    });

    test('an owned bar dating a refresh, or a guest an edit, is refused', () {
      for (final entry in [
        'mode: owner, refreshed: "2026-08-09T18:22:04.000Z"',
        'mode: guest, source: {via: file, at: a, from: b}, '
            'updated: "2026-08-09T18:22:04.000Z"',
      ]) {
        expect(
          indexRejected(
            'format: 2\n'
            'open:\n\n'
            'bars:\n'
            '  - {id: 5f2c9a, name: Home bar, $entry}\n',
          ),
          isNotEmpty,
          reason: entry,
        );
      }
    });

    test('two bars of one name are two records (FR-BAR-1)', () {
      final records = indexOf(
        codec.encodeIndex((bars: [home, guest], openId: guest.id)),
      );
      expect(records.bars, [home, guest]);
      expect(records.openId, 'b3e1d7');
    });

    // FR-SET-2, ADR 24: the block is the device's, not the file's — it rides
    // the index and never an export.
    group('what the optimizer is asked', () {
      Bar asking(ShoppingSettings shopping) =>
          Bar(id: 'a1', name: 'Ada', mode: BarMode.owner, shopping: shopping);

      test('round-trips whole', () {
        const asked = ShoppingSettings(
          aiming: true,
          budget: 3,
          restocking: true,
          keptPerSize: 50,
          buyingOptional: true,
        );
        final records = indexOf(
          codec.encodeIndex((bars: [asking(asked)], openId: null)),
        );
        expect(records.bars.single.shopping, asked);
      });

      test('is left off entirely while nothing in it has moved', () {
        final written = codec.encodeIndex((
          bars: [asking(const ShoppingSettings())],
          openId: null,
        ));
        expect(written, isNot(contains('shopping')));
        expect(indexOf(written).bars.single.shopping, const ShoppingSettings());
      });

      test('a record written before it existed reads as the defaults', () {
        final records = indexOf(
          'format: 2\nopen:\n'
          'bars:\n'
          '  - {id: a1, name: Ada, mode: owner}\n',
        );
        expect(records.bars.single.shopping, const ShoppingSettings());
      });

      test('a number outside what its screen offers is reported', () {
        final issues = indexRejected(
          'format: 2\nopen:\n'
          'bars:\n'
          '  - {id: a1, name: Ada, mode: owner, shopping: {budget: 7}}\n',
        );
        expect(issues.single.issue.message, contains('Budget must be one of'));
      });
    });

    test('an empty shelf round-trips, open naming nothing', () {
      final records = indexOf(
        codec.encodeIndex((bars: const [], openId: null)),
      );
      expect(records.bars, isEmpty);
      expect(records.openId, isNull);
    });

    test('an index carries the same format number as a bar\'s file', () {
      expect(
        codec.encodeIndex((bars: const [], openId: null)),
        startsWith('format: ${YamlCodec.formatVersion}\n'),
      );
    });

    test('a version it does not read is refused at the gate', () {
      expect(
        indexRejected('format: 9\nbars: []\n').single.issue.kind,
        ValidationIssueKind.unsupportedFormat,
      );
    });

    test('an unknown key is a structural error, as in a bar\'s file', () {
      expect(
        indexRejected('format: 2\nopen:\nbars: []\njunk: 1\n'),
        isNotEmpty,
      );
    });

    // The reason validateShelf takes bars already built (ADR 20): an index
    // this broken must be reported on, never crashed on.
    test('a record its mode forbids is reported, not thrown', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: guest}\n',
      );
      expect(issues.single.issue.message, contains('refreshes from'));
    });

    test('open naming a bar the shelf lacks is reported', () {
      final issues = indexRejected(
        'format: 2\nopen: nothing\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner}\n',
      );
      expect(issues.single.issue.message, contains('open names no bar'));
    });

    test('a duplicate id is reported', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner}\n'
        '  - {id: a1, name: Bea, mode: owner}\n',
      );
      expect(issues.first.issue.message, contains('Duplicate bar id'));
    });

    test('a record missing what every bar needs is reported', () {
      expect(
        indexRejected('format: 2\nopen:\nbars:\n  - {name: Ada}\n'),
        isNotEmpty,
      );
    });

    test('a refresh time that is not a timestamp is reported', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner, refreshed: soon}\n',
      );
      expect(issues.first.issue.message, contains('timestamp'));
    });

    test('never throws, whatever the input', () {
      for (final input in [
        '',
        'format: 2',
        'format: 2\nbars: 5\n',
        'format: 2\nbars: [1, 2]\n',
        'format: 2\nopen: 5\nbars: []\n',
        'format: 2\nbars:\n  - {id: a1, name: Ada, mode: sideways}\n',
        'format: 2\nbars:\n  - {id: a1, name: Ada, mode: guest, source: 5}\n',
        '- a list\n',
        '\t bad: yaml\n',
      ]) {
        expect(() => codec.decodeIndex(input), returnsNormally, reason: input);
      }
    });
  });
}
