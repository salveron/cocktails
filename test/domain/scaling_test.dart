import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const gin = RecipeLine(Amount(1.5), Unit.part, 'gin', mark: LineMark.base);
const bitters = RecipeLine(Amount(2), Unit.dash, 'bitters');
const rum = RecipeLine(Amount.range(1.5, 2), Unit.part, 'white rum');

const inMl = Settings(display: DisplayUnit.ml);

/// The halves put back together, the way the card reads them side by side.
String read(
  RecipeLine line, {
  Settings settings = const Settings(),
  int scale = 1,
}) {
  final shown = displayRecipeLine(line, settings, scale: scale);
  return '${shown.measure} ${shown.body}';
}

void main() {
  group('displayRecipeLine', () {
    test('as written, it reads exactly as the file writes it', () {
      for (final line in [gin, bitters, rum]) {
        expect(read(line), formatRecipeLine(line));
      }
    });

    test('the factor multiplies the amount (FR-REC-7)', () {
      expect(read(gin, scale: 2), '3 part gin (base)');
    });

    test('both ends of a range scale together', () {
      expect(read(rum, scale: 4), '6-8 part white rum');
    });

    test('what is measured in anything else scales too', () {
      expect(read(bitters, scale: 3), '6 dash bitters');
    });

    test('parts convert at the ratio the settings hold (FR-SET-1)', () {
      expect(read(gin, settings: inMl), '45 ml gin (base)');
      expect(
        read(
          gin,
          settings: const Settings(partMl: 25, display: DisplayUnit.ml),
        ),
        '37.5 ml gin (base)',
      );
    });

    test('what is already measured shows as entered', () {
      expect(read(bitters, settings: inMl), '2 dash bitters');
    });

    test('a card asking for both gets both', () {
      expect(read(rum, settings: inMl, scale: 2), '90-120 ml white rum');
    });

    test('what a binary product loses, rounding gives back', () {
      const saline = RecipeLine(Amount(0.1), Unit.part, 'saline');
      expect(read(saline, settings: inMl), '3 ml saline');
    });

    test('the split leaves the mark with what it marks', () {
      final shown = displayRecipeLine(gin, inMl, scale: 2);
      expect(shown.measure, '90 ml');
      expect(shown.body, 'gin (base)');
    });
  });

  group('scaleFactors', () {
    test('offers the recipe as written and the three FR-REC-7 factors', () {
      expect(scaleFactors, [1, 2, 3, 4]);
    });
  });
}
