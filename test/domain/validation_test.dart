import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// The required line every recipe now needs (FR-REC-2), so a fixture about
/// some other rule does not trip that one. Its bottle is declared alongside.
const _gin = RecipeLine(Amount(1), 'part', 'gin');

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
      expect(validateModel(units: defaultUnits), isEmpty);
    });

    test('a line measured in nothing the vocabulary holds is reported', () {
      final issues = validateModel(
        units: const [Unit(partUnit), Unit(mlUnit)],
        ingredients: [Ingredient('bitters')],
        recipes: [
          Recipe(
            'Dashes',
            lines: const [RecipeLine(Amount(2), 'dash', 'bitters')],
          ),
        ],
      );
      expect(issues.single.kind, ValidationIssueKind.unknownUnit);
      expect(issues.single.path, ['recipes', 0, 'lines', 0]);
      expect(issues.single.message, contains('"dash"'));
    });

    test('the two units the app leans on must be there', () {
      final issues = validateModel(units: const [Unit('dash')]);
      expect(issues.map((i) => i.message), [
        'units must include "part"',
        'units must include "ml"',
      ]);
      expect(issues.first.kind, ValidationIssueKind.missingUnit);
      expect(issues.first.path, ['units']);
    });

    test('a spelling another unit answers to is a duplicate', () {
      final issues = validateModel(
        units: const [
          Unit(partUnit, plural: 'parts'),
          Unit(mlUnit),
          Unit('dash', plural: 'parts'),
        ],
      );
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
      expect(issues.single.path, ['units', 2, 'plural']);
      expect(issues.single.message, contains('"parts"'));
    });

    test('a plural written out as its own name is no duplicate', () {
      expect(
        validateModel(
          units: const [
            Unit(partUnit),
            Unit(mlUnit, plural: 'ml'),
          ],
        ),
        isEmpty,
      );
    });

    test('both spellings answer to the name rules', () {
      final issues = validateModel(
        units: const [
          Unit(partUnit),
          Unit(mlUnit),
          Unit(' oz'),
          Unit('dash', plural: 'dashes '),
        ],
      );
      expect(issues.map((i) => i.path), [
        ['units', 2],
        ['units', 3, 'plural'],
      ]);
      expect(
        issues.every((i) => i.kind == ValidationIssueKind.whitespaceInName),
        isTrue,
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
              RecipeLine(
                Amount.range(1.5, 2),
                'part',
                'bourbon',
                mark: LineMark.base,
              ),
              RecipeLine(Amount(0.75), 'part', 'lemon juice'),
              RecipeLine(Amount(0.5), 'part', 'rich demerara syrup'),
              RecipeLine(
                Amount(0.5),
                'part',
                'egg white',
                mark: LineMark.optional,
              ),
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
        ingredients: [Ingredient(''), Ingredient('gin')],
        ingredientTags: [const Tag(' citrus', color: TagColor.sand)],
        recipeTags: [const Tag(' sour', color: TagColor.rose)],
        recipes: [
          Recipe('Old\nFashioned', lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(4));
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
        final issues = validateModel(ingredients: [Ingredient(name)]);
        expect(issues, hasLength(1), reason: name);
        expect(issues.single.path, ['ingredients', 0]);
        expect(issues.single.message, contains('reserved'));
      }
    });

    test('the reserved suffix rule is ingredient-only', () {
      final issues = validateModel(
        ingredients: [Ingredient('gin')],
        recipeTags: [const Tag('odd (optional)', color: TagColor.rose)],
        recipes: [
          Recipe('Strange (optional)', lines: const [_gin]),
        ],
      );
      expect(issues, isEmpty);
    });

    test('flags duplicate names at the repeated position', () {
      final issues = validateModel(
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
      expect(issues[0].path, ['ingredients', 1]);
      expect(issues[0].message, 'Duplicate ingredient name: "gin"');
      expect(issues[1].path, ['ingredient_tags', 1]);
      expect(issues[1].message, 'Duplicate ingredient tag name: "citrus"');
      expect(issues[2].path, ['recipe_tags', 1]);
      expect(issues[2].message, 'Duplicate recipe tag name: "sour"');
      expect(issues[3].path, ['recipes', 1]);
    });

    test('two spellings of one name are a duplicate (ADR 08)', () {
      final issues = validateModel(
        ingredients: [Ingredient('Gin'), Ingredient('gin')],
      );
      expect(issues.single.path, ['ingredients', 1]);
      expect(issues.single.kind, ValidationIssueKind.duplicateName);
    });

    test('a name in both vocabularies at once is no duplicate', () {
      expect(
        validateModel(
          ingredientTags: [const Tag('sour', color: TagColor.sand)],
          recipeTags: [const Tag('sour', color: TagColor.rose)],
        ),
        isEmpty,
      );
    });

    test(
      'an alias is a spelling of the vocabulary, at its own path (ADR 10)',
      () {
        final issues = validateModel(
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
      final issues = validateModel(
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
        validateModel(
          ingredients: [
            Ingredient('bourbon', aliases: const ['whiskey']),
          ],
          recipes: [
            Recipe(
              'Old Fashioned',
              lines: const [RecipeLine(Amount(2), 'part', 'whiskey')],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('flags unknown ingredient and tag references', () {
      final issues = validateModel(
        recipes: [
          Recipe(
            'Negroni',
            tags: ['classic'],
            lines: const [RecipeLine(Amount(1), 'part', 'gin')],
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
        ingredients: [Ingredient('gin')],
        recipeTags: [const Tag('sour', color: TagColor.rose)],
        recipes: [
          Recipe('Daiquiri', tags: ['sour', 'sour'], lines: const [_gin]),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'tags', 1]);
      expect(issues.single.message, contains('"sour"'));
    });

    test('flags a recipe with nothing required, at its lines', () {
      for (final lines in [
        const <RecipeLine>[],
        const [RecipeLine(Amount(1), 'part', 'gin', mark: LineMark.optional)],
      ]) {
        final issues = validateModel(
          ingredients: [Ingredient('gin')],
          recipes: [Recipe('Negroni', lines: lines)],
        );
        expect(issues.single.path, ['recipes', 0, 'lines'], reason: '$lines');
        expect(issues.single.kind, ValidationIssueKind.noRequiredLine);
      }
    });

    test('a base line is a required line', () {
      expect(
        validateModel(
          ingredients: [Ingredient('gin')],
          recipes: [
            Recipe(
              'Negroni',
              lines: const [
                RecipeLine(Amount(1), 'part', 'gin', mark: LineMark.base),
              ],
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('flags non-positive and out-of-order amounts', () {
      final issues = validateModel(
        ingredients: [Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            lines: const [
              RecipeLine(Amount(0), 'part', 'gin'),
              RecipeLine(Amount.range(2, 1.5), 'part', 'gin'),
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
        ingredients: [Ingredient('gin')],
        recipes: [
          Recipe(
            'Negroni',
            lines: const [_gin],
            made: MadeHistory(DateTime(2026, 7, 18), 0),
          ),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'made', 'times']);
    });

    test('collects every issue in one pass', () {
      final issues = validateModel(
        settings: const Settings(partMl: -1),
        ingredients: [Ingredient('gin'), Ingredient('gin')],
        recipes: [
          Recipe(
            'Negroni',
            lines: const [RecipeLine(Amount(1), 'part', 'vermouth')],
          ),
        ],
      );
      expect(issues, hasLength(3));
    });

    test('ordering: ingredient issue before recipe issue', () {
      final issues = validateModel(
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
      final issues = validateModel(
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
      final issues = validateModel(
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
      final issues = validateModel(
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
      final issues = validateModel(
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
      final issues = validateModel(
        ingredients: [Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            tags: const ['unknown'],
            lines: const [RecipeLine(Amount(0), 'part', 'gin')],
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
          lines: const [RecipeLine(Amount(1.5), 'part', 'bourbon')],
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
          lines: const [RecipeLine(Amount(1.5), 'part', 'Bourbon')],
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
            RecipeLine(Amount(1), 'part', 'gin'),
            RecipeLine(Amount(1), 'part', 'vermouth'),
            RecipeLine(Amount(0), 'part', 'missing'),
          ],
          made: MadeHistory(DateTime(2026, 7, 18), 0),
        ),
        knownIngredients: {'gin', 'vermouth'},
        knownTags: const {},
        knownUnits: shippedUnits,
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

    test('validateModel prefixes the same issues with recipes[index]', () {
      final recipe = Recipe(
        'Martini',
        tags: const ['unknown'],
        lines: const [RecipeLine(Amount(0), 'part', 'missing')],
      );
      final modelIssues = validateModel(recipes: [recipe]);
      final recipeIssues = validateRecipe(
        recipe,
        knownIngredients: const {},
        knownTags: const {},
        knownUnits: shippedUnits,
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

    test('reports what validateModel reports for the same entry', () {
      final entry = Ingredient(' gin (optional)', tags: const ['juniper']);
      expect(
        validateModel(ingredients: [entry]).map((i) => i.message).toList(),
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

      test('reports what validateModel reports for the same entry', () {
        final entry = Ingredient('bourbon', aliases: const ['gin', 'Bourbon']);
        expect(
          validateModel(
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

  group('issue kinds', () {
    test('settings, name and duplicate rules', () {
      expect(
        validateModel(settings: const Settings(partMl: 0)).single.kind,
        ValidationIssueKind.partMlNotPositive,
      );
      expect(
        validateModel(ingredients: [Ingredient('')]).single.kind,
        ValidationIssueKind.emptyName,
      );
      expect(
        validateModel(ingredients: [Ingredient(' gin')]).single.kind,
        ValidationIssueKind.whitespaceInName,
      );
      expect(
        validateModel(ingredients: [Ingredient('gin\nrum')]).single.kind,
        ValidationIssueKind.lineBreakInName,
      );
      expect(
        validateModel(
          ingredients: [Ingredient('gin'), Ingredient('gin')],
        ).single.kind,
        ValidationIssueKind.duplicateName,
      );
      expect(
        validateModel(
          ingredients: [Ingredient('bitters (optional)')],
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
            RecipeLine(Amount(0), 'part', 'missing'),
            RecipeLine(Amount.range(2, 1), 'part', 'gin'),
          ],
          made: MadeHistory(DateTime(2026, 7, 18), 0),
        ),
        knownIngredients: {'gin'},
        knownTags: const {},
        knownUnits: shippedUnits,
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
