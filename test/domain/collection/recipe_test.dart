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

    test('collections are unmodifiable', () {
      final recipe = Recipe('Whiskey Sour', tags: ['sour']);
      expect(() => recipe.tags.add('classic'), throwsUnsupportedError);
      expect(
        () => recipe.lines.add(const RecipeLine(Amount(1), 'part', ['gin'])),
        throwsUnsupportedError,
      );
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

    test('copyWith replaces one field and carries the rest', () {
      final recipe = build();
      expect(recipe.copyWith(), recipe, reason: 'nothing named');
      expect(
        recipe.copyWith(name: 'Sazerac'),
        build(name: 'Sazerac'),
        reason: 'name',
      );
      expect(
        recipe.copyWith(tags: ['classic']),
        build(tags: const ['classic']),
        reason: 'tags',
      );
      expect(
        recipe.copyWith(
          lines: [
            const RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
        build(
          lines: const [
            RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
        reason: 'lines',
      );
      expect(
        recipe.copyWith(notes: 'stirred'),
        build(notes: 'stirred'),
        reason: 'notes',
      );
    });
  });
}
