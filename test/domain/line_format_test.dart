import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// The vocabulary every line here is written against — what a file naming no
/// units is read with (ADR 09).
const units = defaultUnits;

/// One a user might add: a plural no rule could have guessed.
const leaf = Unit('leaf', plural: 'leaves');

void main() {
  group('parseRecipeLine', () {
    test('parses a single-amount line', () {
      expect(
        parseRecipeLine('0.75 part lemon juice', units),
        const RecipeLine(Amount(0.75), 'part', ['lemon juice']),
      );
    });

    test('parses an integer amount', () {
      expect(
        parseRecipeLine('2 oz gin', units),
        const RecipeLine(Amount(2), 'oz', ['gin']),
      );
    });

    test('parses a range amount', () {
      expect(
        parseRecipeLine('1.5-2 part bourbon', units),
        const RecipeLine(Amount.range(1.5, 2), 'part', ['bourbon']),
      );
    });

    test('strips the (optional) suffix', () {
      expect(
        parseRecipeLine('0.5 part egg white (optional)', units),
        const RecipeLine(Amount(0.5), 'part', [
          'egg white',
        ], mark: LineMark.optional),
      );
    });

    test('strips the (base) suffix', () {
      expect(
        parseRecipeLine('1.5 part bourbon (base)', units),
        const RecipeLine(Amount(1.5), 'part', ['bourbon'], mark: LineMark.base),
      );
    });

    test('without the leading space, (optional) stays in the name', () {
      expect(
        parseRecipeLine('1 part gin(optional)', units),
        const RecipeLine(Amount(1), 'part', ['gin(optional)']),
      );
    });

    test('two suffixes cannot combine: only the last one is the mark', () {
      expect(
        parseRecipeLine('1 part gin (base) (optional)', units),
        const RecipeLine(Amount(1), 'part', [
          'gin (base)',
        ], mark: LineMark.optional),
      );
    });

    test('accepts every unit the vocabulary holds', () {
      for (final unit in units) {
        expect(parseRecipeLine('1 ${unit.name} gin', units).unit, unit.name);
      }
    });

    test('tolerates surrounding and repeated whitespace', () {
      expect(
        parseRecipeLine('  1.5   part   bourbon  ', units),
        const RecipeLine(Amount(1.5), 'part', ['bourbon']),
      );
    });

    test('leaves value rules to M5: zero and inverted ranges parse', () {
      expect(parseRecipeLine('0 part gin', units).amount, const Amount(0));
      expect(
        parseRecipeLine('2-1.5 part gin', units).amount,
        const Amount.range(2, 1.5),
      );
    });

    test('rejects lines with no amount, or with nothing left to name', () {
      const lines = ['', '   ', 'bourbon', '2 dash', '0.5 part (optional)'];
      for (final line in lines) {
        expect(
          () => parseRecipeLine(line, units),
          throwsFormatException,
          reason: line,
        );
      }
    });

    test('rejects malformed amounts, naming the value', () {
      const amounts = ['x', '.5', '1.', '1,5', '-1', '1-', '1.5-2-3'];
      for (final amount in amounts) {
        expect(
          () => parseRecipeLine('$amount part gin', units),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('"$amount"'),
            ),
          ),
          reason: amount,
        );
      }
    });

    test('a line with no unit is measured in parts', () {
      expect(
        parseRecipeLine('1 gin', units),
        const RecipeLine(Amount(1), 'part', ['gin']),
      );
      expect(
        parseRecipeLine('0.75 lemon juice', units),
        const RecipeLine(Amount(0.75), 'part', ['lemon juice']),
      );
      expect(
        parseRecipeLine('1.5-2 bourbon (base)', units),
        const RecipeLine(Amount.range(1.5, 2), 'part', [
          'bourbon',
        ], mark: LineMark.base),
      );
    });

    test('a word that is no unit belongs to the ingredient name', () {
      expect(
        parseRecipeLine('1.5 cup sugar', units),
        const RecipeLine(Amount(1.5), 'part', ['cup sugar']),
      );
    });

    test('what is a unit is the vocabulary\'s to say', () {
      const tsp = Unit('tsp');
      expect(
        parseRecipeLine('1.5 tsp sugar', units),
        const RecipeLine(Amount(1.5), 'part', ['tsp sugar']),
      );
      expect(
        parseRecipeLine('1.5 tsp sugar', const [...units, tsp]),
        const RecipeLine(Amount(1.5), 'tsp', ['sugar']),
      );
    });

    test('a unit may be written in the plural', () {
      for (final unit in units) {
        expect(
          parseRecipeLine('2 ${unit.pluralName} gin', units).unit,
          unit.name,
        );
      }
      expect(parseRecipeLine('2 dashes bitters', units).unit, 'dash');
      expect(parseRecipeLine('2 pieces lime', units).unit, 'piece');
    });

    test('a plural the vocabulary never wrote is still accepted', () {
      for (final unit in units) {
        expect(parseRecipeLine('2 ${unit.name}s gin', units).unit, unit.name);
      }
      expect(
        parseRecipeLine('2 tsps sugar', const [...units, Unit('tsp')]).unit,
        'tsp',
      );
    });

    test('whichever spelling is typed, the line takes the unit\'s own', () {
      const written = [...units, leaf];
      expect(parseRecipeLine('2 leaves mint', written).unit, 'leaf');
      expect(parseRecipeLine('2 Leaves mint', written).unit, 'leaf');
      expect(parseRecipeLine('1 LEAF mint', written).unit, 'leaf');
    });

    test('what it accepts loosely it writes in full', () {
      expect(
        formatRecipeLine(parseRecipeLine('2 dash gin', units), units),
        '2 dashes gin',
      );
      expect(
        formatRecipeLine(parseRecipeLine('1 gin', units), units),
        '1 part gin',
      );
    });
  });

  group('substitution groups (ADR 11)', () {
    test('a slash names alternatives, any one of which makes the line', () {
      expect(
        parseRecipeLine('1 part cognac / vodka', units),
        const RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
      );
    });

    test('the spaces around it are optional', () {
      for (final line in [
        '1 part cognac/vodka',
        '1 part cognac /vodka',
        '1 part cognac  /  vodka',
      ]) {
        expect(
          parseRecipeLine(line, units),
          const RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
        );
      }
    });

    test('there may be more than two', () {
      expect(
        parseRecipeLine('1 part cognac / brandy / armagnac', units),
        const RecipeLine(Amount(1), 'part', ['cognac', 'brandy', 'armagnac']),
      );
    });

    test('the mark is taken off first, so it governs the whole group', () {
      expect(
        parseRecipeLine('2 parts rye / bourbon (base)', units),
        const RecipeLine(Amount(2), 'part', [
          'rye',
          'bourbon',
        ], mark: LineMark.base),
      );
    });

    test('one amount and one unit measure the group', () {
      expect(
        parseRecipeLine('2 oz lemon juice / lime juice', units),
        const RecipeLine(Amount(2), 'oz', ['lemon juice', 'lime juice']),
      );
    });

    test('an omitted unit still reads as parts', () {
      expect(
        parseRecipeLine('1 cognac/vodka', units),
        const RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
      );
    });

    test('a name is wanted either side of the slash', () {
      for (final line in ['1 part cognac /', '1 part / vodka', '1 part /']) {
        expect(
          tryParseRecipeLine(line, units).problem,
          'Expected an ingredient either side of "/": "$line"',
        );
        expect(tryParseRecipeLine(line, units).line, isNull);
      }
    });

    test('a slash before the mark is no mark at all', () {
      expect(
        parseRecipeLine('1 part cognac (base) / vodka', units),
        const RecipeLine(Amount(1), 'part', ['cognac (base)', 'vodka']),
      );
    });

    test('a second amount is a name nothing answers to, not a measure', () {
      expect(
        parseRecipeLine('1 part cognac / 2 parts vodka', units),
        const RecipeLine(Amount(1), 'part', ['cognac', '2 parts vodka']),
      );
    });

    test('it writes back spaced, whichever way it was typed', () {
      expect(
        formatRecipeLine(parseRecipeLine('1 cognac/vodka', units), units),
        '1 part cognac / vodka',
      );
    });

    test('a group survives parse then format, and format then parse', () {
      const line = '1.5-2 parts rye / bourbon / cognac (base)';
      expect(formatRecipeLine(parseRecipeLine(line, units), units), line);
      const parsed = RecipeLine(Amount(0.5), 'dash', [
        'absinthe',
        'pastis',
      ], mark: LineMark.optional);
      expect(parseRecipeLine(formatRecipeLine(parsed, units), units), parsed);
    });
  });

  group('tryParseRecipeLine', () {
    test('never throws, valid or not', () {
      const lines = [
        '0.75 part lemon juice',
        '0.5 part egg white (optional)',
        'bourbon',
        'x part gin',
        '1.5 cup sugar',
      ];
      for (final line in lines) {
        expect(
          () => tryParseRecipeLine(line, units),
          returnsNormally,
          reason: line,
        );
      }
    });

    test('returns the line and no problem for a plain valid line', () {
      final parsed = tryParseRecipeLine('0.75 part lemon juice', units);
      expect(parsed.problem, isNull);
      expect(
        parsed.line,
        const RecipeLine(Amount(0.75), 'part', ['lemon juice']),
      );
    });

    test('returns the line and no problem for an (optional) valid line', () {
      final parsed = tryParseRecipeLine('0.5 part egg white (optional)', units);
      expect(parsed.problem, isNull);
      expect(
        parsed.line,
        const RecipeLine(Amount(0.5), 'part', [
          'egg white',
        ], mark: LineMark.optional),
      );
    });

    test('returns a problem and no line on a shape mismatch', () {
      final parsed = tryParseRecipeLine('bourbon', units);
      expect(parsed.line, isNull);
      expect(parsed.problem, contains('Expected'));
    });

    test('returns a problem and no line on an invalid amount', () {
      final parsed = tryParseRecipeLine('x part gin', units);
      expect(parsed.line, isNull);
      expect(parsed.problem, 'Invalid amount: "x"');
    });

    test('returns a problem and no line where a unit is all there is', () {
      final parsed = tryParseRecipeLine('1.5 barspoon', units);
      expect(parsed.line, isNull);
      expect(parsed.problem, contains('Expected'));
    });
  });

  group('parseRecipeLine behaves like tryParseRecipeLine', () {
    test('returns the same line tryParseRecipeLine parses', () {
      const lines = [
        '0.75 part lemon juice',
        '0.5 part egg white (optional)',
        '1.5-2 part bourbon',
      ];
      for (final line in lines) {
        expect(
          parseRecipeLine(line, units),
          tryParseRecipeLine(line, units).line,
        );
      }
    });

    test('throws the same message tryParseRecipeLine reports as a problem', () {
      const lines = ['bourbon', 'x part gin', '2 dash', ''];
      for (final line in lines) {
        final problem = tryParseRecipeLine(line, units).problem!;
        expect(
          () => parseRecipeLine(line, units),
          throwsA(
            isA<FormatException>().having((e) => e.message, 'message', problem),
          ),
          reason: line,
        );
      }
    });
  });

  group('formatRecipeLine', () {
    test('formats a single amount', () {
      expect(
        formatRecipeLine(
          const RecipeLine(Amount(0.75), 'part', ['lemon juice']),
          units,
        ),
        '0.75 parts lemon juice',
      );
    });

    test('drops the trailing .0 from whole numbers', () {
      expect(
        formatRecipeLine(const RecipeLine(Amount(2), 'oz', ['gin']), units),
        '2 oz gin',
      );
    });

    test('formats a range', () {
      expect(
        formatRecipeLine(
          const RecipeLine(Amount.range(1.5, 2), 'part', ['bourbon']),
          units,
        ),
        '1.5-2 parts bourbon',
      );
    });

    test('appends the (optional) suffix', () {
      expect(
        formatRecipeLine(
          const RecipeLine(Amount(0.5), 'part', [
            'egg white',
          ], mark: LineMark.optional),
          units,
        ),
        '0.5 parts egg white (optional)',
      );
    });

    test('appends the (base) suffix', () {
      expect(
        formatRecipeLine(
          const RecipeLine(Amount(1.5), 'part', [
            'bourbon',
          ], mark: LineMark.base),
          units,
        ),
        '1.5 parts bourbon (base)',
      );
    });

    test('the plural reads for anything but exactly one', () {
      const written = [...units, leaf];
      String measure(Amount amount) => formatRecipeLine(
        RecipeLine(amount, 'leaf', ['mint']),
        written,
      ).split(' mint').first;
      expect(measure(const Amount(1)), '1 leaf');
      expect(measure(const Amount.range(1, 1)), '1 leaf');
      expect(measure(const Amount(0.75)), '0.75 leaves');
      expect(measure(const Amount(2)), '2 leaves');
      expect(measure(const Amount.range(1.5, 2)), '1.5-2 leaves');
    });

    test('a unit reading like its name pluralises to itself', () {
      expect(
        formatRecipeLine(const RecipeLine(Amount(2), 'ml', ['gin']), units),
        '2 ml gin',
      );
    });

    test('a unit the vocabulary has lost prints as written', () {
      expect(
        formatRecipeLine(const RecipeLine(Amount(2), 'cube', ['sugar']), units),
        '2 cube sugar',
      );
    });
  });

  group('formatAmount', () {
    test('canonical amount text', () {
      expect(formatAmount(const Amount(2)), '2');
      expect(formatAmount(const Amount(0.75)), '0.75');
      expect(formatAmount(const Amount.range(1.5, 2)), '1.5-2');
      expect(formatAmount(const Amount.range(2, 2)), '2');
    });
  });

  group('round trip', () {
    test('canonical lines survive parse then format', () {
      const lines = [
        '1.5-2 parts bourbon',
        '0.75 parts lemon juice',
        '0.5 parts rich demerara syrup',
        '0.5 parts egg white (optional)',
        '2 oz rye whiskey (base)',
        '2 oz gin',
        '1 part gin',
        '1 barspoon maraschino liqueur',
        '2 dashes angostura bitters',
      ];
      for (final line in lines) {
        expect(
          formatRecipeLine(parseRecipeLine(line, units), units),
          line,
          reason: line,
        );
      }
    });

    test('lines survive format then parse', () {
      const lines = [
        RecipeLine(Amount(2), 'oz', ['gin']),
        RecipeLine(Amount(0.75), 'part', ['lemon juice']),
        RecipeLine(Amount.range(1.5, 2), 'part', ['bourbon']),
        RecipeLine(Amount(0.5), 'part', ['egg white'], mark: LineMark.optional),
        RecipeLine(Amount(2), 'oz', ['rye whiskey'], mark: LineMark.base),
        RecipeLine(Amount(1), 'drop', ['saline solution']),
        RecipeLine(Amount(3), 'drop', ['saline solution']),
      ];
      for (final line in lines) {
        expect(
          parseRecipeLine(formatRecipeLine(line, units), units),
          line,
          reason: '$line',
        );
      }
    });

    test('non-canonical input formats to canonical form', () {
      String canonical(String line) =>
          formatRecipeLine(parseRecipeLine(line, units), units);
      expect(canonical('2.0  oz  gin'), '2 oz gin');
      expect(canonical('2-2 part gin'), '2 parts gin');
      expect(canonical('01.50 part gin'), '1.5 parts gin');
      expect(canonical('2 dash gin'), '2 dashes gin');
    });
  });
}
