import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('Recipe', () {
    Recipe build({
      String name = 'Whiskey Sour',
      List<String> tags = const ['sour'],
      List<RecipeLine> lines = const [
        RecipeLine(Amount.range(1.5, 2), 'part', ['bourbon']),
      ],
      String notes = 'dry shake, then shake with ice',
    }) => Recipe(name, tags: tags, lines: lines, notes: notes);

    test('defaults: no tags, no lines, empty notes', () {
      final recipe = Recipe('Whiskey Sour');
      expect(recipe.tags, isEmpty);
      expect(recipe.lines, isEmpty);
      expect(recipe.notes, isEmpty);
    });

    test('detached from the lists it was built from', () {
      final tags = ['sour'];
      final recipe = Recipe('Whiskey Sour', tags: tags);
      tags.add('classic');
      expect(recipe.tags, ['sour']);
    });

    valueEquality(build, {
      'name': build(name: 'Sazerac'),
      'tags': build(tags: const ['sour', 'classic']),
      'lines': build(
        lines: const [
          RecipeLine(Amount(2), 'part', ['bourbon']),
        ],
      ),
      'notes': build(notes: 'stirred'),
    });

    final recipe = build();
    copyWithContract([
      (
        field: 'nothing named',
        apply: () => recipe.copyWith(),
        expected: recipe,
      ),
      (
        field: 'name',
        apply: () => recipe.copyWith(name: 'Sazerac'),
        expected: build(name: 'Sazerac'),
      ),
      (
        field: 'tags',
        apply: () => recipe.copyWith(tags: ['classic']),
        expected: build(tags: const ['classic']),
      ),
      (
        field: 'lines',
        apply: () => recipe.copyWith(
          lines: [
            const RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
        expected: build(
          lines: const [
            RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
      ),
      (
        field: 'notes',
        apply: () => recipe.copyWith(notes: 'stirred'),
        expected: build(notes: 'stirred'),
      ),
    ]);
  });
}
