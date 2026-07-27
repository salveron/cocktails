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

ingredients:
  - {name: bourbon, base: true, stock: in}
  - {name: lemon juice, stock: low}
  - {name: rich demerara syrup}
  - {name: egg white, stock: in}

tags: [sour, classic]

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 part bourbon
      - 0.75 part lemon juice
      - 0.5 part rich demerara syrup
      - 0.5 part egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
''';

/// The same example verbatim from the doc, comments included.
const commentedText = '''
format: 1

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  display: part        # part | ml

ingredients:
  - {name: bourbon, base: true, stock: in}
  - {name: lemon juice, stock: low}
  - {name: rich demerara syrup}        # stock omitted = out
  - {name: egg white, stock: in}

tags: [sour, classic]

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 part bourbon
      - 0.75 part lemon juice
      - 0.5 part rich demerara syrup
      - 0.5 part egg white (optional)
    notes: dry shake, then shake with ice
    made: {last: 2026-07-18, times: 12}
''';

Model docModel() => Model(
  ingredients: const [
    Ingredient('bourbon', isBase: true, stock: StockLevel.in_),
    Ingredient('lemon juice', stock: StockLevel.low),
    Ingredient('rich demerara syrup'),
    Ingredient('egg white', stock: StockLevel.in_),
  ],
  tags: const [Tag('sour'), Tag('classic')],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
        RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
        RecipeLine(Amount(0.5), Unit.part, 'rich demerara syrup'),
        RecipeLine(Amount(0.5), Unit.part, 'egg white', isOptional: true),
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

ingredients: []

tags: []

recipes: []
''');
    });

    test('omits entry defaults and empty recipe fields', () {
      final model = Model(
        ingredients: const [Ingredient('gin')],
        recipes: [Recipe('Nothing Yet')],
      );
      final text = codec.encode(model);
      expect(text, contains('\ningredients:\n  - {name: gin}\n'));
      expect(text, contains('\nrecipes:\n  - name: Nothing Yet\n'));
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
        ingredients: const [Ingredient('1976'), Ingredient('true')],
        tags: const [Tag('true'), Tag('no')],
      );
      final text = codec.encode(model);
      expect(text, contains('- {name: "1976"}'));
      expect(text, contains('- {name: "true"}'));
      expect(text, contains('tags: ["true", no]'));
    });

    test('quotes structure-breaking text', () {
      final model = Model(
        ingredients: const [
          Ingredient('lime, fresh'),
          Ingredient('rum # dark'),
        ],
        recipes: [
          Recipe(
            'gin: a study',
            lines: const [RecipeLine(Amount(1), Unit.oz, 'rum # dark')],
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
      final issues = rejected('format: 1\ntags: [a]\ntags: [b]\n');
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
      final issues = rejected('format: 1\ningredients:\n  - {base: true}\n');
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
        '  - {name: rum, base: yes}\n',
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
        'ingredients[1].base',
        4,
        messagePart: 'base must be true or false: "yes"',
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

    test('a tag that is not a string', () {
      final issues = rejected('format: 1\ntags: [sour, 1976]\n');
      expectIssue(
        issues.single,
        ValidationIssueKind.malformedValue,
        'tags[1]',
        2,
        messagePart: 'Tag must be a string: 1976',
      );
    });

    test('recipe lines: bad grammar and a non-string, each at its line', () {
      final issues = rejected(
        'format: 1\n'
        'recipes:\n'
        '  - name: Martini\n'
        '    lines:\n'
        '      - 2 cups gin\n'
        '      - 5\n',
      );
      expect(issues, hasLength(2));
      expectIssue(
        issues[0],
        ValidationIssueKind.malformedLine,
        'recipes[0].lines[0]',
        5,
        messagePart: 'Unknown unit: "cups"',
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
        'tags: [2]\n'
        'recipes:\n'
        '  - 3\n',
      );
      expect(issues.map((issue) => issue.line).toList(), [3, 5, 6, 8]);
      expect(issues.map((issue) => issue.issue.location).toList(), [
        'settings.part_ml',
        'ingredients[0].name',
        'tags[0]',
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
        'tags: [classic]\n'
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
        7,
        messagePart: 'Unknown tag: "sour"',
      );
      expectIssue(
        issues[1],
        ValidationIssueKind.duplicateTag,
        'recipes[0].tags[2]',
        7,
      );
      expectIssue(
        issues[2],
        ValidationIssueKind.unknownIngredient,
        'recipes[0].lines[0]',
        9,
        messagePart: 'Unknown ingredient: "vermouth"',
      );
      expectIssue(
        issues[3],
        ValidationIssueKind.rangeOutOfOrder,
        'recipes[0].lines[0]',
        9,
      );
      expectIssue(
        issues[4],
        ValidationIssueKind.amountNotPositive,
        'recipes[0].lines[1]',
        10,
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
        'recipes:\n'
        '  - name: A\n'
        '    made: {last: 2026-07-18, times: 0}\n',
      );
      expectIssue(
        issues.single,
        ValidationIssueKind.timesBelowOne,
        'recipes[0].made.times',
        4,
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
        ingredients: const [
          Ingredient('bourbon', isBase: true, stock: StockLevel.in_),
          Ingredient('true'),
          Ingredient('1976', stock: StockLevel.low),
          Ingredient('lime, fresh', stock: StockLevel.in_),
          Ingredient('rum # dark', stock: StockLevel.in_),
          Ingredient('crème de violette'),
        ],
        tags: const [Tag('sour'), Tag('no'), Tag('1976')],
        recipes: [
          Recipe(
            'gin: a study',
            tags: const ['no', '1976'],
            lines: const [
              RecipeLine(Amount(1), Unit.oz, 'rum # dark'),
              RecipeLine(
                Amount.range(1, 2.5),
                Unit.drop,
                'lime, fresh',
                isOptional: true,
              ),
              RecipeLine(Amount(0.5), Unit.barspoon, 'crème de violette'),
            ],
            notes: 'stir.\nstrain — serve "up"',
            made: MadeHistory(DateTime(2025, 1, 3), 4),
          ),
          Recipe('Plain'),
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
        'recipes:\n'
        '  - name: Gin Shot\n'
        '    lines:\n'
        '      - 2.0-2.0 oz gin\n',
      );
      expect(codec.encode(model), '''
format: 1

settings:
  part_ml: 30
  display: part

ingredients:
  - {name: gin, stock: in}

tags: []

recipes:
  - name: Gin Shot
    lines:
      - 2 oz gin
''');
    });
  });
}
