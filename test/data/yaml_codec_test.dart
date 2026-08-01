import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const codec = YamlCodec();

/// The docs/architecture.md#data-format example, as the emitter writes it.
const canonicalText = '''
format: 1

settings:
  part_ml: 30
  display: part

units:
  - {name: part, plural: parts}
  - {name: ml}
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in}
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}
  - {name: egg white, stock: in}

ingredient_tags:
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
''';

/// The same example verbatim from the doc, comments included.
const commentedText = '''
format: 1

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  display: part        # part | ml

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in}
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}   # stock omitted = out
  - {name: egg white, stock: in}                           # untagged

ingredient_tags:                       # what a bottle can be labelled
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:                           # a separate vocabulary (ADR 07)
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
''';

Model docModel() => Model(
  units: const [
    Unit(partUnit, plural: 'parts'),
    Unit(mlUnit),
    Unit('dash', plural: 'dashes'),
  ],
  ingredients: [
    Ingredient('bourbon', stock: StockLevel.in_),
    Ingredient('lemon juice', stock: StockLevel.low, tags: const ['citrus']),
    Ingredient('rich demerara syrup', tags: const ['syrup', 'homemade']),
    Ingredient('egg white', stock: StockLevel.in_),
  ],
  ingredientTags: const [
    Tag('citrus', color: TagColor.sand),
    Tag('homemade', color: TagColor.slate),
    Tag('syrup', color: TagColor.indigo),
  ],
  recipeTags: const [
    Tag('sour', color: TagColor.rose),
    Tag('classic', color: TagColor.teal),
  ],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(
          Amount.range(1.5, 2),
          'part',
          'bourbon',
          mark: LineMark.base,
        ),
        RecipeLine(Amount(0.75), 'part', 'lemon juice'),
        RecipeLine(Amount(0.5), 'part', 'rich demerara syrup'),
        RecipeLine(Amount(0.5), 'part', 'egg white', mark: LineMark.optional),
      ],
      notes: 'dry shake, then shake with ice',
      made: MadeHistory(DateTime(2026, 7, 18), 12),
    ),
  ],
);

Model decoded(String yaml) {
  final result = codec.decode(yaml);
  if (result is Rejected) {
    fail('expected Decoded, got:\n${result.issues.join('\n')}');
  }
  return (result as Decoded).model;
}

List<SourcedIssue> rejected(String yaml) {
  final result = codec.decode(yaml);
  expect(result, isA<Rejected>(), reason: 'expected Rejected');
  return (result as Rejected).issues;
}

void expectIssue(
  SourcedIssue actual,
  ValidationIssueKind kind,
  String location,
  int? line, {
  String? messagePart,
}) {
  expect(actual.issue.kind, kind, reason: '$actual');
  expect(actual.issue.location, location, reason: '$actual');
  expect(actual.line, line, reason: '$actual');
  if (messagePart != null) {
    expect(actual.issue.message, contains(messagePart), reason: '$actual');
  }
}

void main() {
  group('encode', () {
    test('writes the docs/architecture.md example canonically', () {
      expect(codec.encode(docModel()), canonicalText);
    });

    test('writes an empty model with every section present', () {
      expect(codec.encode(Model()), '''
format: 1

settings:
  part_ml: 30
  display: part

units:
  - {name: part, plural: parts}
  - {name: ml}
  - {name: oz}
  - {name: dash, plural: dashes}
  - {name: barspoon, plural: barspoons}
  - {name: drop, plural: drops}
  - {name: piece, plural: pieces}

ingredients: []

ingredient_tags: []

recipe_tags: []

recipes: []
''');
    });

    test('omits entry defaults and empty recipe fields', () {
      final model = Model(
        ingredients: [Ingredient('gin')],
        recipes: [Recipe('Nothing Yet')],
      );
      final text = codec.encode(model);
      expect(text, contains('\ningredients:\n  - {name: gin}\n'));
      expect(text, contains('\nrecipes:\n  - name: Nothing Yet\n'));
    });

    test('a tag colour is written even though nothing is default', () {
      final model = Model(
        ingredientTags: const [Tag('citrus', color: TagColor.sand)],
        recipeTags: const [Tag('sour', color: TagColor.rose)],
      );
      final text = codec.encode(model);
      expect(
        text,
        contains('\ningredient_tags:\n  - {name: citrus, color: sand}\n'),
      );
      expect(text, contains('\nrecipe_tags:\n  - {name: sour, color: rose}\n'));
    });

    test('writes non-default settings', () {
      final model = Model(
        settings: const Settings(partMl: 22.5, display: DisplayUnit.ml),
      );
      expect(
        codec.encode(model),
        contains('settings:\n  part_ml: 22.5\n  display: ml\n'),
      );
    });

    test('quotes scalars YAML would read as other types', () {
      final model = Model(
        ingredients: [Ingredient('1976'), Ingredient('true')],
        recipeTags: const [
          Tag('true', color: TagColor.teal),
          Tag('no', color: TagColor.teal),
        ],
      );
      final text = codec.encode(model);
      expect(text, contains('- {name: "1976"}'));
      expect(text, contains('- {name: "true"}'));
      expect(
        text,
        contains(
          'recipe_tags:\n  - {name: "true", color: teal}\n'
          '  - {name: no, color: teal}\n',
        ),
      );
    });

    test('quotes structure-breaking text', () {
      final model = Model(
        ingredients: [Ingredient('lime, fresh'), Ingredient('rum # dark')],
        recipes: [
          Recipe(
            'gin: a study',
            lines: const [RecipeLine(Amount(1), 'oz', 'rum # dark')],
            notes: 'stir.\nstrain — serve "up"',
          ),
        ],
      );
      final text = codec.encode(model);
      expect(text, contains('- {name: "lime, fresh"}'));
      expect(text, contains('- name: "gin: a study"'));
      expect(text, contains('- "1 oz rum # dark"'));
      expect(text, contains(r'notes: "stir.\nstrain — serve \"up\""'));
    });
  });

  group('units (ADR 09)', () {
    test('a file naming none is read with the ones the app shipped', () {
      expect(decoded('format: 1\n').units, defaultUnits);
    });

    test('a section given replaces them, so a line may lose its unit', () {
      final model = decoded(
        'format: 1\n'
        'units:\n'
        '  - {name: part, plural: parts}\n'
        '  - {name: ml}\n'
        'ingredients:\n'
        '  - {name: gin}\n'
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    lines: [2 part gin]\n',
      );
      expect(model.units, const [Unit('part', plural: 'parts'), Unit('ml')]);
      final issues = rejected(
        'format: 1\n'
        'units:\n'
        '  - {name: part}\n'
        '  - {name: ml}\n'
        'ingredients:\n'
        '  - {name: bitters}\n'
        'recipes:\n'
        '  - name: Dashes\n'
        '    lines: [2 dash bitters]\n',
      );
      // The word no longer measures anything, so it joins the name — and the
      // bottle "dash bitters" is the one the file has no entry for.
      expectIssue(
        issues.single,
        ValidationIssueKind.unknownIngredient,
        'recipes[0].lines[0]',
        9,
        messagePart: '"dash bitters"',
      );
    });

    test('an empty section is a vocabulary of none', () {
      final issues = rejected('format: 1\nunits: []\n');
      expect(
        issues.map((i) => i.issue.kind),
        everyElement(ValidationIssueKind.missingUnit),
      );
      expect(issues, hasLength(2));
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
          'format: 1\n'
          '\n'
          'settings:\n'
          '  part_ml: 30\n'
          '  display: part\n'
          '\n'
          'units:\n'
          '  - {name: part, plural: parts}\n'
          '  - {name: ml}\n'
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
      expect(codec.encode(decoded(text)), text);
    });
  });

  group('decode', () {
    test('reads the doc example, comments included', () {
      expect(decoded(commentedText), docModel());
    });

    test('a file of only the format line is the empty model', () {
      expect(decoded('format: 1\n'), Model());
    });

    test('absent settings keys keep their defaults', () {
      final model = decoded('format: 1\nsettings:\n  part_ml: 25\n');
      expect(model.settings, const Settings(partMl: 25));
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

    test('rejects an unsupported version before anything else runs', () {
      final issues = rejected('format: 2\njunk: true\n');
      expect(issues, hasLength(1));
      expectIssue(
        issues.single,
        ValidationIssueKind.unsupportedFormat,
        'format',
        1,
        messagePart: 'Unsupported format version 2',
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

  group('decode reports shape errors with lines', () {
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

    test('a section that is not a list', () {
      final issues = rejected('format: 1\ningredients: 5\n');
      expect(issues, hasLength(1));
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients',
        2,
        messagePart: 'ingredients must be a list: 5',
      );
    });

    test('an ingredient entry that is not a mapping', () {
      final issues = rejected('format: 1\ningredients:\n  - gin\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients[0]',
        3,
        messagePart: 'must be a mapping: "gin"',
      );
    });

    test('a missing name', () {
      final issues = rejected('format: 1\ningredients:\n  - {stock: in}\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients[0]',
        3,
        messagePart: 'Missing name',
      );
    });

    test('a name that is not a string', () {
      final issues = rejected('format: 1\ningredients:\n  - {name: 1976}\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients[0].name',
        3,
        messagePart: 'name must be a string: 1976',
      );
    });

    test('bad ingredient field values, each at its own line', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin, stock: high}\n'
        '  - {name: rum, stock: 7}\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedValue,
        'ingredients[0].stock',
        3,
        messagePart: 'stock must be one of in, low, out: "high"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.malformedValue,
        'ingredients[1].stock',
        4,
        messagePart: 'stock must be one of in, low, out: 7',
      );
    });

    test('an unknown top-level key — a typo would drop content', () {
      final issues = rejected('format: 1\nrecipies:\n  - name: X\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'recipies',
        2,
        messagePart: 'Unknown key: "recipies"',
      );
    });

    test('the retired ingredient base key — a base is a line mark now', () {
      final issues = rejected(
        'format: 1\ningredients:\n  - {name: gin, base: true}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients[0].base',
        3,
        messagePart: 'Unknown key: "base"',
      );
    });

    test('an unknown entry key', () {
      final issues = rejected(
        'format: 1\ningredients:\n  - {name: gin, based: true}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredients[0].based',
        3,
        messagePart: 'Unknown key: "based"',
      );
    });

    test('a tag written the pre-colour way, as a bare name', () {
      final issues = rejected('format: 1\nrecipe_tags: [sour, classic]\n');
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedValue,
        'recipe_tags[0]',
        2,
        messagePart: 'Tag entry must be a mapping: "sour"',
      );
    });

    test('the one tags section from before the split', () {
      final issues = rejected('format: 1\ntags: []\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'tags',
        2,
        messagePart: 'Unknown key: "tags"',
      );
    });

    test('a tag entry with no colour at all', () {
      final issues = rejected('format: 1\nrecipe_tags:\n  - {name: sour}\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'recipe_tags[0]',
        3,
        messagePart: 'Missing color',
      );
    });

    test('a colour outside the palette names the whole palette', () {
      final issues = rejected(
        'format: 1\ningredient_tags:\n  - {name: citrus, color: puce}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'ingredient_tags[0].color',
        3,
        messagePart:
            'color must be one of teal, indigo, plum, rose, sand, slate: '
            '"puce"',
      );
    });

    test('an unknown tag key costs the key and the colour with it', () {
      final issues = rejected(
        'format: 1\nrecipe_tags:\n  - {name: sour, colour: rose}\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedValue,
        'recipe_tags[0].colour',
        3,
        messagePart: 'Unknown key: "colour"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.malformedValue,
        'recipe_tags[0]',
        3,
        messagePart: 'Missing color',
      );
    });

    test('recipe lines: bad grammar and a non-string, each at its line', () {
      final issues = rejected(
        'format: 1\n'
        'recipes:\n'
        '  - name: Martini\n'
        '    lines:\n'
        '      - gin\n'
        '      - 5\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedLine,
        'recipes[0].lines[0]',
        5,
        messagePart: 'Expected "<amount> [unit] <ingredient>": "gin"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.malformedValue,
        'recipes[0].lines[1]',
        6,
        messagePart: 'Recipe line must be a string: 5',
      );
    });

    test('made-history problems, each at its own line', () {
      final issues = rejected(
        'format: 1\n'
        'recipes:\n'
        '  - name: A\n'
        '    made: {last: 2026-02-31, times: 2}\n'
        '  - name: B\n'
        '    made: {last: 2026-07-18}\n'
        '  - name: C\n'
        '    made: {last: "2026-07-18T10:00:00", times: 1}\n'
        '  - name: D\n'
        '    made: {times: 2, last: 2026-07-18, extra: 1}\n'
        '  - name: E\n'
        '    made: {last: 2026-07-18, times: two}\n',
      );
      expect(issues, hasLength(5));
      const kind = ValidationIssueKind.malformedValue;
      expectIssue(
        issues[0],
        kind,
        'recipes[0].made.last',
        4,
        messagePart: 'last must be a date (YYYY-MM-DD): "2026-02-31"',
      );
      expectIssue(
        issues[1],
        kind,
        'recipes[1].made',
        6,
        messagePart: 'Missing times',
      );
      expectIssue(issues[2], kind, 'recipes[2].made.last', 8);
      expectIssue(
        issues[3],
        kind,
        'recipes[3].made.extra',
        10,
        messagePart: 'Unknown key: "extra"',
      );
      expectIssue(
        issues[4],
        kind,
        'recipes[4].made.times',
        12,
        messagePart: 'times must be a whole number: "two"',
      );
    });

    test('notes that are not a string', () {
      final issues = rejected(
        'format: 1\nrecipes:\n  - name: A\n    notes: [x]\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'recipes[0].notes',
        4,
        messagePart: 'notes must be a string: a list',
      );
    });

    test('bad settings values', () {
      final issues = rejected(
        'format: 1\nsettings:\n  part_ml: thirty\n  display: liters\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedValue,
        'settings.part_ml',
        3,
        messagePart: 'part_ml must be a number: "thirty"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.malformedValue,
        'settings.display',
        4,
        messagePart: 'display must be part or ml: "liters"',
      );
    });

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

    test('a non-positive part_ml', () {
      final issues = rejected('format: 1\nsettings:\n  part_ml: -5\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.partMlNotPositive,
        'settings.part_ml',
        3,
      );
    });

    test('a times below one', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin}\n'
        'recipes:\n'
        '  - name: A\n'
        '    lines: [1 part gin]\n'
        '    made: {last: 2026-07-18, times: 0}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.timesBelowOne,
        'recipes[0].made.times',
        7,
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

  group('round trip (FR-DAT-5)', () {
    test('encode → decode → encode is the identity on canonical text', () {
      final model = Model(
        settings: const Settings(partMl: 22.5, display: DisplayUnit.ml),
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
              RecipeLine(Amount(1), 'oz', 'rum # dark'),
              RecipeLine(
                Amount.range(1, 2.5),
                'drop',
                'lime, fresh',
                mark: LineMark.optional,
              ),
              RecipeLine(Amount(0.5), 'barspoon', 'crème de violette'),
            ],
            notes: 'stir.\nstrain — serve "up"',
            made: MadeHistory(DateTime(2025, 1, 3), 4),
          ),
          Recipe(
            'Plain',
            lines: const [RecipeLine(Amount(1), 'part', 'bourbon')],
          ),
        ],
      );
      final text = codec.encode(model);
      final reread = decoded(text);
      expect(reread, model);
      expect(codec.encode(reread), text);
    });

    test('the doc example round-trips through its canonical form', () {
      final model = decoded(commentedText);
      expect(codec.encode(model), canonicalText);
      expect(decoded(canonicalText), model);
    });

    test('hand-written input normalises on the first rewrite', () {
      final model = decoded(
        'format: 1\n'
        'ingredients:\n'
        '  - name: gin\n'
        '    stock: in\n'
        '  - name: bitters\n'
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    lines:\n'
        '      - 2.0-2.0 oz gin\n'
        '      - 2 dashes bitters\n'
        '      - 1 GIN\n',
      );
      expect(codec.encode(model), '''
format: 1

settings:
  part_ml: 30
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
  - {name: gin, stock: in}
  - {name: bitters}

ingredient_tags: []

recipe_tags: []

recipes:
  - name: Gin Shot
    lines:
      - 2 oz gin
      - 2 dashes bitters
      - 1 part GIN
''');
    });
  });
}
