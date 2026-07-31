import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRecipeLine', () {
    test('parses a single-amount line', () {
      expect(
        parseRecipeLine('0.75 part lemon juice'),
        const RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
      );
    });

    test('parses an integer amount', () {
      expect(
        parseRecipeLine('2 oz gin'),
        const RecipeLine(Amount(2), Unit.oz, 'gin'),
      );
    });

    test('parses a range amount', () {
      expect(
        parseRecipeLine('1.5-2 part bourbon'),
        const RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
      );
    });

    test('strips the (optional) suffix', () {
      expect(
        parseRecipeLine('0.5 part egg white (optional)'),
        const RecipeLine(
          Amount(0.5),
          Unit.part,
          'egg white',
          mark: LineMark.optional,
        ),
      );
    });

    test('strips the (base) suffix', () {
      expect(
        parseRecipeLine('1.5 part bourbon (base)'),
        const RecipeLine(
          Amount(1.5),
          Unit.part,
          'bourbon',
          mark: LineMark.base,
        ),
      );
    });

    test('without the leading space, (optional) stays in the name', () {
      expect(
        parseRecipeLine('1 part gin(optional)'),
        const RecipeLine(Amount(1), Unit.part, 'gin(optional)'),
      );
    });

    test('two suffixes cannot combine: only the last one is the mark', () {
      expect(
        parseRecipeLine('1 part gin (base) (optional)'),
        const RecipeLine(
          Amount(1),
          Unit.part,
          'gin (base)',
          mark: LineMark.optional,
        ),
      );
    });

    test('accepts every unit', () {
      for (final unit in Unit.values) {
        expect(parseRecipeLine('1 ${unit.name} gin').unit, unit);
      }
    });

    test('tolerates surrounding and repeated whitespace', () {
      expect(
        parseRecipeLine('  1.5   part   bourbon  '),
        const RecipeLine(Amount(1.5), Unit.part, 'bourbon'),
      );
    });

    test('leaves value rules to M5: zero and inverted ranges parse', () {
      expect(parseRecipeLine('0 part gin').amount, const Amount(0));
      expect(
        parseRecipeLine('2-1.5 part gin').amount,
        const Amount.range(2, 1.5),
      );
    });

    test('rejects lines with no amount, or with nothing left to name', () {
      const lines = ['', '   ', 'bourbon', '2 dash', '0.5 part (optional)'];
      for (final line in lines) {
        expect(
          () => parseRecipeLine(line),
          throwsFormatException,
          reason: line,
        );
      }
    });

    test('rejects malformed amounts, naming the value', () {
      const amounts = ['x', '.5', '1.', '1,5', '-1', '1-', '1.5-2-3'];
      for (final amount in amounts) {
        expect(
          () => parseRecipeLine('$amount part gin'),
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
        parseRecipeLine('1 gin'),
        const RecipeLine(Amount(1), Unit.part, 'gin'),
      );
      expect(
        parseRecipeLine('0.75 lemon juice'),
        const RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
      );
      expect(
        parseRecipeLine('1.5-2 bourbon (base)'),
        const RecipeLine(
          Amount.range(1.5, 2),
          Unit.part,
          'bourbon',
          mark: LineMark.base,
        ),
      );
    });

    test('a word that is no unit belongs to the ingredient name', () {
      expect(
        parseRecipeLine('1.5 cup sugar'),
        const RecipeLine(Amount(1.5), Unit.part, 'cup sugar'),
      );
    });

    test('a unit may be written in the plural', () {
      for (final unit in Unit.values) {
        expect(parseRecipeLine('2 ${unit.token}s gin').unit, unit);
      }
      expect(parseRecipeLine('2 dashes bitters').unit, Unit.dash);
      expect(parseRecipeLine('2 pieces lime').unit, Unit.piece);
    });

    test('what it accepts loosely it writes in full', () {
      expect(formatRecipeLine(parseRecipeLine('2 dashes gin')), '2 dash gin');
      expect(formatRecipeLine(parseRecipeLine('1 gin')), '1 part gin');
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
        expect(() => tryParseRecipeLine(line), returnsNormally, reason: line);
      }
    });

    test('returns the line and no problem for a plain valid line', () {
      final parsed = tryParseRecipeLine('0.75 part lemon juice');
      expect(parsed.problem, isNull);
      expect(
        parsed.line,
        const RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
      );
    });

    test('returns the line and no problem for an (optional) valid line', () {
      final parsed = tryParseRecipeLine('0.5 part egg white (optional)');
      expect(parsed.problem, isNull);
      expect(
        parsed.line,
        const RecipeLine(
          Amount(0.5),
          Unit.part,
          'egg white',
          mark: LineMark.optional,
        ),
      );
    });

    test('returns a problem and no line on a shape mismatch', () {
      final parsed = tryParseRecipeLine('bourbon');
      expect(parsed.line, isNull);
      expect(parsed.problem, contains('Expected'));
    });

    test('returns a problem and no line on an invalid amount', () {
      final parsed = tryParseRecipeLine('x part gin');
      expect(parsed.line, isNull);
      expect(parsed.problem, 'Invalid amount: "x"');
    });

    test('returns a problem and no line where a unit is all there is', () {
      final parsed = tryParseRecipeLine('1.5 barspoon');
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
        expect(parseRecipeLine(line), tryParseRecipeLine(line).line);
      }
    });

    test('throws the same message tryParseRecipeLine reports as a problem', () {
      const lines = ['bourbon', 'x part gin', '2 dash', ''];
      for (final line in lines) {
        final problem = tryParseRecipeLine(line).problem!;
        expect(
          () => parseRecipeLine(line),
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
          const RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
        ),
        '0.75 part lemon juice',
      );
    });

    test('drops the trailing .0 from whole numbers', () {
      expect(
        formatRecipeLine(const RecipeLine(Amount(2), Unit.oz, 'gin')),
        '2 oz gin',
      );
    });

    test('formats a range', () {
      expect(
        formatRecipeLine(
          const RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
        ),
        '1.5-2 part bourbon',
      );
    });

    test('appends the (optional) suffix', () {
      expect(
        formatRecipeLine(
          const RecipeLine(
            Amount(0.5),
            Unit.part,
            'egg white',
            mark: LineMark.optional,
          ),
        ),
        '0.5 part egg white (optional)',
      );
    });

    test('appends the (base) suffix', () {
      expect(
        formatRecipeLine(
          const RecipeLine(
            Amount(1.5),
            Unit.part,
            'bourbon',
            mark: LineMark.base,
          ),
        ),
        '1.5 part bourbon (base)',
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
        '1.5-2 part bourbon',
        '0.75 part lemon juice',
        '0.5 part rich demerara syrup',
        '0.5 part egg white (optional)',
        '2 oz rye whiskey (base)',
        '2 oz gin',
        '1 barspoon maraschino liqueur',
        '2 dash angostura bitters',
      ];
      for (final line in lines) {
        expect(formatRecipeLine(parseRecipeLine(line)), line);
      }
    });

    test('lines survive format then parse', () {
      const lines = [
        RecipeLine(Amount(2), Unit.oz, 'gin'),
        RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
        RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
        RecipeLine(
          Amount(0.5),
          Unit.part,
          'egg white',
          mark: LineMark.optional,
        ),
        RecipeLine(Amount(2), Unit.oz, 'rye whiskey', mark: LineMark.base),
        RecipeLine(Amount(1), Unit.drop, 'saline solution'),
      ];
      for (final line in lines) {
        expect(parseRecipeLine(formatRecipeLine(line)), line);
      }
    });

    test('non-canonical input formats to canonical form', () {
      expect(formatRecipeLine(parseRecipeLine('2.0  oz  gin')), '2 oz gin');
      expect(formatRecipeLine(parseRecipeLine('2-2 part gin')), '2 part gin');
      expect(
        formatRecipeLine(parseRecipeLine('01.50 part gin')),
        '1.5 part gin',
      );
    });
  });
}
