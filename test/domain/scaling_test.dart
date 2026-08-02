import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const gin = RecipeLine(Amount(1.5), 'part', ['gin'], mark: LineMark.base);
const bitters = RecipeLine(Amount(2), 'dash', ['bitters']);
const rum = RecipeLine(Amount.range(1.5, 2), 'part', ['white rum']);

const inMl = Settings(display: DisplayUnit.ml);

/// The measure alone — the only half that transforms; a card writes the rest.
String read(
  RecipeLine line, {
  Settings settings = const Settings(),
  List<Unit> units = defaultUnits,
  int scale = 1,
}) => displayMeasure(line, settings, units, scale: scale);

void main() {
  group('displayMeasure', () {
    test('as written, it opens the line the file writes', () {
      for (final line in [gin, bitters, rum]) {
        expect(formatRecipeLine(line, defaultUnits), startsWith(read(line)));
      }
    });

    test('the factor multiplies the amount (FR-REC-7)', () {
      expect(read(gin, scale: 2), '3 parts');
    });

    test('both ends of a range scale together', () {
      expect(read(rum, scale: 4), '6-8 parts');
    });

    test('what is measured in anything else scales too', () {
      expect(read(bitters, scale: 3), '6 dashes');
    });

    test('parts convert at the ratio the settings hold (FR-SET-1)', () {
      expect(read(gin, settings: inMl), '45 ml');
      expect(
        read(
          gin,
          settings: const Settings(partMl: 25, display: DisplayUnit.ml),
        ),
        '37.5 ml',
      );
    });

    test('what is already measured shows as entered', () {
      expect(read(bitters, settings: inMl), '2 dashes');
    });

    test('a card asking for both gets both', () {
      expect(read(rum, settings: inMl, scale: 2), '90-120 ml');
    });

    test('what a binary product loses, rounding gives back', () {
      const saline = RecipeLine(Amount(0.1), 'part', ['saline']);
      expect(read(saline, settings: inMl), '3 ml');
    });

    test('a scaled amount takes the plural the vocabulary spells', () {
      const dash = RecipeLine(Amount(0.5), 'dash', ['absinthe']);
      expect(read(dash), '0.5 dashes');
      expect(read(dash, scale: 2), '1 dash');
    });

    test('the vocabulary spells the conversion too', () {
      const millilitre = [
        Unit(partUnit, plural: 'parts'),
        Unit(mlUnit, plural: 'millilitres'),
      ];
      expect(read(gin, settings: inMl, units: millilitre), '45 millilitres');
    });

    test(
      'it carries the amount and the unit, never the mark or the bottles',
      () {
        expect(read(gin, settings: inMl, scale: 2), '90 ml');
        const group = RecipeLine(Amount(1), 'part', ['cognac', 'vodka']);
        expect(read(group, scale: 3), '3 parts');
      },
    );
  });

  group('scaleFactors', () {
    test('offers the recipe as written and the three FR-REC-7 factors', () {
      expect(scaleFactors, [1, 2, 3, 4]);
    });
  });
}
