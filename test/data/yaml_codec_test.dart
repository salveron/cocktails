/// The codec itself: the format gate it keeps before anything else runs, the
/// YAML parse it either gets a tree from or refuses whole, and the round trip
/// that holds emitter and reader to each other.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  group('format gate', () {
    test('rejects a missing format version and reads nothing else', () {
      final issues = rejected('ingredients: 5\n');
      expect(issues, hasLength(1));
      expectIssue(
        issues.single,
        ValidationIssueKind.unsupportedFormat,
        'format',
        1,
        messagePart: 'Missing format version',
      );
    });

    test('rejects a version past this one before anything else runs', () {
      final issues = rejected('format: 3\njunk: true\n');
      expect(issues, hasLength(1));
      expectIssue(
        issues.single,
        ValidationIssueKind.unsupportedFormat,
        'format',
        1,
        messagePart: 'Unsupported format version 3',
      );
    });

    // Nothing was ever written as format 0, but the gate reads a range now and
    // both its ends have to hold (ADR 21).
    test('rejects a version below the oldest it reads', () {
      final issues = rejected('format: 0\n');
      expect(issues, hasLength(1));
      expectIssue(
        issues.single,
        ValidationIssueKind.unsupportedFormat,
        'format',
        1,
        messagePart: 'Unsupported format version 0',
      );
    });

    test('rejects a non-integer version', () {
      for (final value in ['"1"', '1.0', 'one']) {
        final issues = rejected('format: $value\n');
        expect(issues, hasLength(1), reason: value);
        expectIssue(
          issues.single,
          ValidationIssueKind.unsupportedFormat,
          'format',
          1,
          messagePart: 'format must be an integer',
        );
      }
    });
  });

  group('the parse itself', () {
    test('text that is not YAML at all', () {
      final issues = rejected('a: [1\n');
      expect(issues, hasLength(1));
      expect(issues.single.issue.kind, ValidationIssueKind.malformedValue);
      expect(issues.single.issue.message, contains('Not valid YAML'));
    });

    test('duplicate YAML keys', () {
      final issues = rejected(
        'format: 1\nrecipe_tags: [a]\nrecipe_tags: [b]\n',
      );
      expect(issues.single.issue.message, contains('Not valid YAML'));
    });

    test('a top level that is not a mapping', () {
      for (final input in ['', '42\n', '- a\n']) {
        final issues = rejected(input);
        expect(issues, hasLength(1), reason: input);
        expectIssue(
          issues.single,
          ValidationIssueKind.malformedValue,
          '',
          1,
          messagePart: 'top level must be a mapping',
        );
      }
    });
  });

  group('round trip (FR-DAT-5)', () {
    test('encode → decode → encode is the identity on canonical text', () {
      final collection = Collection(
        unitSizes: const UnitSizes(partMl: 22.5),
        ingredients: [
          Ingredient('bourbon', stock: StockLevel.in_),
          Ingredient('true', tags: const ['no']),
          Ingredient('1976', stock: StockLevel.low),
          Ingredient(
            'lime, fresh',
            stock: StockLevel.in_,
            tags: const ['citrus, fresh', 'no'],
          ),
          Ingredient('rum # dark', stock: StockLevel.in_),
          Ingredient('crème de violette'),
        ],
        // "no" stands in both vocabularies, in different colours: the same
        // name means two things, which is what the split is for.
        ingredientTags: const [
          Tag('citrus, fresh', color: TagColor.sand),
          Tag('no', color: TagColor.slate),
        ],
        recipeTags: const [
          Tag('sour', color: TagColor.rose),
          Tag('no', color: TagColor.indigo),
          Tag('1976', color: TagColor.plum),
        ],
        recipes: [
          Recipe(
            'gin: a study',
            tags: const ['no', '1976'],
            lines: const [
              RecipeLine(Amount(1), 'oz', ['rum # dark']),
              RecipeLine(Amount.range(1, 2.5), 'drop', [
                'lime, fresh',
              ], mark: LineMark.optional),
              RecipeLine(Amount(0.5), 'barspoon', ['crème de violette']),
              RecipeLine(Amount(2), 'part', ['bourbon', 'rum # dark']),
            ],
            notes: 'stir.\nstrain — serve "up"',
          ),
          Recipe(
            'Plain',
            lines: const [
              RecipeLine(Amount(1), 'part', ['bourbon']),
            ],
          ),
        ],
      );
      final text = encoded(collection);
      final reread = decoded(text);
      expect(reread, collection);
      expect(encoded(reread), text);
    });

    test('the doc example round-trips through its canonical form', () {
      final collection = decoded(commentedText);
      expect(encoded(collection), canonicalText);
      expect(decoded(canonicalText), collection);
    });

    test('a substitution group is written and read back whole (ADR 11)', () {
      final collection = Collection(
        ingredients: [Ingredient('cognac'), Ingredient('vodka')],
        recipes: [
          Recipe(
            'Sidecar',
            lines: const [
              RecipeLine(Amount(1), 'part', [
                'cognac',
                'vodka',
              ], mark: LineMark.base),
            ],
          ),
        ],
      );
      final text = encoded(collection);
      expect(text, contains('      - 1 part cognac / vodka (base)\n'));
      expect(decoded(text), collection);
      expect(encoded(decoded(text)), text);
    });

    test('a hand-written group normalises its spacing on the rewrite', () {
      final collection = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - name: cognac\n'
        '  - name: vodka\n'
        'recipes:\n'
        '  - name: Sidecar\n'
        '    lines:\n'
        '      - 1 cognac/vodka\n',
      );
      expect(encoded(collection), contains('      - 1 part cognac / vodka\n'));
    });

    test('hand-written input normalises on the first rewrite', () {
      final collection = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - name: gin\n'
        '    stock: in\n'
        '    aliases: [genever]\n'
        '  - name: bitters\n'
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    lines:\n'
        '      - 2.0-2.0 oz genever\n'
        '      - 2 dashes bitters\n'
        '      - 1 GIN\n',
      );
      expect(encoded(collection), '''
format: 2
name: Home bar

settings:
  part_ml: 30
  oz_ml: 29.5735
  display: part

units:
  - {name: part, plural: parts}
  - {name: ml}
  - {name: oz}
  - {name: dash, plural: dashes}
  - {name: barspoon, plural: barspoons}
  - {name: drop, plural: drops}
  - {name: piece, plural: pieces}

ingredients:
  - {name: gin, stock: in, aliases: [genever]}
  - {name: bitters}

ingredient_tags: []

recipe_tags: []

recipes:
  - name: Gin Shot
    lines:
      - 2 oz gin
      - 2 dashes bitters
      - 1 part gin
''');
    });
  });
}
