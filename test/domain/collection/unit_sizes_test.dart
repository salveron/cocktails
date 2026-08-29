import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('UnitSizes', () {
    test('defaults match the data-format example', () {
      const unitSizes = UnitSizes();
      expect(unitSizes.partMl, 30);
      expect(unitSizes.ozMl, 29.5735);
    });

    test('ml is the anchor the other two are sized against (ADR 17)', () {
      const unitSizes = UnitSizes(partMl: 25, ozMl: 30);
      expect(unitSizes.mlPer(FixedUnit.part), 25);
      expect(unitSizes.mlPer(FixedUnit.ml), 1);
      expect(unitSizes.mlPer(FixedUnit.oz), 30);
    });

    test('ratio derives every pair from the two sizes', () {
      const unitSizes = UnitSizes(partMl: 30, ozMl: 15);
      expect(unitSizes.ratio(FixedUnit.part, FixedUnit.ml), 30);
      expect(unitSizes.ratio(FixedUnit.part, FixedUnit.oz), 2);
      expect(unitSizes.ratio(FixedUnit.oz, FixedUnit.part), 0.5);
      expect(unitSizes.ratio(FixedUnit.ml, FixedUnit.oz), 1 / 15);
      for (final unit in FixedUnit.values) {
        expect(unitSizes.ratio(unit, unit), 1);
      }
    });

    test('withRatio moves the trailing unit, ml having no size', () {
      const unitSizes = UnitSizes(partMl: 30, ozMl: 15);
      // Trailing ml: the leading unit is the only one with a size to take it.
      expect(
        unitSizes.withRatio(FixedUnit.part, FixedUnit.ml, 45),
        const UnitSizes(partMl: 45, ozMl: 15),
      );
      expect(
        unitSizes.withRatio(FixedUnit.oz, FixedUnit.ml, 29.5735),
        const UnitSizes(partMl: 30, ozMl: 29.5735),
      );
      // Neither is ml, so the part stands and the ounce moves under it.
      expect(
        unitSizes.withRatio(FixedUnit.part, FixedUnit.oz, 1),
        const UnitSizes(partMl: 30, ozMl: 30),
      );
      expect(
        unitSizes.withRatio(FixedUnit.oz, FixedUnit.part, 0.5),
        const UnitSizes(partMl: 30, ozMl: 15),
      );
    });

    test('withRatio inverts its own ratio, whichever way round', () {
      const unitSizes = UnitSizes(partMl: 27, ozMl: 29.5735);
      for (final (from, to) in [
        (FixedUnit.part, FixedUnit.ml),
        (FixedUnit.oz, FixedUnit.ml),
        (FixedUnit.part, FixedUnit.oz),
        (FixedUnit.oz, FixedUnit.part),
      ]) {
        final same = unitSizes.withRatio(from, to, unitSizes.ratio(from, to));
        expect(same.partMl, closeTo(unitSizes.partMl, 1e-12));
        expect(same.ozMl, closeTo(unitSizes.ozMl, 1e-12));
      }
    });

    valueEquality(() => const UnitSizes(), const {
      'partMl': UnitSizes(partMl: 22.5),
      'ozMl': UnitSizes(ozMl: 30),
    });

    test('copyWith replaces one field and carries the rest', () {
      const unitSizes = UnitSizes(partMl: 25, ozMl: 30);
      expect(unitSizes.copyWith(), unitSizes, reason: 'nothing named');
      expect(
        unitSizes.copyWith(partMl: 30),
        const UnitSizes(partMl: 30, ozMl: 30),
        reason: 'partMl',
      );
      expect(
        unitSizes.copyWith(ozMl: 29.5735),
        const UnitSizes(partMl: 25),
        reason: 'ozMl',
      );
    });

    // ADR 21: of the sizes the pick alone is the reader's, so it is the one
    // part of it a guest bar's refresh must not be able to replace.
    test('carries no reading unit, that being the bar\'s (ADR 21)', () {
      expect(
        Bar(id: 'a1', name: 'Home bar', mode: BarMode.owner).display,
        FixedUnit.part,
      );
      expect(const UnitSizes().toString(), isNot(contains('display')));
    });
  });
}
