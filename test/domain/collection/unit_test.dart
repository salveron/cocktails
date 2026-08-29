import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  tokenVocabulary(
    'FixedUnit',
    values: FixedUnit.values,
    token: (value) => value.token,
    fromToken: FixedUnit.fromToken,
    tokens: const ['part', 'ml', 'oz'],
    unknown: 'litre',
  );

  test(
    'FixedUnit.named finds the fixed unit a spelling stands for (ADR 08)',
    () {
      expect(FixedUnit.named('oz'), FixedUnit.oz);
      expect(FixedUnit.named('OZ'), FixedUnit.oz);
      expect(FixedUnit.named('dash'), isNull);
    },
  );

  group('Unit', () {
    test('the shipped vocabulary matches the data format', () {
      expect(
        [for (final unit in defaultUnits) unit.name],
        ['part', 'ml', 'oz', 'dash', 'barspoon', 'drop', 'piece'],
      );
      expect(
        FixedUnit.values.every(
          (fixed) => defaultUnits.spellings.contains(fixed.token),
        ),
        isTrue,
      );
    });

    test('an unwritten plural reads like the name', () {
      expect(const Unit('ml').pluralName, 'ml');
      expect(const Unit('dash', plural: 'dashes').pluralName, 'dashes');
    });

    test('only exactly one is spelled in the singular', () {
      const leaf = Unit('leaf', plural: 'leaves');
      expect(leaf.spelling(const Amount(1)), 'leaf');
      expect(leaf.spelling(const Amount.range(1, 1)), 'leaf');
      expect(leaf.spelling(const Amount(0.75)), 'leaves');
      expect(leaf.spelling(const Amount.range(1, 2)), 'leaves');
    });

    test('it answers to either spelling, in any case (ADR 08)', () {
      const dash = Unit('dash', plural: 'dashes');
      expect(dash.answersTo('DASH'), isTrue);
      expect(dash.answersTo('Dashes'), isTrue);
      expect(dash.answersTo('dashs'), isFalse);
    });

    valueEquality(() => const Unit('dash'), const {
      'name': Unit('drop'),
      'plural': Unit('dash', plural: 'dashes'),
    });
  });

  group('UnitLookup', () {
    test('finds a unit by either spelling, or by a plural never written', () {
      expect(defaultUnits.unitNamed('dash')?.name, 'dash');
      expect(defaultUnits.unitNamed('dashes')?.name, 'dash');
      expect(defaultUnits.unitNamed('Dashes')?.name, 'dash');
      expect(defaultUnits.unitNamed('ozs')?.name, 'oz');
      expect(defaultUnits.unitNamed('cup'), isNull);
    });

    test('a unit named outright beats another unit\'s stripped guess', () {
      const written = [Unit('dashe'), Unit('dash', plural: 'dashes')];
      expect(written.unitNamed('dashes')?.name, 'dash');
    });

    test('spellings count a plural reading like its name once', () {
      expect(const [Unit('ml')].spellings, ['ml']);
      expect(const [Unit('ml', plural: 'ml')].spellings, ['ml']);
      expect(const [Unit('dash', plural: 'dashes')].spellings, [
        'dash',
        'dashes',
      ]);
    });
  });
}
