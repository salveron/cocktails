import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final whiskeySour = Recipe(
    'Whiskey Sour',
    tags: ['sour', 'classic'],
    lines: const [
      RecipeLine(Amount.range(1.5, 2), 'part', [
        'bourbon',
      ], mark: LineMark.base),
      RecipeLine(Amount(0.75), 'part', ['lemon juice']),
      RecipeLine(Amount(0.5), 'part', ['egg white'], mark: LineMark.optional),
    ],
    notes: 'dry shake, then shake with ice',
  );
  final negroni = Recipe(
    'Negroni',
    tags: ['classic'],
    lines: const [
      RecipeLine(Amount(1), 'part', ['gin']),
    ],
  );
  final model = Model(
    settings: const Settings(partMl: 25),
    ingredients: [
      Ingredient('bourbon', stock: StockLevel.in_, tags: const ['oaked']),
      Ingredient('lemon juice', stock: StockLevel.low, tags: const ['citrus']),
      Ingredient('egg white'),
      Ingredient('gin'),
    ],
    ingredientTags: const [
      Tag('citrus', color: TagColor.sand),
      Tag('oaked', color: TagColor.slate),
    ],
    recipeTags: const [
      Tag('sour', color: TagColor.rose),
      Tag('classic', color: TagColor.teal),
    ],
    recipes: [whiskeySour, negroni],
  );

  List<String> namesOf(List<Ingredient> ingredients) =>
      ingredients.map((ingredient) => ingredient.name).toList();

  group('units', () {
    /// The vocabulary as the units screen hands it back: every row as it now
    /// reads, each carrying the name it came from.
    List<UnitEdit> rows(List<Unit> units) => [
      for (final unit in units) (unit: unit, was: unit.name),
    ];

    List<String> unitsOf(Model model) => [
      for (final unit in model.units) unit.name,
    ];

    List<String> linesOf(Model model, String recipe) => [
      for (final line in model.recipeNamed(recipe)!.lines)
        formatRecipeLine(line, model.units),
    ];

    test('withUnits replaces the vocabulary', () {
      final edited = model.withUnits([
        ...rows(defaultUnits),
        (unit: const Unit('tsp'), was: null),
      ]);
      expect(unitsOf(edited), [...unitsOf(model), 'tsp']);
      expect(edited.recipes, model.recipes);
    });

    test('a plural is edited without touching a line', () {
      final edited = model.withUnits([
        for (final unit in defaultUnits)
          (
            unit: unit.name == 'part'
                ? const Unit('part', plural: 'partes')
                : unit,
            was: unit.name,
          ),
      ]);
      expect(edited.recipeNamed('Negroni')!.lines, negroni.lines);
      expect(linesOf(edited, 'Negroni'), ['1 part gin']);
      expect(
        linesOf(edited, 'Whiskey Sour').first,
        '1.5-2 partes bourbon (base)',
      );
    });

    test('a rename rewrites every line measured in it', () {
      final edited = model.withUnits([
        for (final unit in defaultUnits)
          (
            unit: unit.name == 'part' ? const Unit('share') : unit,
            was: unit.name,
          ),
      ]);
      expect(unitsOf(edited).first, 'share');
      expect(linesOf(edited, 'Negroni'), ['1 share gin']);
      expect(edited.recipeNamed('Whiskey Sour')!.lines.first.unit, 'share');
    });

    test('two units trade names in one edit', () {
      final swapped = model.withUnits([
        (unit: const Unit('dash'), was: 'part'),
        (unit: const Unit('part'), was: 'dash'),
        (unit: const Unit(mlUnit), was: mlUnit),
      ]);
      expect(unitsOf(swapped), ['dash', 'part', 'ml']);
      expect(linesOf(swapped, 'Negroni'), ['1 dash gin']);
    });

    test('a recapitalisation is a rename of the same unit', () {
      final edited = model.withUnits([
        for (final unit in defaultUnits)
          (
            unit: unit.name == 'part' ? const Unit('Part') : unit,
            was: unit.name,
          ),
      ]);
      expect(edited.recipeNamed('Negroni')!.lines.single.unit, 'Part');
    });

    test('a unit dropped from the list is gone, lines untouched', () {
      final edited = model.withUnits(
        rows([
          for (final unit in defaultUnits)
            if (unit.name != 'oz') unit,
        ]),
      );
      expect(unitsOf(edited), isNot(contains('oz')));
      expect(edited.recipes, model.recipes);
    });

    test('recipesUsingUnit names what stands in the way of deleting it', () {
      expect(model.recipesUsingUnit('part'), ['Whiskey Sour', 'Negroni']);
      expect(model.recipesUsingUnit('PART'), ['Whiskey Sour', 'Negroni']);
      expect(model.recipesUsingUnit('oz'), isEmpty);
    });
  });

  group('settings', () {
    test('withSettings replaces the settings and nothing else', () {
      final edited = model.withSettings(const Settings(partMl: 30));
      expect(edited.settings, const Settings(partMl: 30));
      expect(edited, model.copyWith(settings: const Settings(partMl: 30)));
    });
  });

  group('ingredients', () {
    test('withIngredient adds an entry the vocabulary lacked', () {
      final edited = model.withIngredient(Ingredient('rye'));
      expect(namesOf(edited.ingredients), [
        'bourbon',
        'lemon juice',
        'egg white',
        'gin',
        'rye',
      ]);
    });

    test('withIngredient replaces the entry of that name where it stands', () {
      final edited = model.withIngredient(
        Ingredient('lemon juice', stock: StockLevel.in_),
      );
      expect(namesOf(edited.ingredients), namesOf(model.ingredients));
      expect(edited.ingredientNamed('lemon juice')?.stock, StockLevel.in_);
    });

    test('withoutIngredient removes only that entry', () {
      final edited = model.withoutIngredient('egg white');
      expect(namesOf(edited.ingredients), ['bourbon', 'lemon juice', 'gin']);
    });

    test('withoutIngredient leaves the recipes that referenced it', () {
      expect(model.withoutIngredient('bourbon').recipes, model.recipes);
    });

    test('withoutIngredient of an unknown name changes nothing', () {
      expect(model.withoutIngredient('rye'), model);
    });

    test('withStock sets the level and keeps the rest of the entry', () {
      final edited = model.withStock('bourbon', StockLevel.low);
      expect(
        edited.ingredientNamed('bourbon'),
        Ingredient('bourbon', stock: StockLevel.low, tags: const ['oaked']),
      );
      expect(namesOf(edited.ingredients), namesOf(model.ingredients));
    });

    test('withStock on an unknown ingredient changes nothing', () {
      expect(model.withStock('rye', StockLevel.in_), same(model));
    });
  });

  group('ingredient rename', () {
    /// The bourbon entry under a new name, everything else about it kept —
    /// the whole entry as the dialog hands it back.
    Model renamed(Model model, String to, {String from = 'bourbon'}) =>
        model.withIngredient(
          model.ingredientNamed(from)!.copyWith(name: to),
          replacing: from,
        );

    test('renames the entry where it stands', () {
      final edited = renamed(model, 'rye');
      expect(namesOf(edited.ingredients), [
        'rye',
        'lemon juice',
        'egg white',
        'gin',
      ]);
      expect(edited.ingredientNamed('rye')?.stock, StockLevel.in_);
      expect(edited.ingredientNamed('bourbon'), isNull);
    });

    test('rewrites every referencing line', () {
      final line = renamed(
        model,
        'rye',
      ).recipeNamed('Whiskey Sour')?.lines.first;
      expect(line?.ingredients.single, 'rye');
      expect(line?.mark, LineMark.base);
    });

    test('rewrites optional lines too', () {
      final edited = renamed(model, 'aquafaba', from: 'egg white');
      expect(
        edited.recipeNamed('Whiskey Sour')?.lines.last.ingredients.single,
        'aquafaba',
      );
      expect(edited.recipeNamed('Whiskey Sour')?.lines.last.isOptional, isTrue);
    });

    test('leaves a recipe that never referenced it untouched', () {
      expect(renamed(model, 'rye').recipeNamed('Negroni'), same(negroni));
    });

    test('reaches a bottle standing as one alternative of a group', () {
      final grouped = model.copyWith(
        recipes: [
          Recipe(
            'Sidecar',
            lines: const [
              RecipeLine(Amount(1), 'part', ['bourbon', 'gin']),
            ],
          ),
        ],
      );
      expect(
        renamed(
          grouped,
          'rye',
        ).recipeNamed('Sidecar')?.lines.single.ingredients,
        ['rye', 'gin'],
      );
    });

    test('an unknown name lands the entry all the same', () {
      final edited = model.withIngredient(Ingredient('rye'), replacing: 'gone');
      expect(namesOf(edited.ingredients).last, 'rye');
      expect(edited.recipes, model.recipes);
    });

    test('renaming onto an existing name is rejected', () {
      expect(() => renamed(model, 'gin'), throwsArgumentError);
      expect(() => renamed(model, 'GIN'), throwsArgumentError);
    });

    test('recapitalising is a rename of that entry, not a collision', () {
      final edited = renamed(model, 'Bourbon');
      expect(namesOf(edited.ingredients).first, 'Bourbon');
      expect(
        edited.recipeNamed('Whiskey Sour')?.lines.first.ingredients.single,
        'Bourbon',
      );
    });

    test('the name it replaces is read however it is written (ADR 08)', () {
      expect(
        renamed(model, 'rye', from: 'BOURBON').ingredients.first,
        Ingredient('rye', stock: StockLevel.in_, tags: const ['oaked']),
      );
    });

    test('a rename dropping an alias never builds the half of it', () {
      final aliased = model.withIngredient(
        Ingredient('bourbon', stock: StockLevel.in_, aliases: const ['rye']),
      );
      // The new name is the alias the same edit lets go of, so applying the
      // two halves in either order would collide with itself (ADR 10).
      final edited = aliased.withIngredient(
        Ingredient('rye', stock: StockLevel.in_),
        replacing: 'bourbon',
      );
      expect(edited.ingredientNamed('rye')?.aliases, isEmpty);
      expect(
        edited.recipeNamed('Whiskey Sour')?.lines.first.ingredients.single,
        'rye',
      );
    });

    test('and neither does one taking the old name as an alias', () {
      final edited = model.withIngredient(
        Ingredient('sloe gin', aliases: const ['gin']),
        replacing: 'gin',
      );
      expect(edited.ingredientNamed('gin')?.name, 'sloe gin');
      expect(
        edited.recipeNamed('Negroni')?.lines.single.ingredients.single,
        'sloe gin',
      );
    });
  });

  const stirred = Tag('stirred', color: TagColor.plum);

  /// Both vocabularies answer to one API, so one body tests both — told apart
  /// only by what each holds, who wears its tags, and what the other side is.
  /// A rule proven on one side is proven on the other by construction.
  void vocabulary(
    TagKind kind, {
    required String renamedTo,
    required List<String> wearers,
    required Object Function(Model model) sameSide,
    required Object Function(Model model) otherSide,
    required Object? Function(Model model) bystander,
  }) {
    final other = kind == TagKind.recipe ? TagKind.ingredient : TagKind.recipe;
    final held = model.tagsOf(kind);
    final first = held.first;
    final last = held.last;

    group('${kind.name} tags', () {
      test('withTag adds an entry the vocabulary lacked', () {
        expect(model.withTag(kind, stirred).tagsOf(kind), [...held, stirred]);
      });

      test('withTag of an existing name leaves one entry', () {
        expect(model.withTag(kind, first).tagsOf(kind), held);
      });

      test('withTag repaints the entry where it stands', () {
        final repainted = first.copyWith(color: TagColor.indigo);
        expect(model.withTag(kind, repainted).tagsOf(kind), [repainted, last]);
      });

      test('withoutTag removes only that entry', () {
        expect(model.withoutTag(kind, first.name).tagsOf(kind), [last]);
      });

      test('withoutTag leaves the entries that wore it', () {
        expect(sameSide(model.withoutTag(kind, first.name)), sameSide(model));
      });

      test('withoutTag of an unknown name changes nothing', () {
        expect(model.withoutTag(kind, 'stirred'), model);
      });

      test('neither edit reaches the other vocabulary', () {
        expect(model.withTag(kind, stirred).tagsOf(other), model.tagsOf(other));
        expect(
          model.withoutTag(kind, first.name).tagsOf(other),
          model.tagsOf(other),
        );
      });
    });

    group('${kind.name} tag rename', () {
      final renamed = model.withTagRenamed(kind, first.name, renamedTo);

      test('renames the entry where it stands, colour and all', () {
        expect(renamed.tagsOf(kind), [first.copyWith(name: renamedTo), last]);
        expect(renamed.hasTag(kind, first.name), isFalse);
      });

      test('rewrites every entry wearing the tag, in place', () {
        expect(model.usersOfTag(kind, first.name), wearers);
        expect(renamed.usersOfTag(kind, renamedTo), wearers);
      });

      test('leaves an entry that never wore it untouched', () {
        expect(bystander(renamed), same(bystander(model)));
      });

      test('an unknown name changes nothing', () {
        expect(model.withTagRenamed(kind, 'stirred', renamedTo), same(model));
      });

      test('the other side is none of its business', () {
        expect(otherSide(renamed), otherSide(model));
      });

      test('a same-named tag in the other vocabulary stays where it is', () {
        final shared = model.withTag(other, first);
        final edited = shared.withTagRenamed(kind, first.name, renamedTo);
        expect(edited.hasTag(other, first.name), isTrue);
        expect(edited.hasTag(kind, first.name), isFalse);
      });

      test('renaming onto an existing name is rejected', () {
        expect(
          () => model.withTagRenamed(kind, first.name, last.name),
          throwsArgumentError,
        );
      });
    });
  }

  vocabulary(
    TagKind.recipe,
    renamedTo: 'sours',
    wearers: ['Whiskey Sour'],
    sameSide: (model) => model.recipes,
    otherSide: (model) => model.ingredients,
    bystander: (model) => model.recipeNamed('Negroni'),
  );

  vocabulary(
    TagKind.ingredient,
    renamedTo: 'citrusy',
    wearers: ['lemon juice'],
    sameSide: (model) => model.ingredients,
    otherSide: (model) => model.recipes,
    bystander: (model) => model.ingredientNamed('gin'),
  );

  group('recipes', () {
    test('withRecipe adds a recipe the model lacked', () {
      final sazerac = Recipe('Sazerac');
      expect(model.withRecipe(sazerac).recipes, [
        whiskeySour,
        negroni,
        sazerac,
      ]);
    });

    test('withRecipe replaces the one of that name where it stands', () {
      final edited = model.withRecipe(Recipe('Whiskey Sour', notes: 'shaken'));
      expect(edited.recipes.first.notes, 'shaken');
      expect(edited.recipes.last, negroni);
    });

    test('withoutRecipe removes only that recipe', () {
      expect(model.withoutRecipe('Whiskey Sour').recipes, [negroni]);
    });

    test('withoutRecipe of an unknown name changes nothing', () {
      expect(model.withoutRecipe('Sazerac'), model);
    });
  });

  group('made it', () {
    final today = DateTime(2026, 7, 27);

    test('the first time stamps the date and counts one', () {
      final made = model
          .withRecipeMade('Negroni', today)
          .recipeNamed('Negroni')
          ?.made;
      expect(made, MadeHistory(today, 1));
    });

    test('every next time counts up and restamps the date', () {
      final twice = model
          .withRecipeMade('Negroni', DateTime(2026, 7, 18))
          .withRecipeMade('Negroni', today);
      expect(twice.recipeNamed('Negroni')?.made, MadeHistory(today, 2));
    });

    test('keeps the day, drops the time of day', () {
      final edited = model.withRecipeMade('Negroni', DateTime(2026, 7, 27, 23));
      expect(edited.recipeNamed('Negroni')?.made?.last, today);
    });

    test('leaves the rest of the recipe alone', () {
      final edited = model.withRecipeMade('Negroni', today);
      expect(edited.recipeNamed('Negroni')?.lines, negroni.lines);
      expect(edited.recipeNamed('Whiskey Sour'), same(whiskeySour));
    });

    test('an unknown recipe changes nothing', () {
      expect(model.withRecipeMade('Sazerac', today), same(model));
    });

    test('a history is written as handed over', () {
      final edited = model.withRecipeHistory('Negroni', MadeHistory(today, 9));
      expect(edited.recipeNamed('Negroni')?.made, MadeHistory(today, 9));
    });

    test('a null clears the history and leaves the recipe standing', () {
      final cleared = model
          .withRecipeMade('Negroni', today)
          .withRecipeHistory('Negroni', null);
      expect(cleared.recipeNamed('Negroni')?.made, isNull);
      expect(cleared.recipeNamed('Negroni'), negroni);
    });

    test('an unknown recipe has no history to write', () {
      expect(model.withRecipeHistory('Sazerac', null), same(model));
    });
  });

  group('withCanonicalIngredientNames (ADR 10)', () {
    /// The vocabulary with one bottle answering to a second spelling.
    final aliased = model.withIngredient(
      Ingredient('bourbon', stock: StockLevel.in_, aliases: const ['whiskey']),
    );

    List<String> ingredientsOf(Model model, String recipe) => [
      for (final line in model.recipeNamed(recipe)!.lines)
        line.ingredients.single,
    ];

    Model naming(Model model, String ingredient) => model.copyWith(
      recipes: [
        Recipe(
          'Old Fashioned',
          lines: [
            RecipeLine(const Amount(2), 'part', [ingredient]),
          ],
        ),
      ],
    );

    test('an alias becomes the bottle it names', () {
      final canonical = naming(
        aliased,
        'whiskey',
      ).withCanonicalIngredientNames();
      expect(ingredientsOf(canonical, 'Old Fashioned'), ['bourbon']);
    });

    test('so does a spelling in another case (ADR 08)', () {
      final canonical = naming(
        aliased,
        'BOURBON',
      ).withCanonicalIngredientNames();
      expect(ingredientsOf(canonical, 'Old Fashioned'), ['bourbon']);
    });

    test('a line naming no known bottle is left as written', () {
      final unknown = naming(aliased, 'rye');
      expect(unknown.withCanonicalIngredientNames(), same(unknown));
    });

    test('every alternative of a group settles, the rest left alone', () {
      final grouped = aliased.copyWith(
        recipes: [
          Recipe(
            'Old Fashioned',
            lines: const [
              RecipeLine(Amount(2), 'part', ['WHISKEY', 'rye', 'gin']),
            ],
          ),
        ],
      );
      expect(
        grouped
            .withCanonicalIngredientNames()
            .recipeNamed('Old Fashioned')!
            .lines
            .single
            .ingredients,
        ['bourbon', 'rye', 'gin'],
      );
    });

    test('a model already canonical is the very same model', () {
      final empty = Model();
      expect(model.withCanonicalIngredientNames(), same(model));
      expect(empty.withCanonicalIngredientNames(), same(empty));
    });

    test('every other part of the recipe rides along untouched', () {
      final canonical = aliased
          .copyWith(
            recipes: [
              whiskeySour.copyWith(
                lines: [
                  const RecipeLine(Amount.range(1.5, 2), 'part', [
                    'WHISKEY',
                  ], mark: LineMark.base),
                  ...whiskeySour.lines.skip(1),
                ],
              ),
            ],
          )
          .withCanonicalIngredientNames();
      expect(canonical.recipeNamed('Whiskey Sour'), whiskeySour);
    });
  });

  group('reference queries', () {
    test('recipesUsingIngredient names them in model order', () {
      final shared = model.withRecipe(
        Recipe(
          'Old Fashioned',
          lines: const [
            RecipeLine(Amount(2), 'part', ['bourbon']),
          ],
        ),
      );
      expect(shared.recipesUsingIngredient('bourbon'), [
        'Whiskey Sour',
        'Old Fashioned',
      ]);
    });

    test('recipesUsingIngredient counts optional lines', () {
      expect(model.recipesUsingIngredient('egg white'), ['Whiskey Sour']);
    });

    test('recipesUsingIngredient is empty when nothing references it', () {
      expect(model.recipesUsingIngredient('lemon juice'), ['Whiskey Sour']);
      expect(
        model
            .withoutRecipe('Whiskey Sour')
            .recipesUsingIngredient('lemon juice'),
        isEmpty,
      );
    });

    test('usersOfTag names them in model order', () {
      expect(model.usersOfTag(TagKind.recipe, 'classic'), [
        'Whiskey Sour',
        'Negroni',
      ]);
      final shared = model.withIngredient(
        Ingredient('gin', tags: const ['oaked']),
      );
      expect(shared.usersOfTag(TagKind.ingredient, 'oaked'), [
        'bourbon',
        'gin',
      ]);
    });

    test('usersOfTag is empty when nothing wears it', () {
      for (final kind in TagKind.values) {
        expect(
          model.withTag(kind, stirred).usersOfTag(kind, 'stirred'),
          isEmpty,
        );
      }
    });

    test('a reference in another case still counts (ADR 08)', () {
      expect(model.recipesUsingIngredient('BOURBON'), ['Whiskey Sour']);
      expect(model.usersOfTag(TagKind.recipe, 'Classic'), [
        'Whiskey Sour',
        'Negroni',
      ]);
    });

    test('so does one made by an alias, either end of it (ADR 10)', () {
      final aliased = model.withIngredient(
        Ingredient('bourbon', aliases: const ['whiskey']),
      );
      expect(aliased.recipesUsingIngredient('whiskey'), ['Whiskey Sour']);
      final byAlias = aliased.copyWith(
        recipes: [
          Recipe(
            'Old Fashioned',
            lines: const [
              RecipeLine(Amount(2), 'part', ['whiskey']),
            ],
          ),
        ],
      );
      expect(byAlias.recipesUsingIngredient('bourbon'), ['Old Fashioned']);
    });

    test('standing as one alternative still blocks a delete (ADR 11)', () {
      final grouped = model.copyWith(
        recipes: [
          Recipe(
            'Sidecar',
            lines: const [
              RecipeLine(Amount(1), 'part', ['cognac', 'bourbon']),
            ],
          ),
        ],
      );
      expect(grouped.recipesUsingIngredient('bourbon'), ['Sidecar']);
      expect(grouped.recipesUsingIngredient('gin'), isEmpty);
    });

    test('each query looks only at its own side', () {
      final shared = model
          .withTag(TagKind.ingredient, const Tag('sour', color: TagColor.rose))
          .withTag(TagKind.recipe, const Tag('citrus', color: TagColor.sand));
      expect(shared.usersOfTag(TagKind.ingredient, 'sour'), isEmpty);
      expect(shared.usersOfTag(TagKind.recipe, 'citrus'), isEmpty);
    });
  });
}
