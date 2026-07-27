import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kind = ValidationIssueKind.emptyName;

  group('ValidationIssue', () {
    test('location renders keys and indexes', () {
      expect(
        ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops').location,
        'recipes[0].lines[2]',
      );
      expect(
        ValidationIssue(['settings', 'part_ml'], kind, 'oops').location,
        'settings.part_ml',
      );
    });

    test('an entry-relative issue has an empty location', () {
      expect(ValidationIssue(const [], kind, 'oops').location, '');
    });

    test('toString carries location and message', () {
      expect(
        ValidationIssue(['tags', 1], kind, 'oops').toString(),
        'tags[1]: oops',
      );
    });

    test(
      'equal path values, kind and message are equal, even from separate lists',
      () {
        final a = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
        final b = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
        expect(identical(a.path, b.path), isFalse);
        expect(a, b);
      },
    );

    test('hashCode agrees for equal issues', () {
      final a = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
      final b = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
      expect(a.hashCode, b.hashCode);
    });

    test('differing path is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(ValidationIssue(['recipes', 1], kind, 'oops')),
      );
    });

    test('differing kind is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(
          ValidationIssue(
            ['recipes', 0],
            ValidationIssueKind.duplicateName,
            'oops',
          ),
        ),
      );
    });

    test('differing message is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(ValidationIssue(['recipes', 0], kind, 'other')),
      );
    });
  });

  group('validateModel', () {
    test('empty parts are valid', () {
      expect(validateModel(), isEmpty);
    });

    test('the architecture example is valid', () {
      final issues = validateModel(
        ingredients: [
          const Ingredient('bourbon', isBase: true, stock: StockLevel.in_),
          const Ingredient('lemon juice', stock: StockLevel.low),
          const Ingredient('rich demerara syrup'),
          const Ingredient('egg white', stock: StockLevel.in_),
        ],
        tags: [const Tag('sour'), const Tag('classic')],
        recipes: [
          Recipe(
            'Whiskey Sour',
            tags: ['sour', 'classic'],
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
      expect(issues, isEmpty);
    });

    test('flags a non-positive part_ml', () {
      final issues = validateModel(settings: const Settings(partMl: 0));
      expect(issues, hasLength(1));
      expect(issues.single.path, ['settings', 'part_ml']);
      expect(issues.single.message, contains('positive'));
    });

    test('flags malformed names in every vocabulary', () {
      final issues = validateModel(
        ingredients: [const Ingredient('')],
        tags: [const Tag(' sour')],
        recipes: [Recipe('Old\nFashioned')],
      );
      expect(issues, hasLength(3));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('Empty'));
      expect(issues[1].path, ['tags', 0]);
      expect(issues[1].message, contains('whitespace'));
      expect(issues[2].path, ['recipes', 0]);
      expect(issues[2].message, contains('Line break'));
    });

    test('flags an ingredient name ending with the reserved suffix', () {
      final issues = validateModel(
        ingredients: [const Ingredient('silly (optional)')],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['ingredients', 0]);
      expect(issues.single.message, contains('reserved'));
    });

    test('the reserved suffix rule is ingredient-only', () {
      final issues = validateModel(
        tags: [const Tag('odd (optional)')],
        recipes: [Recipe('Strange (optional)')],
      );
      expect(issues, isEmpty);
    });

    test('flags duplicate names at the repeated position', () {
      final issues = validateModel(
        ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        tags: [const Tag('sour'), const Tag('sour')],
        recipes: [Recipe('Negroni'), Recipe('Negroni')],
      );
      expect(issues, hasLength(3));
      expect(issues[0].path, ['ingredients', 1]);
      expect(issues[0].message, 'Duplicate ingredient name: "gin"');
      expect(issues[1].path, ['tags', 1]);
      expect(issues[2].path, ['recipes', 1]);
    });

    test('flags unknown ingredient and tag references', () {
      final issues = validateModel(
        recipes: [
          Recipe(
            'Negroni',
            tags: ['classic'],
            lines: const [RecipeLine(Amount(1), Unit.part, 'gin')],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['recipes', 0, 'tags', 0]);
      expect(issues[0].message, contains('"classic"'));
      expect(issues[1].path, ['recipes', 0, 'lines', 0]);
      expect(issues[1].message, contains('"gin"'));
    });

    test('flags a tag repeated on one recipe', () {
      final issues = validateModel(
        tags: [const Tag('sour')],
        recipes: [
          Recipe('Daiquiri', tags: ['sour', 'sour']),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'tags', 1]);
      expect(issues.single.message, contains('"sour"'));
    });

    test('flags non-positive and out-of-order amounts', () {
      final issues = validateModel(
        ingredients: [const Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            lines: const [
              RecipeLine(Amount(0), Unit.part, 'gin'),
              RecipeLine(Amount.range(2, 1.5), Unit.part, 'gin'),
            ],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['recipes', 0, 'lines', 0]);
      expect(issues[0].message, contains('positive'));
      expect(issues[1].path, ['recipes', 0, 'lines', 1]);
      expect(issues[1].message, contains('2-1.5'));
    });

    test('flags a times-made count below 1', () {
      final issues = validateModel(
        recipes: [
          Recipe('Negroni', made: MadeHistory(DateTime(2026, 7, 18), 0)),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'made', 'times']);
    });

    test('collects every issue in one pass', () {
      final issues = validateModel(
        settings: const Settings(partMl: -1),
        ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        recipes: [
          Recipe(
            'Negroni',
            lines: const [RecipeLine(Amount(1), Unit.part, 'vermouth')],
          ),
        ],
      );
      expect(issues, hasLength(3));
    });

    test('ordering: ingredient issue before recipe issue', () {
      final issues = validateModel(
        ingredients: [const Ingredient('silly (optional)')],
        recipes: [Recipe('Negroni'), Recipe('Negroni')],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('reserved'));
      expect(issues[1].path, ['recipes', 1]);
      expect(issues[1].message, contains('Duplicate'));
    });

    test('ordering: settings, then ingredients, tags, recipes', () {
      final issues = validateModel(
        settings: const Settings(partMl: 0),
        ingredients: [const Ingredient('silly (optional)')],
        tags: [const Tag('sour'), const Tag('sour')],
        recipes: [Recipe('Negroni'), Recipe('Negroni')],
      );
      expect(issues, hasLength(4));
      expect(issues[0].path, ['settings', 'part_ml']);
      expect(issues[0].message, contains('positive'));
      expect(issues[1].path, ['ingredients', 0]);
      expect(issues[1].message, contains('reserved'));
      expect(issues[2].path, ['tags', 1]);
      expect(issues[2].message, contains('Duplicate'));
      expect(issues[3].path, ['recipes', 1]);
      expect(issues[3].message, contains('Duplicate'));
    });

    test('ordering: within one vocabulary, by entry index', () {
      final issues = validateModel(
        ingredients: [
          const Ingredient('absinthe (optional)'),
          const Ingredient('gin'),
          const Ingredient('gin'),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('reserved'));
      expect(issues[1].path, ['ingredients', 2]);
      expect(issues[1].message, contains('Duplicate'));
    });

    test('ordering: every rule on one entry stays on that entry', () {
      final issues = validateModel(
        ingredients: [const Ingredient(' gin (optional)')],
      );
      expect(issues.map((i) => i.path), [
        ['ingredients', 0],
        ['ingredients', 0],
      ]);
      expect(issues[0].message, contains('whitespace'));
      expect(issues[1].message, contains('reserved'));
    });

    test('ordering: a recipe\'s own issues precede the next recipe\'s', () {
      final issues = validateModel(
        ingredients: [const Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            tags: const ['unknown'],
            lines: const [RecipeLine(Amount(0), Unit.part, 'gin')],
          ),
          Recipe(''),
        ],
      );
      expect(issues.map((i) => i.path), [
        ['recipes', 0, 'tags', 0],
        ['recipes', 0, 'lines', 0],
        ['recipes', 1],
      ]);
    });
  });

  group('validateRecipe', () {
    test('a clean recipe against known vocabularies is valid', () {
      final issues = validateRecipe(
        Recipe(
          'Whiskey Sour',
          tags: const ['sour'],
          lines: const [RecipeLine(Amount(1.5), Unit.part, 'bourbon')],
        ),
        knownIngredients: {'bourbon'},
        knownTags: {'sour'},
      );
      expect(issues, isEmpty);
    });

    test('paths have no recipes[index] prefix', () {
      final issues = validateRecipe(
        Recipe(
          'Martini',
          tags: const ['unknown'],
          lines: const [
            RecipeLine(Amount(1), Unit.part, 'gin'),
            RecipeLine(Amount(1), Unit.part, 'vermouth'),
            RecipeLine(Amount(0), Unit.part, 'missing'),
          ],
          made: MadeHistory(DateTime(2026, 7, 18), 0),
        ),
        knownIngredients: {'gin', 'vermouth'},
        knownTags: const {},
      );
      expect(issues.map((i) => i.path), [
        ['tags', 0],
        ['lines', 2],
        ['lines', 2],
        ['made', 'times'],
      ]);
    });

    test('flags a tag repeated on the recipe, in tag order', () {
      final issues = validateRecipe(
        Recipe('Negroni', tags: const ['sour', 'classic', 'sour']),
        knownIngredients: const {},
        knownTags: {'sour', 'classic'},
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['tags', 2]);
      expect(issues.single.message, contains('Duplicate tag'));
    });

    test('checks the recipe name, at an entry-relative empty path', () {
      final issues = validateRecipe(
        Recipe(''),
        knownIngredients: const {},
        knownTags: const {},
      );
      expect(issues.single.path, isEmpty);
      expect(issues.single.kind, ValidationIssueKind.emptyName);
    });

    test('a name collides with another recipe, never with itself', () {
      expect(
        validateRecipe(
          Recipe('Negroni'),
          knownIngredients: const {},
          knownTags: const {},
          otherRecipeNames: {'Martini'},
        ),
        isEmpty,
      );
      expect(
        validateRecipe(
          Recipe('Negroni'),
          knownIngredients: const {},
          knownTags: const {},
          otherRecipeNames: {'Negroni'},
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });

    test('validateModel prefixes the same issues with recipes[index]', () {
      final recipe = Recipe(
        'Martini',
        tags: const ['unknown'],
        lines: const [RecipeLine(Amount(0), Unit.part, 'missing')],
      );
      final modelIssues = validateModel(recipes: [recipe]);
      final recipeIssues = validateRecipe(
        recipe,
        knownIngredients: const {},
        knownTags: const {},
      );
      expect(modelIssues.map((i) => i.path), [
        ['recipes', 0, 'tags', 0],
        ['recipes', 0, 'lines', 0],
        ['recipes', 0, 'lines', 0],
      ]);
      expect(
        modelIssues.map((i) => i.message).toList(),
        recipeIssues.map((i) => i.message).toList(),
      );
    });
  });

  group('validateIngredient', () {
    test('a clean entry is valid', () {
      expect(validateIngredient(const Ingredient('gin')), isEmpty);
    });

    test('name rules apply, at an entry-relative empty path', () {
      final issues = validateIngredient(const Ingredient(' gin (optional)'));
      expect(issues.map((i) => i.path), [const [], const []]);
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.whitespaceInName,
        ValidationIssueKind.reservedSuffix,
      ]);
    });

    test('a name collides with another entry, never with itself', () {
      expect(
        validateIngredient(
          const Ingredient('gin'),
          otherIngredientNames: {'rum'},
        ),
        isEmpty,
      );
      expect(
        validateIngredient(
          const Ingredient('gin'),
          otherIngredientNames: {'gin'},
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });

    test('reports what validateModel reports for the same entry', () {
      const entry = Ingredient(' gin (optional)');
      expect(
        validateModel(ingredients: [entry]).map((i) => i.message).toList(),
        validateIngredient(entry).map((i) => i.message).toList(),
      );
    });
  });

  group('validateTag', () {
    test('a clean tag is valid', () {
      expect(validateTag(const Tag('sour')), isEmpty);
    });

    test('the reserved suffix is an ingredient rule only', () {
      expect(validateTag(const Tag('sour (optional)')), isEmpty);
    });

    test('a name collides with another entry, never with itself', () {
      expect(
        validateTag(const Tag('sour'), otherTagNames: {'classic'}),
        isEmpty,
      );
      expect(
        validateTag(const Tag('sour'), otherTagNames: {'sour'}).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });
  });

  group('issue kinds', () {
    test('settings, name and duplicate rules', () {
      expect(
        validateModel(settings: const Settings(partMl: 0)).single.kind,
        ValidationIssueKind.partMlNotPositive,
      );
      expect(
        validateModel(ingredients: [const Ingredient('')]).single.kind,
        ValidationIssueKind.emptyName,
      );
      expect(
        validateModel(ingredients: [const Ingredient(' gin')]).single.kind,
        ValidationIssueKind.whitespaceInName,
      );
      expect(
        validateModel(ingredients: [const Ingredient('gin\nrum')]).single.kind,
        ValidationIssueKind.lineBreakInName,
      );
      expect(
        validateModel(
          ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
      expect(
        validateModel(
          ingredients: [const Ingredient('bitters (optional)')],
        ).single.kind,
        ValidationIssueKind.reservedSuffix,
      );
    });

    test('recipe reference and value rules', () {
      final issues = validateRecipe(
        Recipe(
          'Martini',
          tags: const ['unknown', 'unknown'],
          lines: const [
            RecipeLine(Amount(0), Unit.part, 'missing'),
            RecipeLine(Amount.range(2, 1), Unit.part, 'gin'),
          ],
          made: MadeHistory(DateTime(2026, 7, 18), 0),
        ),
        knownIngredients: {'gin'},
        knownTags: const {},
      );
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.unknownTag,
        ValidationIssueKind.unknownTag,
        ValidationIssueKind.duplicateTag,
        ValidationIssueKind.unknownIngredient,
        ValidationIssueKind.amountNotPositive,
        ValidationIssueKind.rangeOutOfOrder,
        ValidationIssueKind.timesBelowOne,
      ]);
    });
  });
}
