import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// The required line every recipe now needs (FR-REC-2), so a fixture about
/// some other rule does not trip that one. Its bottle is declared alongside.
const _gin = RecipeLine(Amount(1), 'part', ['gin']);

/// The spellings a line may measure in, as a recipe check asks for them.
final shippedUnits = defaultUnits.spellings.toSet();

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

  group('units', () {
    test('the shipped vocabulary is valid', () {
      expect(validateCollection(units: defaultUnits), isEmpty);
    });

    test('a line measured in nothing the vocabulary holds is reported', () {
      final issues = validateCollection(
        units: const [Unit(partUnit), Unit(mlUnit), Unit(ozUnit)],
        ingredients: [Ingredient('bitters')],
        recipes: [
          Recipe(
            'Dashes',
            lines: const [
              RecipeLine(Amount(2), 'dash', ['bitters']),
            ],
          ),
        ],
      );
      expect(issues.single.kind, ValidationIssueKind.unknownUnit);
      expect(issues.single.path, ['recipes', 0, 'lines', 0]);
      expect(issues.single.message, contains('"dash"'));
    });

    test('the three units the app leans on must be there', () {
      final issues = validateCollection(units: const [Unit('dash')]);
      expect(issues.map((i) => i.message), [
        'units must include "part"',
        'units must include "ml"',
        'units must include "oz"',
      ]);
      expect(issues.first.kind, ValidationIssueKind.missingUnit);
      expect(issues.first.path, ['units']);
    });

    test('a spelling another unit answers to is a duplicate', () {
      final issues = validateCollection(
        units: const [
          Unit(partUnit, plural: 'parts'),
          Unit(mlUnit),
          Unit(ozUnit),
          Unit('dash', plural: 'parts'),
        ],
      );
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
      expect(issues.single.path, ['units', 3, 'plural']);
      expect(issues.single.message, contains('"parts"'));
    });

    test('a plural written out as its own name is no duplicate', () {
      expect(
        validateCollection(
          units: const [
            Unit(partUnit),
            Unit(mlUnit, plural: 'ml'),
            Unit(ozUnit),
          ],
        ),
        isEmpty,
      );
    });

    test('both spellings answer to the name rules', () {
      final issues = validateCollection(
        units: const [
          Unit(partUnit),
          Unit(mlUnit),
          Unit(ozUnit),
          Unit(' tsp'),
          Unit('dash', plural: 'dashes '),
        ],
      );
      expect(issues.map((i) => i.path), [
        ['units', 3],
        ['units', 4, 'plural'],
      ]);
      expect(
        issues.every((i) => i.kind == ValidationIssueKind.whitespaceInName),
        isTrue,
      );
    });
  });

  group('validateCollection', () {
    test('empty parts are valid', () {
      expect(validateCollection(), isEmpty);
    });

    test('the architecture example is valid', () {
      final issues = validateCollection(
        ingredients: [
          Ingredient('bourbon', stock: StockLevel.in_),
          Ingredient('lemon juice', stock: StockLevel.low),
          Ingredient('rich demerara syrup'),
          Ingredient('egg white', stock: StockLevel.in_),
        ],
        recipeTags: [
          const Tag('sour', color: TagColor.rose),
          const Tag('classic', color: TagColor.rose),
        ],
        recipes: [
          Recipe(
            'Whiskey Sour',
            tags: ['sour', 'classic'],
            lines: const [
              RecipeLine(Amount.range(1.5, 2), 'part', [
                'bourbon',
              ], mark: LineMark.base),
              RecipeLine(Amount(0.75), 'part', ['lemon juice']),
              RecipeLine(Amount(0.5), 'part', ['rich demerara syrup']),
              RecipeLine(Amount(0.5), 'part', [
                'egg white',
              ], mark: LineMark.optional),
            ],
            notes: 'dry shake, then shake with ice',
          ),
        ],
      );
      expect(issues, isEmpty);
    });

    test('flags a non-positive unit size, at the size it is', () {
      // Every size a ratio is derived from is judged the same way (ADR 17).
      for (final (settings, path) in [
        (const Settings(partMl: 0), ['settings', 'part_ml']),
        (const Settings(ozMl: -1), ['settings', 'oz_ml']),
      ]) {
        final issues = validateCollection(settings: settings);
        expect(issues, hasLength(1), reason: '$path');
        expect(issues.single.path, path);
        expect(issues.single.kind, ValidationIssueKind.unitSizeNotPositive);
        expect(issues.single.message, contains('positive'));
      }
    });

    test('flags malformed names in every vocabulary', () {
      final issues = validateCollection(
        ingredients: [Ingredient(''), Ingredient('gin')],
        ingredientTags: [const Tag(' citrus', color: TagColor.sand)],
        recipeTags: [const Tag(' sour', color: TagColor.rose)],
        recipes: [
          Recipe('Old\nFashioned', lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(4));
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.emptyName,
        ValidationIssueKind.whitespaceInName,
        ValidationIssueKind.whitespaceInName,
        ValidationIssueKind.lineBreakInName,
      ]);
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('Empty'));
      expect(issues[1].path, ['ingredient_tags', 0]);
      expect(
        issues[1].message,
        'Surrounding whitespace in ingredient tag name: " citrus"',
      );
      expect(issues[2].path, ['recipe_tags', 0]);
      expect(issues[2].message, contains('whitespace'));
      expect(issues[3].path, ['recipes', 0]);
      expect(issues[3].message, contains('Line break'));
    });

    test('flags an ingredient name ending with a reserved suffix', () {
      for (final name in ['silly (optional)', 'silly (base)']) {
        final issues = validateCollection(ingredients: [Ingredient(name)]);
        expect(issues, hasLength(1), reason: name);
        expect(issues.single.path, ['ingredients', 0]);
        expect(issues.single.kind, ValidationIssueKind.reservedSuffix);
        expect(issues.single.message, contains('reserved'));
      }
    });

    test('flags a slash in an ingredient name (ADR 11)', () {
      final issues = validateCollection(
        ingredients: [Ingredient('sweet / dry vermouth')],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['ingredients', 0]);
      expect(issues.single.kind, ValidationIssueKind.separatorInName);
      expect(
        issues.single.message,
        'Ingredient name holds the reserved "/" separator: '
        '"sweet / dry vermouth"',
      );
    });

    test('flags a slash in an alias too, spaced or not', () {
      for (final alias in ['sweet/dry', 'sweet / dry']) {
        final issues = validateCollection(
          ingredients: [
            Ingredient('vermouth', aliases: [alias]),
          ],
        );
        expect(issues, hasLength(1), reason: alias);
        expect(issues.single.path, ['ingredients', 0, 'aliases', 0]);
        expect(issues.single.kind, ValidationIssueKind.separatorInName);
      }
    });

    test('the slash rule is ingredient-only: it splits nothing else', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin')],
        recipeTags: [const Tag('half/half', color: TagColor.rose)],
        recipes: [
          Recipe('Sour / Fizz', tags: const ['half/half'], lines: const [_gin]),
        ],
      );
      expect(issues, isEmpty);
    });

    test('the reserved suffix rule is ingredient-only', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin')],
        recipeTags: [const Tag('odd (optional)', color: TagColor.rose)],
        recipes: [
          Recipe('Strange (optional)', lines: const [_gin]),
        ],
      );
      expect(issues, isEmpty);
    });

    test('flags duplicate names at the repeated position', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin'), Ingredient('gin')],
        ingredientTags: [
          const Tag('citrus', color: TagColor.sand),
          const Tag('citrus', color: TagColor.teal),
        ],
        recipeTags: [
          const Tag('sour', color: TagColor.rose),
          const Tag('sour', color: TagColor.rose),
        ],
        recipes: [
          Recipe('Negroni', lines: const [_gin]),
          Recipe('Negroni', lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(4));
      expect(
        issues.every((i) => i.kind == ValidationIssueKind.duplicateName),
        isTrue,
      );
      expect(issues[0].path, ['ingredients', 1]);
      expect(issues[0].message, 'Duplicate ingredient name: "gin"');
      expect(issues[1].path, ['ingredient_tags', 1]);
      expect(issues[1].message, 'Duplicate ingredient tag name: "citrus"');
      expect(issues[2].path, ['recipe_tags', 1]);
      expect(issues[2].message, 'Duplicate recipe tag name: "sour"');
      expect(issues[3].path, ['recipes', 1]);
    });

    test('two spellings of one name are a duplicate (ADR 08)', () {
      final issues = validateCollection(
        ingredients: [Ingredient('Gin'), Ingredient('gin')],
      );
      expect(issues.single.path, ['ingredients', 1]);
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
    });

    test('a name in both vocabularies at once is no duplicate', () {
      expect(
        validateCollection(
          ingredientTags: [const Tag('sour', color: TagColor.sand)],
          recipeTags: [const Tag('sour', color: TagColor.rose)],
        ),
        isEmpty,
      );
    });

    test(
      'an alias is a spelling of the vocabulary, at its own path (ADR 10)',
      () {
        final issues = validateCollection(
          ingredients: [
            Ingredient('bourbon', aliases: const ['rye']),
            Ingredient('gin', aliases: const ['Rye', 'bourbon']),
          ],
        );
        expect(issues.map((i) => i.path), [
          ['ingredients', 1, 'aliases', 0],
          ['ingredients', 1, 'aliases', 1],
        ]);
        expect(issues[0].message, 'Duplicate ingredient name: "Rye"');
        expect(issues[1].message, 'Duplicate ingredient name: "bourbon"');
      },
    );

    test('a name repeating an earlier alias reports on the name', () {
      final issues = validateCollection(
        ingredients: [
          Ingredient('bourbon', aliases: const ['rye']),
          Ingredient('rye'),
        ],
      );
      expect(issues.single.path, ['ingredients', 1]);
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
    });

    test('a line may name a bottle by an alias', () {
      expect(
        validateCollection(
          ingredients: [
            Ingredient('bourbon', aliases: const ['whiskey']),
          ],
          recipes: [
            Recipe(
              'Old Fashioned',
              lines: const [
                RecipeLine(Amount(2), 'part', ['whiskey']),
              ],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('flags unknown ingredient and tag references', () {
      final issues = validateCollection(
        recipes: [
          Recipe(
            'Negroni',
            tags: ['classic'],
            lines: const [
              RecipeLine(Amount(1), 'part', ['gin']),
            ],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.unknownTag,
        ValidationIssueKind.unknownIngredient,
      ]);
      expect(issues[0].path, ['recipes', 0, 'tags', 0]);
      expect(issues[0].message, contains('"classic"'));
      expect(issues[1].path, ['recipes', 0, 'lines', 0]);
      expect(issues[1].message, contains('"gin"'));
    });

    test('flags a tag repeated on one recipe', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin')],
        recipeTags: [const Tag('sour', color: TagColor.rose)],
        recipes: [
          Recipe('Daiquiri', tags: ['sour', 'sour'], lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'tags', 1]);
      expect(issues.single.kind, ValidationIssueKind.duplicateTag);
      expect(issues.single.message, contains('"sour"'));
    });

    test('flags a recipe with nothing required, at its lines', () {
      for (final lines in [
        const <RecipeLine>[],
        const [
          RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.optional),
        ],
      ]) {
        final issues = validateCollection(
          ingredients: [Ingredient('gin')],
          recipes: [Recipe('Negroni', lines: lines)],
        );
        expect(issues.single.path, ['recipes', 0, 'lines'], reason: '$lines');
        expect(issues.single.kind, ValidationIssueKind.noRequiredLine);
      }
    });

    test('a base line is a required line', () {
      expect(
        validateCollection(
          ingredients: [Ingredient('gin')],
          recipes: [
            Recipe(
              'Negroni',
              lines: const [
                RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.base),
              ],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('flags non-positive and out-of-order amounts', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            lines: const [
              RecipeLine(Amount(0), 'part', ['gin']),
              RecipeLine(Amount.range(2, 1.5), 'part', ['gin']),
            ],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.amountNotPositive,
        ValidationIssueKind.rangeOutOfOrder,
      ]);
      expect(issues[0].path, ['recipes', 0, 'lines', 0]);
      expect(issues[0].message, contains('positive'));
      expect(issues[1].path, ['recipes', 0, 'lines', 1]);
      expect(issues[1].message, contains('2-1.5'));
    });

    test('collects every issue in one pass', () {
      final issues = validateCollection(
        settings: const Settings(partMl: -1),
        ingredients: [Ingredient('gin'), Ingredient('gin')],
        recipes: [
          Recipe(
            'Negroni',
            lines: const [
              RecipeLine(Amount(1), 'part', ['vermouth']),
            ],
          ),
        ],
      );
      expect(issues, hasLength(3));
    });

    test('ordering: ingredient issue before recipe issue', () {
      final issues = validateCollection(
        ingredients: [Ingredient('silly (optional)'), Ingredient('gin')],
        recipes: [
          Recipe('Negroni', lines: const [_gin]),
          Recipe('Negroni', lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('reserved'));
      expect(issues[1].path, ['recipes', 1]);
      expect(issues[1].message, contains('Duplicate'));
    });

    test('ordering follows the file: settings, ingredients, both tag '
        'vocabularies, recipes', () {
      final issues = validateCollection(
        settings: const Settings(partMl: 0),
        ingredients: [Ingredient('silly (optional)'), Ingredient('gin')],
        ingredientTags: [
          const Tag('citrus', color: TagColor.sand),
          const Tag('citrus', color: TagColor.sand),
        ],
        recipeTags: [
          const Tag('sour', color: TagColor.rose),
          const Tag('sour', color: TagColor.rose),
        ],
        recipes: [
          Recipe('Negroni', lines: const [_gin]),
          Recipe('Negroni', lines: const [_gin]),
        ],
      );
      expect(issues.map((i) => i.path).toList(), [
        ['settings', 'part_ml'],
        ['ingredients', 0],
        ['ingredient_tags', 1],
        ['recipe_tags', 1],
        ['recipes', 1],
      ]);
    });

    test("an ingredient's tag issues follow its own name issues", () {
      final issues = validateCollection(
        ingredients: [
          Ingredient(' gin', tags: const ['juniper']),
          Ingredient('rum'),
        ],
      );
      expect(issues.map((i) => i.path).toList(), [
        ['ingredients', 0],
        ['ingredients', 0, 'tags', 0],
      ]);
    });

    test('ordering: within one vocabulary, by entry index', () {
      final issues = validateCollection(
        ingredients: [
          Ingredient('absinthe (optional)'),
          Ingredient('gin'),
          Ingredient('gin'),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('reserved'));
      expect(issues[1].path, ['ingredients', 2]);
      expect(issues[1].message, contains('Duplicate'));
    });

    test('ordering: every rule on one entry stays on that entry', () {
      final issues = validateCollection(
        ingredients: [Ingredient(' gin (optional)')],
      );
      expect(issues.map((i) => i.path), [
        ['ingredients', 0],
        ['ingredients', 0],
      ]);
      expect(issues[0].message, contains('whitespace'));
      expect(issues[1].message, contains('reserved'));
    });

    test('ordering: a recipe\'s own issues precede the next recipe\'s', () {
      final issues = validateCollection(
        ingredients: [Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            tags: const ['unknown'],
            lines: const [
              RecipeLine(Amount(0), 'part', ['gin']),
            ],
          ),
          Recipe('', lines: const [_gin]),
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
          lines: const [
            RecipeLine(Amount(1.5), 'part', ['bourbon']),
          ],
        ),
        knownIngredients: {'bourbon'},
        knownTags: {'sour'},
        knownUnits: shippedUnits,
      );
      expect(issues, isEmpty);
    });

    test('a line and a tag resolve however they are written (ADR 08)', () {
      final issues = validateRecipe(
        Recipe(
          'whiskey sour',
          tags: const ['SOUR'],
          lines: const [
            RecipeLine(Amount(1.5), 'part', ['Bourbon']),
          ],
        ),
        knownIngredients: {'bourbon'},
        knownTags: {'sour'},
        knownUnits: shippedUnits,
        otherRecipeNames: {'Whiskey Sour'},
      );
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
    });

    test('paths have no recipes[index] prefix', () {
      final issues = validateRecipe(
        Recipe(
          'Martini',
          tags: const ['unknown'],
          lines: const [
            RecipeLine(Amount(1), 'part', ['gin']),
            RecipeLine(Amount(1), 'part', ['vermouth']),
            RecipeLine(Amount(0), 'part', ['missing']),
          ],
        ),
        knownIngredients: {'gin', 'vermouth'},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(issues.map((i) => i.path), [
        ['tags', 0],
        ['lines', 2],
        ['lines', 2],
      ]);
    });

    test('every alternative must name a bottle (ADR 11)', () {
      final issues = validateRecipe(
        Recipe(
          'Sidecar',
          lines: const [
            RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
          ],
        ),
        knownIngredients: {'cognac'},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(issues, hasLength(1));
      expect(issues.single.kind, ValidationIssueKind.unknownIngredient);
      expect(issues.single.message, 'Unknown ingredient: "vodka"');
    });

    test('a group every bottle of which is known is clean', () {
      expect(
        validateRecipe(
          Recipe(
            'Sidecar',
            lines: const [
              RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
            ],
          ),
          knownIngredients: {'cognac', 'vodka'},
          knownTags: const {},
          knownUnits: shippedUnits,
        ),
        isEmpty,
      );
    });

    test('both unknown alternatives are named, under the one line path', () {
      final issues = validateRecipe(
        Recipe(
          'Sidecar',
          lines: const [
            _gin,
            RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
          ],
        ),
        knownIngredients: {'gin'},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(issues.map((i) => i.message), [
        'Unknown ingredient: "cognac"',
        'Unknown ingredient: "vodka"',
      ]);
      expect(issues.map((i) => i.path), [
        ['lines', 1],
        ['lines', 1],
      ]);
    });

    test('naming one bottle twice is a slip, not a choice', () {
      final issues = validateRecipe(
        Recipe(
          'Sidecar',
          lines: const [
            RecipeLine(Amount(1), 'part', ['cognac', 'COGNAC']),
          ],
        ),
        knownIngredients: {'cognac'},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(issues, hasLength(1));
      expect(issues.single.kind, ValidationIssueKind.duplicateAlternative);
      expect(issues.single.path, ['lines', 0]);
      expect(
        issues.single.message,
        'Duplicate alternative on the line: '
        '"COGNAC"',
      );
    });

    test('flags a tag repeated on the recipe, in tag order', () {
      final issues = validateRecipe(
        Recipe(
          'Negroni',
          tags: const ['sour', 'classic', 'sour'],
          lines: const [_gin],
        ),
        knownIngredients: {'gin'},
        knownTags: {'sour', 'classic'},
        knownUnits: shippedUnits,
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['tags', 2]);
      expect(issues.single.message, contains('Duplicate tag'));
    });

    test('checks the recipe name, at an entry-relative empty path', () {
      final issues = validateRecipe(
        Recipe('', lines: const [_gin]),
        knownIngredients: {'gin'},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(issues.single.path, isEmpty);
      expect(issues.single.kind, ValidationIssueKind.emptyName);
    });

    test('a name collides with another recipe, never with itself', () {
      expect(
        validateRecipe(
          Recipe('Negroni', lines: const [_gin]),
          knownIngredients: {'gin'},
          knownTags: const {},
          knownUnits: shippedUnits,
          otherRecipeNames: {'Martini'},
        ),
        isEmpty,
      );
      expect(
        validateRecipe(
          Recipe('Negroni', lines: const [_gin]),
          knownIngredients: {'gin'},
          knownTags: const {},
          knownUnits: shippedUnits,
          otherRecipeNames: {'Negroni'},
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });

    test('validateCollection prefixes the same issues with recipes[index]', () {
      final recipe = Recipe(
        'Martini',
        tags: const ['unknown'],
        lines: const [
          RecipeLine(Amount(0), 'part', ['missing']),
        ],
      );
      final collectionIssues = validateCollection(recipes: [recipe]);
      final recipeIssues = validateRecipe(
        recipe,
        knownIngredients: const {},
        knownTags: const {},
        knownUnits: shippedUnits,
      );
      expect(collectionIssues.map((i) => i.path), [
        ['recipes', 0, 'tags', 0],
        ['recipes', 0, 'lines', 0],
        ['recipes', 0, 'lines', 0],
      ]);
      expect(
        collectionIssues.map((i) => i.message).toList(),
        recipeIssues.map((i) => i.message).toList(),
      );
    });
  });

  group('validateIngredient', () {
    List<ValidationIssue> check(
      Ingredient ingredient, {
      Set<String> known = const {},
      Set<String> others = const {},
    }) => validateIngredient(
      ingredient,
      knownIngredientTags: known,
      otherIngredientNames: others,
    );

    test('a clean entry is valid', () {
      expect(check(Ingredient('gin')), isEmpty);
    });

    test('name rules apply, at an entry-relative empty path', () {
      final issues = check(Ingredient(' gin (optional)'));
      expect(issues.map((i) => i.path), [const [], const []]);
      expect(issues.map((i) => i.kind), [
        ValidationIssueKind.whitespaceInName,
        ValidationIssueKind.reservedSuffix,
      ]);
    });

    test('a name collides with another entry, never with itself', () {
      expect(check(Ingredient('gin'), others: {'rum'}), isEmpty);
      expect(
        check(Ingredient('gin'), others: {'gin'}).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });

    test('a name differing only in case is that name (ADR 08)', () {
      expect(
        check(Ingredient('Gin'), others: {'gin'}).single.kind,
        ValidationIssueKind.duplicateName,
      );
      expect(check(Ingredient('Gin'), known: {'Citrus'}), isEmpty);
      expect(
        check(Ingredient('gin', tags: const ['CITRUS']), known: {'citrus'}),
        isEmpty,
      );
    });

    test('otherNames leaves out the entry being renamed, case and all', () {
      expect(otherNames({'gin', 'rum'}, 'GIN'), {'rum'});
      expect(otherNames({'gin', 'rum'}, null), {'gin', 'rum'});
    });

    test('tag references resolve against the vocabulary it is given', () {
      final tagged = Ingredient('gin', tags: const ['juniper']);
      expect(check(tagged, known: {'juniper'}), isEmpty);
      final issue = check(tagged).single;
      expect(issue.kind, ValidationIssueKind.unknownTag);
      expect(issue.path, ['tags', 0]);
    });

    test('reports what validateCollection reports for the same entry', () {
      final entry = Ingredient(' gin (optional)', tags: const ['juniper']);
      expect(
        validateCollection(ingredients: [entry]).map((i) => i.message).toList(),
        check(entry).map((i) => i.message).toList(),
      );
    });

    group('aliases (ADR 10)', () {
      test('a spelling of its own is valid', () {
        expect(
          check(Ingredient('bourbon', aliases: const ['bourbon whiskey'])),
          isEmpty,
        );
      });

      test('the name rules apply, at the alias own path', () {
        final issues = check(
          Ingredient('bourbon', aliases: const ['', ' rye ', 'rye (base)']),
        );
        expect(issues.map((i) => i.path), [
          ['aliases', 0],
          ['aliases', 1],
          ['aliases', 2],
        ]);
        expect(issues.map((i) => i.kind), [
          ValidationIssueKind.emptyName,
          ValidationIssueKind.whitespaceInName,
          ValidationIssueKind.reservedSuffix,
        ]);
      });

      test('a comma is barred, the field being separated by one', () {
        final issue = check(
          Ingredient('bourbon', aliases: const ['rye, whiskey']),
        ).single;
        expect(issue.kind, ValidationIssueKind.commaInAlias);
        expect(issue.message, 'Comma in ingredient alias: "rye, whiskey"');
      });

      test('names and aliases share one namespace', () {
        for (final aliases in [
          const ['gin'], // another entry's name
          const ['GIN'], // the same name, differently written (ADR 08)
          const ['Bourbon'], // its own entry's name
          const ['rye', 'RYE'], // itself, twice
        ]) {
          final issues = check(
            Ingredient('bourbon', aliases: aliases),
            others: {'gin'},
          );
          expect(
            issues.single.kind,
            ValidationIssueKind.duplicateName,
            reason: '$aliases',
          );
        }
      });

      test('an alias may repeat a name in another vocabulary', () {
        expect(
          check(
            Ingredient('bourbon', aliases: const ['juniper']),
            known: {'juniper'},
          ),
          isEmpty,
        );
      });

      test('reports what validateCollection reports for the same entry', () {
        final entry = Ingredient('bourbon', aliases: const ['gin', 'Bourbon']);
        expect(
          validateCollection(
            ingredients: [Ingredient('gin'), entry],
          ).where((i) => i.path.contains('aliases')).map((i) => i.message),
          check(entry, others: {'gin'}).map((i) => i.message),
        );
      });
    });
  });

  group('validateTag', () {
    test('a clean tag is valid', () {
      expect(validateTag(const Tag('sour', color: TagColor.rose)), isEmpty);
    });

    test('the reserved suffix is an ingredient rule only', () {
      expect(
        validateTag(const Tag('sour (optional)', color: TagColor.rose)),
        isEmpty,
      );
    });

    test('a name collides with another entry, never with itself', () {
      expect(
        validateTag(
          const Tag('sour', color: TagColor.rose),
          otherTagNames: {'classic'},
        ),
        isEmpty,
      );
      expect(
        validateTag(
          const Tag('sour', color: TagColor.rose),
          otherTagNames: {'sour'},
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
    });
  });
}
