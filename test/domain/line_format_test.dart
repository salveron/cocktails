import 'package:cocktails/domain/line_format.dart';
import 'package:cocktails/domain/model.dart';
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
        const RecipeLine(Amount(0.5), Unit.part, 'egg white', isOptional: true),
      );
    });

    test('without the leading space, (optional) stays in the name', () {
      expect(
        parseRecipeLine('1 part gin(optional)'),
        const RecipeLine(Amount(1), Unit.part, 'gin(optional)'),
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

    test('rejects lines that do not have three parts', () {
      const lines = [
        '',
        '   ',
        'bourbon',
        '1.5 bourbon',
        '0.5 part (optional)',
      ];
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

    test('rejects unknown units, naming the value', () {
      expect(
        () => parseRecipeLine('1.5 cup sugar'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('"cup"'),
          ),
        ),
      );
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
            isOptional: true,
          ),
        ),
        '0.5 part egg white (optional)',
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
        RecipeLine(Amount(0.5), Unit.part, 'egg white', isOptional: true),
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
