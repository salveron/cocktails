import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const codec = YamlCodec();

/// The docs/architecture.md#data-format example, as the emitter writes it.
const canonicalText = '''
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

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: lime juice, tags: [citrus]}
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
      - 0.75 parts lemon juice / lime juice
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
''';

/// The same example verbatim from the doc, comments included.
const commentedText = '''
format: 2
name: Home bar         # the bar's, a label rather than an identity (FR-BAR-1)

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  oz_ml: 29.5735       # and one ounce; ml is the anchor, so it needs none (ADR 17)
  display: part        # part | ml | oz — what the three read in

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: oz}                         # fixed, like the two above (ADR 17)
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}  # also answers to (ADR 10)
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: lime juice, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}   # stock omitted = out
  - {name: egg white, stock: in}                           # untagged

ingredient_tags:                       # what an ingredient can be labelled
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
      - 0.75 parts lemon juice / lime juice   # either one makes it (ADR 11)
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
''';

Collection docCollection() => Collection(
  units: const [
    Unit(partUnit, plural: 'parts'),
    Unit(mlUnit),
    Unit(ozUnit),
    Unit('dash', plural: 'dashes'),
  ],
  ingredients: [
    Ingredient(
      'bourbon',
      stock: StockLevel.in_,
      aliases: const ['bourbon whiskey'],
    ),
    Ingredient('lemon juice', stock: StockLevel.low, tags: const ['citrus']),
    Ingredient('lime juice', tags: const ['citrus']),
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
        RecipeLine(Amount.range(1.5, 2), 'part', [
          'bourbon',
        ], mark: LineMark.base),
        RecipeLine(Amount(0.75), 'part', ['lemon juice', 'lime juice']),
        RecipeLine(Amount(0.5), 'part', ['rich demerara syrup']),
        RecipeLine(Amount(0.5), 'part', ['egg white'], mark: LineMark.optional),
      ],
      notes: 'dry shake, then shake with ice',
    ),
  ],
);

BarPayload payloadOf(String yaml) {
  final result = codec.decode(yaml);
  if (result is Rejected<BarPayload>) {
    fail('expected Ok, got:\n${result.issues.join('\n')}');
  }
  return (result as Ok<BarPayload>).value;
}

Collection decoded(String yaml) => payloadOf(yaml).collection;

/// A collection written as the bar's file — the doc example's name and unit
/// unless a test is about one of the two (ADR 21).
String encoded(
  Collection collection, {
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
}) => codec.encode((name: name, display: display, collection: collection));

List<SourcedIssue> rejected(String yaml) {
  final result = codec.decode(yaml);
  expect(result, isA<Rejected<BarPayload>>(), reason: 'expected Rejected');
  return (result as Rejected<BarPayload>).issues;
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
      expect(encoded(docCollection()), canonicalText);
    });

    test('writes an empty collection with every section present', () {
      expect(encoded(Collection()), '''
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

ingredients: []

ingredient_tags: []

recipe_tags: []

recipes: []
''');
    });

    test('omits entry defaults and empty recipe fields', () {
      final collection = Collection(
        ingredients: [Ingredient('gin')],
        recipes: [Recipe('Nothing Yet')],
      );
      final text = encoded(collection);
      expect(text, contains('\ningredients:\n  - {name: gin}\n'));
      expect(text, contains('\nrecipes:\n  - name: Nothing Yet\n'));
    });

    test('an entry writes the spellings it also answers to (ADR 10)', () {
      final collection = Collection(
        ingredients: [
          Ingredient(
            'bourbon',
            stock: StockLevel.in_,
            aliases: const ['bourbon whiskey', 'bourbon whisky'],
            tags: const ['oaked'],
          ),
        ],
        ingredientTags: const [Tag('oaked', color: TagColor.slate)],
      );
      expect(
        encoded(collection),
        contains(
          '\ningredients:\n'
          '  - {name: bourbon, stock: in, tags: [oaked], '
          'aliases: [bourbon whiskey, bourbon whisky]}\n',
        ),
      );
    });

    test('a tag colour is written even though nothing is default', () {
      final collection = Collection(
        ingredientTags: const [Tag('citrus', color: TagColor.sand)],
        recipeTags: const [Tag('sour', color: TagColor.rose)],
      );
      final text = encoded(collection);
      expect(
        text,
        contains('\ningredient_tags:\n  - {name: citrus, color: sand}\n'),
      );
      expect(text, contains('\nrecipe_tags:\n  - {name: sour, color: rose}\n'));
    });

    test('writes non-default settings', () {
      final collection = Collection(settings: const Settings(partMl: 22.5));
      expect(
        encoded(collection, display: FixedUnit.ml),
        contains(
          'settings:\n  part_ml: 22.5\n  oz_ml: 29.5735\n  display: ml\n',
        ),
      );
    });

    test('quotes scalars YAML would read as other types', () {
      final collection = Collection(
        ingredients: [Ingredient('1976'), Ingredient('true')],
        recipeTags: const [
          Tag('true', color: TagColor.teal),
          Tag('no', color: TagColor.teal),
        ],
      );
      final text = encoded(collection);
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
      final collection = Collection(
        ingredients: [Ingredient('lime, fresh'), Ingredient('rum # dark')],
        recipes: [
          Recipe(
            'gin: a study',
            lines: const [
              RecipeLine(Amount(1), 'oz', ['rum # dark']),
            ],
            notes: 'stir.\nstrain — serve "up"',
          ),
        ],
      );
      final text = encoded(collection);
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
      expect(collection.settings, const Settings(partMl: 25));
    });

    test('a file written before the ounce had a size still reads (ADR 17)', () {
      final payload = payloadOf(
        'format: 1\nsettings:\n  part_ml: 25\n  display: ml\n',
      );
      expect(payload.collection.settings, const Settings(partMl: 25));
      // The pick comes out beside the sizes, not inside them (ADR 21).
      expect(payload.display, FixedUnit.ml);
      expect(payload.collection.settings.ozMl, const Settings().ozMl);
    });

    test('an ounce sized by hand is read and written back', () {
      final payload = payloadOf(
        'format: 1\nsettings:\n  oz_ml: 30\n  display: oz\n',
      );
      expect(payload.collection.settings, const Settings(ozMl: 30));
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

    test('an aliases section that is not a list of strings', () {
      final issues = rejected(
        'format: 1\n'
        'ingredients:\n'
        '  - {name: gin, aliases: genever}\n'
        '  - {name: rum, aliases: [7]}\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedValue,
        'ingredients[0].aliases',
        3,
        messagePart: 'aliases must be a list: "genever"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.malformedValue,
        'ingredients[1].aliases[0]',
        4,
        messagePart: 'Alias must be a string: 7',
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
        messagePart: 'display must be part, ml or oz: "liters"',
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

  // ADR 21: the file carries the bar's name and the reader's unit beside the
  // collection, and says nothing about mode, source, refresh time or id.
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

  // The index is device state rather than an export, written by the same
  // emitter and judged by validateShelf (docs/architecture.md#data-format).
  group('the index', () {
    final home = Bar(id: '5f2c9a', name: 'Home bar', mode: BarMode.owner);
    final guest = Bar(
      id: 'b3e1d7',
      name: 'Home bar',
      mode: BarMode.guest,
      display: FixedUnit.ml,
      refreshed: DateTime.utc(2026, 8, 9, 18, 22, 4),
      source: const BarSource(
        via: Transport.lan,
        at: '_cocktails._tcp/x',
        from: 'Home bar (b3e)',
      ),
    );

    Records indexOf(String yaml) {
      final result = codec.decodeIndex(yaml);
      if (result is Rejected<Records>) {
        fail('expected Ok, got:\n${result.issues.join('\n')}');
      }
      return (result as Ok<Records>).value;
    }

    List<SourcedIssue> indexRejected(String yaml) {
      final result = codec.decodeIndex(yaml);
      expect(result, isA<Rejected<Records>>(), reason: 'expected Rejected');
      return (result as Rejected<Records>).issues;
    }

    test('writes an owner as one line, its absent halves left off', () {
      expect(codec.encodeIndex((bars: [home], openId: home.id)), '''
format: 2
open: 5f2c9a

bars:
  - {id: 5f2c9a, name: Home bar, mode: owner, display: part}
''');
    });

    test('an offer and its guests ride on the record (FR-BAR-6)', () {
      final shared = home.copyWith(
        offers: const [
          (via: Transport.lan, guests: ['ada']),
          (via: Transport.file, guests: []),
        ],
      );
      expect(
        codec.encodeIndex((bars: [shared], openId: null)),
        contains('offers: [{via: lan, guests: [ada]}, {via: file}]'),
      );
    });

    test('a guest carries where it came from and when it answered', () {
      expect(
        codec.encodeIndex((bars: [guest], openId: null)),
        contains(
          'refreshed: "2026-08-09T18:22:04.000Z", '
          'source: {via: lan, at: _cocktails._tcp/x, from: Home bar (b3e)}',
        ),
      );
    });

    test('an owner carries when it changed and what it holds', () {
      final summarised = home.summarised(
        Collection(ingredients: [Ingredient('gin')]),
        at: DateTime.utc(2026, 8, 9, 18, 22, 4),
      );
      expect(
        codec.encodeIndex((bars: [summarised], openId: null)),
        contains(
          'updated: "2026-08-09T18:22:04.000Z", '
          'holds: {recipe: 0, ingredient: 1, tag: 0, '
          'unit: ${defaultUnits.length}}',
        ),
      );
    });

    test('a summary and its stamp survive the round trip', () {
      final counted = [
        home.summarised(
          Collection(recipes: [Recipe('Negroni')]),
          at: DateTime.utc(2026, 8, 9, 18, 22, 4),
        ),
        guest.summarised(Collection()),
      ];
      expect(
        indexOf(codec.encodeIndex((bars: counted, openId: null))).bars,
        counted,
      );
    });

    test('an index written before summaries existed reads as uncounted', () {
      // The one state the reader repairs by counting the bar afresh, so it
      // must survive decoding rather than being refused (ADR 20).
      final records = indexOf(
        'format: 2\n'
        'open: 5f2c9a\n\n'
        'bars:\n'
        '  - {id: 5f2c9a, name: Home bar, mode: owner}\n',
      );
      expect(records.bars.single.holds, isNull);
      expect(records.bars.single.updated, isNull);
    });

    test('a summary missing a kind is dropped, not patched with zeroes', () {
      final records = indexOf(
        'format: 2\n'
        'open: 5f2c9a\n\n'
        'bars:\n'
        '  - {id: 5f2c9a, name: Home bar, mode: owner, '
        'holds: {recipe: 3, ingredient: 4}}\n',
      );
      // A partial count read as a whole one would say the bar holds no tags.
      expect(records.bars.single.holds, isNull);
    });

    test('a count that is not one is refused', () {
      for (final holds in ['{recipe: -1}', '{recipe: many}', 'plenty']) {
        expect(
          indexRejected(
            'format: 2\n'
            'open: 5f2c9a\n\n'
            'bars:\n'
            '  - {id: 5f2c9a, name: Home bar, mode: owner, holds: $holds}\n',
          ),
          isNotEmpty,
          reason: holds,
        );
      }
    });

    test('an owned bar dating a refresh, or a guest an edit, is refused', () {
      for (final entry in [
        'mode: owner, refreshed: "2026-08-09T18:22:04.000Z"',
        'mode: guest, source: {via: file, at: a, from: b}, '
            'updated: "2026-08-09T18:22:04.000Z"',
      ]) {
        expect(
          indexRejected(
            'format: 2\n'
            'open:\n\n'
            'bars:\n'
            '  - {id: 5f2c9a, name: Home bar, $entry}\n',
          ),
          isNotEmpty,
          reason: entry,
        );
      }
    });

    test('two bars of one name are two records (FR-BAR-1)', () {
      final records = indexOf(
        codec.encodeIndex((bars: [home, guest], openId: guest.id)),
      );
      expect(records.bars, [home, guest]);
      expect(records.openId, 'b3e1d7');
    });

    // FR-SET-2, ADR 24: the block is the device's, not the file's — it rides
    // the index and never an export.
    group('what the optimizer is asked', () {
      Bar asking(Shopping shopping) =>
          Bar(id: 'a1', name: 'Ada', mode: BarMode.owner, shopping: shopping);

      test('round-trips whole', () {
        const asked = Shopping(
          aiming: true,
          budget: 3,
          restocking: true,
          most: 50,
          buyingOptional: true,
        );
        final records = indexOf(
          codec.encodeIndex((bars: [asking(asked)], openId: null)),
        );
        expect(records.bars.single.shopping, asked);
      });

      test('is left off entirely while nothing in it has moved', () {
        final written = codec.encodeIndex((
          bars: [asking(const Shopping())],
          openId: null,
        ));
        expect(written, isNot(contains('shopping')));
        expect(indexOf(written).bars.single.shopping, const Shopping());
      });

      test('a record written before it existed reads as the defaults', () {
        final records = indexOf(
          'format: 2\nopen:\n'
          'bars:\n'
          '  - {id: a1, name: Ada, mode: owner}\n',
        );
        expect(records.bars.single.shopping, const Shopping());
      });

      test('a number outside what its screen offers is reported', () {
        final issues = indexRejected(
          'format: 2\nopen:\n'
          'bars:\n'
          '  - {id: a1, name: Ada, mode: owner, shopping: {budget: 7}}\n',
        );
        expect(issues.single.issue.message, contains('Budget must be one of'));
      });
    });

    test('an empty shelf round-trips, open naming nothing', () {
      final records = indexOf(
        codec.encodeIndex((bars: const [], openId: null)),
      );
      expect(records.bars, isEmpty);
      expect(records.openId, isNull);
    });

    test('an index carries the same format number as a bar\'s file', () {
      expect(
        codec.encodeIndex((bars: const [], openId: null)),
        startsWith('format: ${YamlCodec.formatVersion}\n'),
      );
    });

    test('a version it does not read is refused at the gate', () {
      expect(
        indexRejected('format: 9\nbars: []\n').single.issue.kind,
        ValidationIssueKind.unsupportedFormat,
      );
    });

    test('an unknown key is a structural error, as in a bar\'s file', () {
      expect(
        indexRejected('format: 2\nopen:\nbars: []\njunk: 1\n'),
        isNotEmpty,
      );
    });

    // The reason validateShelf takes bars already built (ADR 20): an index
    // this broken must be reported on, never crashed on.
    test('a record its mode forbids is reported, not thrown', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: guest}\n',
      );
      expect(issues.single.issue.message, contains('refreshes from'));
    });

    test('open naming a bar the shelf lacks is reported', () {
      final issues = indexRejected(
        'format: 2\nopen: nothing\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner}\n',
      );
      expect(issues.single.issue.message, contains('open names no bar'));
    });

    test('a duplicate id is reported', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner}\n'
        '  - {id: a1, name: Bea, mode: owner}\n',
      );
      expect(issues.first.issue.message, contains('Duplicate bar id'));
    });

    test('a record missing what every bar needs is reported', () {
      expect(
        indexRejected('format: 2\nopen:\nbars:\n  - {name: Ada}\n'),
        isNotEmpty,
      );
    });

    test('a refresh time that is not a timestamp is reported', () {
      final issues = indexRejected(
        'format: 2\nopen:\n'
        'bars:\n'
        '  - {id: a1, name: Ada, mode: owner, refreshed: soon}\n',
      );
      expect(issues.first.issue.message, contains('timestamp'));
    });

    test('never throws, whatever the input', () {
      for (final input in [
        '',
        'format: 2',
        'format: 2\nbars: 5\n',
        'format: 2\nbars: [1, 2]\n',
        'format: 2\nopen: 5\nbars: []\n',
        'format: 2\nbars:\n  - {id: a1, name: Ada, mode: sideways}\n',
        'format: 2\nbars:\n  - {id: a1, name: Ada, mode: guest, source: 5}\n',
        '- a list\n',
        '\t bad: yaml\n',
      ]) {
        expect(() => codec.decodeIndex(input), returnsNormally, reason: input);
      }
    });
  });

  group('round trip (FR-DAT-5)', () {
    test('encode → decode → encode is the identity on canonical text', () {
      final collection = Collection(
        settings: const Settings(partMl: 22.5),
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
