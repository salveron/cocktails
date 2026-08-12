import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const gin = RecipeLine(Amount(1.5), 'part', ['gin'], mark: LineMark.base);
const bitters = RecipeLine(Amount(2), 'dash', ['bitters']);
const rum = RecipeLine(Amount.range(1.5, 2), 'part', ['white rum']);

/// The measure alone — the only half that transforms; a card writes the rest.
/// [display] is the bar's pick, which stands beside the sizes rather than in
/// them (ADR 21).
String read(
  RecipeLine line, {
  Settings settings = const Settings(),
  FixedUnit display = FixedUnit.part,
  List<Unit> units = defaultUnits,
  int scale = 1,
}) => displayMeasure(line, settings, display, units, scale: scale);

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
      expect(read(gin, display: FixedUnit.ml), '45 ml');
      expect(
        read(gin, settings: const Settings(partMl: 25), display: FixedUnit.ml),
        '37.5 ml',
      );
    });

    test('what no ratio reaches shows as entered', () {
      expect(read(bitters, display: FixedUnit.ml), '2 dashes');
      expect(read(bitters, display: FixedUnit.oz), '2 dashes');
    });

    test('every fixed unit reads in the one picked (ADR 17)', () {
      // 30 ml a part and 30 ml an ounce, so the three land on round numbers
      // and it is the conversion being read rather than the rounding.
      const round = Settings(ozMl: 30);
      const millilitres = RecipeLine(Amount(60), 'ml', ['gin']);
      const ounces = RecipeLine(Amount(2), 'oz', ['gin']);
      expect(read(millilitres, settings: round, display: FixedUnit.oz), '2 oz');
      expect(read(ounces, settings: round, display: FixedUnit.ml), '60 ml');
      expect(read(ounces, settings: round), '2 parts');
      expect(read(gin, settings: round, display: FixedUnit.oz), '1.5 oz');
    });

    test('the unit picked is the one a line already stands in', () {
      const ounces = RecipeLine(Amount(1.5), 'oz', ['gin']);
      expect(read(ounces, display: FixedUnit.oz), '1.5 oz');
    });

    test('an ounce is what the settings say it is, not what it is', () {
      const ounces = RecipeLine(Amount(1), 'oz', ['gin']);
      expect(read(ounces, display: FixedUnit.ml), '29.57 ml');
      expect(
        read(ounces, settings: const Settings(ozMl: 30), display: FixedUnit.ml),
        '30 ml',
      );
    });

    test('a fixed unit spelled otherwise still converts (ADR 08)', () {
      const ounces = RecipeLine(Amount(2), 'OZ', ['gin']);
      expect(
        read(
          ounces,
          settings: const Settings(ozMl: 30),
          display: FixedUnit.ml,
          units: const [Unit(partUnit), Unit(mlUnit), Unit('OZ')],
        ),
        '60 ml',
      );
    });

    test('a card asking for both gets both', () {
      expect(read(rum, display: FixedUnit.ml, scale: 2), '90-120 ml');
    });

    test('what a binary product loses, rounding gives back', () {
      const saline = RecipeLine(Amount(0.1), 'part', ['saline']);
      expect(read(saline, display: FixedUnit.ml), '3 ml');
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
      expect(
        read(gin, display: FixedUnit.ml, units: millilitre),
        '45 millilitres',
      );
    });

    test(
      'it carries the amount and the unit, never the mark or the bottles',
      () {
        expect(read(gin, display: FixedUnit.ml, scale: 2), '90 ml');
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
