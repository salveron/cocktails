/// A bar's file read into the parts it carries — its unit vocabulary, its
/// collection, and the owner's name and reader's unit beside them (ADR 21) —
/// and every way a shape or a value in it is refused, each reported at the
/// line a reader can find it on.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  group('units (ADR 09)', () {
    test('a file naming none is read with the ones the app shipped', () {
      expect(decoded('format: 1\n').units, defaultUnits);
    });

    test('a section given replaces them, so a line may lose its unit', () {
      final collection = decoded(
        'format: 1\n'
        'units:\n'
        '  - {name: part, plural: parts}\n'
        '  - {name: ml}\n'
        '  - {name: oz}\n'
        'ingredients:\n'
        '  - {name: gin}\n'
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    lines: [2 part gin]\n',
      );
      expect(collection.units, const [
        Unit('part', plural: 'parts'),
        Unit('ml'),
        Unit('oz'),
      ]);
      final issues = rejected(
        'format: 1\n'
        'units:\n'
        '  - {name: part}\n'
        '  - {name: ml}\n'
        '  - {name: oz}\n'
        'ingredients:\n'
        '  - {name: bitters}\n'
        'recipes:\n'
        '  - name: Dashes\n'
        '    lines: [2 dash bitters]\n',
      );
      // The word no longer measures anything, so it joins the name — and the
      // ingredient "dash bitters" is the one the file has no entry for.
      expectIssue(
        issues.single,
        ValidationIssueKind.unknownIngredient,
        'recipes[0].lines[0]',
        10,
        messagePart: '"dash bitters"',
      );
    });

    test('an empty section is a vocabulary of none', () {
      final issues = rejected('format: 1\nunits: []\n');
      expect(
        issues.map((i) => i.issue.kind),
        everyElement(ValidationIssueKind.missingUnit),
      );
      expect(issues, hasLength(3));
    });

    test('an unknown key on a unit entry', () {
      final issues = rejected(
        'format: 1\nunits:\n  - {name: dash, plurals: dashes}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'units[0].plurals',
        3,
        messagePart: 'Unknown key: "plurals"',
      );
    });

    test('a plural that is not a string', () {
      final issues = rejected(
        'format: 1\nunits:\n  - {name: part, plural: 2}\n',
      );
      expectIssue(
        issues.first,
        ValidationIssueKind.malformedValue,
        'units[0].plural',
        3,
        messagePart: 'plural must be a string',
      );
    });

    test('a unit entry that is not a mapping', () {
      final issues = rejected('format: 1\nunits: [dash]\n');
      expectIssue(
        issues.first,
        ValidationIssueKind.malformedValue,
        'units[0]',
        2,
        messagePart: 'Unit entry must be a mapping',
      );
    });

    test('a vocabulary of one\'s own survives a round trip', () {
      const text =
          'format: 2\n'
          'name: Home bar\n'
          '\n'
          'settings:\n'
          '  part_ml: 30\n'
          '  oz_ml: 29.5735\n'
          '  display: part\n'
          '\n'
          'units:\n'
          '  - {name: part, plural: parts}\n'
          '  - {name: ml}\n'
          '  - {name: oz}\n'
          '  - {name: leaf, plural: leaves}\n'
          '\n'
          'ingredients:\n'
          '  - {name: mint}\n'
          '\n'
          'ingredient_tags: []\n'
          '\n'
          'recipe_tags: []\n'
          '\n'
          'recipes:\n'
          '  - name: Julep\n'
          '    lines:\n'
          '      - 8 leaves mint\n';
      expect(encoded(decoded(text)), text);
    });
  });

  group('decode', () {
    test('reads the doc example, comments included', () {
      expect(decoded(commentedText), docCollection());
    });

    test('a made key is accepted and ignored, whatever it holds (ADR 21)', () {
      const stamps = [
        '{last: 2026-07-18, times: 12}',
        '{last: 2026-02-31}',
        '{times: two, extra: 1}',
        'yesterday',
        '[]',
      ];
      for (final stamp in stamps) {
        final collection = decoded(
          'format: 1\n'
          'ingredients:\n'
          '  - {name: gin}\n'
          'recipes:\n'
          '  - name: Martini\n'
          '    lines: [1 part gin]\n'
          '    made: $stamp\n',
        );
        expect(
          collection.recipeNamed('Martini'),
          Recipe(
            'Martini',
            lines: const [
              RecipeLine(Amount(1), 'part', ['gin']),
            ],
          ),
          reason: stamp,
        );
      }
    });

    test('what a stamped file is written back as carries no made key', () {
      final text = encoded(
        decoded(
          'format: 1\n'
          'ingredients:\n'
          '  - {name: gin}\n'
          'recipes:\n'
          '  - name: Martini\n'
          '    lines: [1 part gin]\n'
          '    made: {last: 2026-07-18, times: 12}\n',
        ),
      );
      expect(text, isNot(contains('made')));
    });

    test('a file of only the format line is the empty collection', () {
      expect(decoded('format: 1\n'), Collection());
    });

    test('absent settings keys keep their defaults', () {
      final collection = decoded('format: 1\nsettings:\n  part_ml: 25\n');
      expect(collection.unitSizes, const UnitSizes(partMl: 25));
    });

    test('a file written before the ounce had a size still reads (ADR 17)', () {
      final payload = payloadOf(
        'format: 1\nsettings:\n  part_ml: 25\n  display: ml\n',
      );
      expect(payload.collection.unitSizes, const UnitSizes(partMl: 25));
      // The pick comes out beside the sizes, not inside them (ADR 21).
      expect(payload.display, FixedUnit.ml);
      expect(payload.collection.unitSizes.ozMl, const UnitSizes().ozMl);
    });

    test('an ounce sized by hand is read and written back', () {
      final payload = payloadOf(
        'format: 1\nsettings:\n  oz_ml: 30\n  display: oz\n',
      );
      expect(payload.collection.unitSizes, const UnitSizes(ozMl: 30));
      expect(payload.display, FixedUnit.oz);
      expect(
        encoded(payload.collection, display: payload.display),
        contains('  oz_ml: 30\n  display: oz\n'),
      );
    });

    test('reads the spellings an ingredient answers to (ADR 10)', () {
      final collection = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: bourbon, aliases: [bourbon whiskey, bourbon whisky]}\n',
      );
      expect(collection.ingredients.single.aliases, [
        'bourbon whiskey',
        'bourbon whisky',
      ]);
      expect(collection.ingredientNamed('bourbon whisky')?.name, 'bourbon');
    });

    test('a hand-edited line naming one is stored canonical', () {
      final collection = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: bourbon, aliases: [whiskey]}\n'
        'recipes:\n'
        '  - name: Old Fashioned\n'
        '    lines: [2 parts whiskey]\n',
      );
      expect(
        collection
            .recipeNamed('Old Fashioned')!
            .lines
            .single
            .ingredients
            .single,
        'bourbon',
      );
    });

    test('never throws, whatever the input', () {
      const inputs = [
        '',
        'a: [',
        '\t',
        '42',
        '- a',
        'format: [1, 2]',
        '!!binary x',
        'a: 1\na: 2',
        '---\na: 1\n---\nb: 2',
      ];
      for (final input in inputs) {
        expect(() => codec.decode(input), returnsNormally, reason: input);
      }
    });
  });

  group('decode reports shape errors with lines', () {
    // One shape throughout: a yaml fragment decodes to a known count of
    // issues, and the one at [index] carries the given kind, location, line
    // and a part of its message (components.md#what-earns-a-test).
    for (final c in [
      (
        description: 'a section that is not a list',
        yaml: 'format: 1\ningredients: 5\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients',
        line: 2,
        messagePart: 'ingredients must be a list: 5',
      ),
      (
        description: 'an ingredient entry that is not a mapping',
        yaml: 'format: 1\ningredients:\n  - gin\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0]',
        line: 3,
        messagePart: 'must be a mapping: "gin"',
      ),
      (
        description: 'a missing name',
        yaml: 'format: 1\ningredients:\n  - {stock: in}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0]',
        line: 3,
        messagePart: 'Missing name',
      ),
      (
        description: 'a name that is not a string',
        yaml: 'format: 1\ningredients:\n  - {name: 1976}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0].name',
        line: 3,
        messagePart: 'name must be a string: 1976',
      ),
      (
        description: 'an ingredient stock outside the allowed words',
        yaml:
            'format: 1\n'
            'ingredients:\n'
            '  - {name: gin, stock: high}\n'
            '  - {name: rum, stock: 7}\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0].stock',
        line: 3,
        messagePart: 'stock must be one of in, low, out: "high"',
      ),
      (
        description: 'a numeric ingredient stock, still at its own line',
        yaml:
            'format: 1\n'
            'ingredients:\n'
            '  - {name: gin, stock: high}\n'
            '  - {name: rum, stock: 7}\n',
        count: 2,
        index: 1,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[1].stock',
        line: 4,
        messagePart: 'stock must be one of in, low, out: 7',
      ),
      (
        description: 'an aliases section that is not a list',
        yaml:
            'format: 1\n'
            'ingredients:\n'
            '  - {name: gin, aliases: genever}\n'
            '  - {name: rum, aliases: [7]}\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0].aliases',
        line: 3,
        messagePart: 'aliases must be a list: "genever"',
      ),
      (
        description: 'an alias that is not a string',
        yaml:
            'format: 1\n'
            'ingredients:\n'
            '  - {name: gin, aliases: genever}\n'
            '  - {name: rum, aliases: [7]}\n',
        count: 2,
        index: 1,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[1].aliases[0]',
        line: 4,
        messagePart: 'Alias must be a string: 7',
      ),
      (
        description: 'an unknown top-level key — a typo would drop content',
        yaml: 'format: 1\nrecipies:\n  - name: X\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipies',
        line: 2,
        messagePart: 'Unknown key: "recipies"',
      ),
      (
        description:
            'the retired ingredient base key — a base is a line mark now',
        yaml: 'format: 1\ningredients:\n  - {name: gin, base: true}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0].base',
        line: 3,
        messagePart: 'Unknown key: "base"',
      ),
      (
        description: 'an unknown entry key',
        yaml: 'format: 1\ningredients:\n  - {name: gin, based: true}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredients[0].based',
        line: 3,
        messagePart: 'Unknown key: "based"',
      ),
      (
        description: 'a tag written the pre-colour way, as a bare name',
        yaml: 'format: 1\nrecipe_tags: [sour, classic]\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipe_tags[0]',
        line: 2,
        messagePart: 'Tag entry must be a mapping: "sour"',
      ),
      (
        description: 'the one tags section from before the split',
        yaml: 'format: 1\ntags: []\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'tags',
        line: 2,
        messagePart: 'Unknown key: "tags"',
      ),
      (
        description: 'a tag entry with no colour at all',
        yaml: 'format: 1\nrecipe_tags:\n  - {name: sour}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipe_tags[0]',
        line: 3,
        messagePart: 'Missing color',
      ),
      (
        description: 'a colour outside the palette names the whole palette',
        yaml: 'format: 1\ningredient_tags:\n  - {name: citrus, color: puce}\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'ingredient_tags[0].color',
        line: 3,
        messagePart:
            'color must be one of teal, indigo, plum, rose, sand, slate: '
            '"puce"',
      ),
      (
        description: 'an unknown tag key',
        yaml: 'format: 1\nrecipe_tags:\n  - {name: sour, colour: rose}\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipe_tags[0].colour',
        line: 3,
        messagePart: 'Unknown key: "colour"',
      ),
      (
        description: 'the unknown tag key costs the colour with it',
        yaml: 'format: 1\nrecipe_tags:\n  - {name: sour, colour: rose}\n',
        count: 2,
        index: 1,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipe_tags[0]',
        line: 3,
        messagePart: 'Missing color',
      ),
      (
        description: 'a recipe line with bad grammar',
        yaml:
            'format: 1\n'
            'recipes:\n'
            '  - name: Martini\n'
            '    lines:\n'
            '      - gin\n'
            '      - 5\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedLine,
        location: 'recipes[0].lines[0]',
        line: 5,
        messagePart: 'Expected "<amount> [unit] <ingredient>": "gin"',
      ),
      (
        description: 'a recipe line that is not a string',
        yaml:
            'format: 1\n'
            'recipes:\n'
            '  - name: Martini\n'
            '    lines:\n'
            '      - gin\n'
            '      - 5\n',
        count: 2,
        index: 1,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipes[0].lines[1]',
        line: 6,
        messagePart: 'Recipe line must be a string: 5',
      ),
      (
        description: 'notes that are not a string',
        yaml: 'format: 1\nrecipes:\n  - name: A\n    notes: [x]\n',
        count: 1,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'recipes[0].notes',
        line: 4,
        messagePart: 'notes must be a string: a list',
      ),
      (
        description: 'a settings value of the wrong type',
        yaml: 'format: 1\nsettings:\n  part_ml: thirty\n  display: liters\n',
        count: 2,
        index: 0,
        kind: ValidationIssueKind.malformedValue,
        location: 'settings.part_ml',
        line: 3,
        messagePart: 'part_ml must be a number: "thirty"',
      ),
      (
        description: 'a settings enum outside its allowed words',
        yaml: 'format: 1\nsettings:\n  part_ml: thirty\n  display: liters\n',
        count: 2,
        index: 1,
        kind: ValidationIssueKind.malformedValue,
        location: 'settings.display',
        line: 4,
        messagePart: 'display must be part, ml or oz: "liters"',
      ),
    ]) {
      test(c.description, () {
        final issues = rejected(c.yaml);
        expect(issues, hasLength(c.count), reason: c.description);
        expectIssue(
          issues[c.index],
          c.kind,
          c.location,
          c.line,
          messagePart: c.messagePart,
        );
      });
    }

    test('shape issues across sections read top-to-bottom', () {
      final issues = rejected(
        'format: 1\n'
        'settings:\n'
        '  part_ml: thirty\n'
        'ingredients:\n'
        '  - {name: 1}\n'
        'ingredient_tags: [2]\n'
        'recipe_tags: [3]\n'
        'recipes:\n'
        '  - 4\n',
      );
      expect(issues.map((issue) => issue.line).toList(), [3, 5, 6, 7, 9]);
      expect(issues.map((issue) => issue.issue.location).toList(), [
        'settings.part_ml',
        'ingredients[0].name',
        'ingredient_tags[0]',
        'recipe_tags[0]',
        'recipes[0]',
      ]);
    });
  });

  group('shape errors reject before value validation', () {
    test('a broken section never cascades into reference errors', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients: 5\n'
        'recipes:\n'
        '  - name: Martini\n'
        '    lines:\n'
        '      - 2 oz gin\n',
      );
      expect(issues, hasLength(1));
      expect(issues.single.issue.location, 'ingredients');
    });
  });

  group('decode reports validation issues with lines', () {
    test('a duplicate name at the line of the second entry', () {
      final issues = rejected(
        'format: 1\ningredients:\n  - {name: gin}\n  - {name: gin}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.duplicateName,
        'ingredients[1]',
        4,
      );
    });

    test('reference and value rules, in file order', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin}\n'
        'recipe_tags:\n'
        '  - {name: classic, color: teal}\n'
        'recipes:\n'
        '  - name: Martini\n'
        '    tags: [sour, classic, classic]\n'
        '    lines:\n'
        '      - 2-1 oz vermouth\n'
        '      - 0 oz gin\n',
      );
      expect(issues, hasLength(5));
      expectIssue(
        issues[0],
        ValidationIssueKind.unknownTag,
        'recipes[0].tags[0]',
        8,
        messagePart: 'Unknown tag: "sour"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.duplicateTag,
        'recipes[0].tags[2]',
        8,
      );
      expectIssue(
        issues[2],
        ValidationIssueKind.unknownIngredient,
        'recipes[0].lines[0]',
        10,
        messagePart: 'Unknown ingredient: "vermouth"',
      );
      expectIssue(
        issues[3],
        ValidationIssueKind.rangeOutOfOrder,
        'recipes[0].lines[0]',
        10,
      );
      expectIssue(
        issues[4],
        ValidationIssueKind.amountNotPositive,
        'recipes[0].lines[1]',
        11,
      );
    });

    test('a non-positive unit size', () {
      final issues = rejected('format: 1\nsettings:\n  part_ml: -5\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.unitSizeNotPositive,
        'settings.part_ml',
        3,
      );
      expectIssue(
        rejected('format: 1\nsettings:\n  oz_ml: 0\n').single,
        ValidationIssueKind.unitSizeNotPositive,
        'settings.oz_ml',
        3,
      );
    });

    test('an ingredient reaching into the other vocabulary', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin, tags: [juniper, juniper]}\n'
        'recipe_tags:\n'
        '  - {name: juniper, color: teal}\n',
      );
      expect(issues, hasLength(3));
      expectIssue(
        issues[0],
        ValidationIssueKind.unknownTag,
        'ingredients[0].tags[0]',
        3,
        messagePart: 'Unknown tag: "juniper"',
      );
      expectIssue(
        issues[2],
        ValidationIssueKind.duplicateTag,
        'ingredients[0].tags[1]',
        3,
        messagePart: 'Duplicate tag on the ingredient: "juniper"',
      );
    });

    test('an empty name at the line of its entry', () {
      final issues = rejected('format: 1\ningredients:\n  - {name: ""}\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.emptyName,
        'ingredients[0]',
        3,
      );
    });
  });

  group('the bar a file carries', () {
    test('the name rides at the top, above the settings', () {
      expect(
        encoded(Collection(), name: 'Ada\'s bar'),
        startsWith('format: 2\nname: Ada\'s bar\n\nsettings:'),
      );
    });

    test('a name YAML would read as something else is quoted', () {
      expect(encoded(Collection(), name: '1976'), contains('name: "1976"\n'));
    });

    test('the pick is written under settings, where a reader looks', () {
      expect(
        encoded(Collection(), display: FixedUnit.oz),
        contains('  oz_ml: 29.5735\n  display: oz\n'),
      );
    });

    test('all three parts come back off a decode', () {
      final payload = payloadOf(encoded(docCollection(), name: 'Ada\'s bar'));
      expect(payload.name, 'Ada\'s bar');
      expect(payload.display, FixedUnit.part);
      expect(payload.collection, docCollection());
    });

    test('the file says nothing the device keeps for itself (ADR 21)', () {
      final text = encoded(docCollection());
      // Neither stamp travels, and a summary counts what the file already
      // carries — so a bar arriving anywhere is counted where it lands.
      for (final key in [
        'mode:',
        'source:',
        'refreshed:',
        'updated:',
        'holds:',
        'id:',
      ]) {
        expect(text, isNot(contains(key)), reason: key);
      }
    });

    test('a format-2 file with no name is refused', () {
      final issues = rejected('format: 2\n');
      expect(issues.first.issue.message, contains('Missing name'));
    });

    test('a format-1 file has no name to carry, and is not asked', () {
      final payload = payloadOf('format: 1\n');
      expect(payload.name, isEmpty);
      expect(payload.collection, Collection());
    });

    test('a format-1 file is written back as 2 (ADR 21)', () {
      final payload = payloadOf(
        'format: 1\nsettings:\n  display: oz\ningredients:\n  - {name: gin}\n',
      );
      final rewritten = encoded(
        payload.collection,
        name: 'Home bar',
        display: payload.display,
      );
      expect(rewritten, startsWith('format: 2\nname: Home bar\n'));
      // Nothing of the old file is lost on the way but the key that left the
      // product with FR-REC-6.
      expect(payloadOf(rewritten).collection, payload.collection);
      expect(payloadOf(rewritten).display, FixedUnit.oz);
    });

    test('a format-1 recipe\'s `made` is ignored, not reported', () {
      final collection = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin}\n'
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    made: 2024-01-01\n'
        '    lines: [1 part gin]\n',
      );
      expect(collection.recipes.single.name, 'Gin Shot');
    });
  });

  // The whole road the tag-chip bug arrives by: an exported file, hand-edited
  // to recase one tag reference, decodes clean and keeps the spelling it was
  // given. What narrows a list has to fold, because the file does not.
  test('a tag reference recased against its vocabulary decodes as written', () {
    final collection = decoded(
      'format: 1\n'
      'ingredients:\n'
      '  - {name: gin}\n'
      'recipe_tags:\n'
      '  - {name: sour, color: teal}\n'
      'recipes:\n'
      '  - name: Martini\n'
      '    tags: [Sour]\n'
      '    lines:\n'
      '      - 2 oz gin\n',
    );
    expect(collection.recipes.single.tags, ['Sour']);
    expect(collection.recipeTags.single.name, 'sour');
  });
}
