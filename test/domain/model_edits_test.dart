import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final whiskeySour = Recipe(
    'Whiskey Sour',
    tags: ['sour', 'classic'],
    lines: const [
      RecipeLine(
        Amount.range(1.5, 2),
        Unit.part,
        'bourbon',
        mark: LineMark.base,
      ),
      RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
      RecipeLine(Amount(0.5), Unit.part, 'egg white', mark: LineMark.optional),
    ],
    notes: 'dry shake, then shake with ice',
  );
  final negroni = Recipe(
    'Negroni',
    tags: ['classic'],
    lines: const [RecipeLine(Amount(1), Unit.part, 'gin')],
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
    test('renames the entry where it stands', () {
      final edited = model.withIngredientRenamed('bourbon', 'rye');
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
      final edited = model.withIngredientRenamed('bourbon', 'rye');
      final line = edited.recipeNamed('Whiskey Sour')?.lines.first;
      expect(line?.ingredient, 'rye');
      expect(line?.mark, LineMark.base);
    });

    test('rewrites optional lines too', () {
      final edited = model.withIngredientRenamed('egg white', 'aquafaba');
      expect(
        edited.recipeNamed('Whiskey Sour')?.lines.last.ingredient,
        'aquafaba',
      );
      expect(edited.recipeNamed('Whiskey Sour')?.lines.last.isOptional, isTrue);
    });

    test('leaves a recipe that never referenced it untouched', () {
      final edited = model.withIngredientRenamed('bourbon', 'rye');
      expect(edited.recipeNamed('Negroni'), same(negroni));
    });

    test('an unknown name changes nothing', () {
      expect(model.withIngredientRenamed('rye', 'bourbon'), same(model));
    });

    test('renaming onto an existing name is rejected', () {
      expect(
        () => model.withIngredientRenamed('bourbon', 'gin'),
        throwsArgumentError,
      );
      expect(
        () => model.withIngredientRenamed('bourbon', 'GIN'),
        throwsArgumentError,
      );
    });

    test('recapitalising is a rename of that entry, not a collision', () {
      final edited = model.withIngredientRenamed('bourbon', 'Bourbon');
      expect(namesOf(edited.ingredients).first, 'Bourbon');
      expect(
        edited.recipeNamed('Whiskey Sour')?.lines.first.ingredient,
        'Bourbon',
      );
    });

    test('the name to rename is read however it is written (ADR 08)', () {
      expect(
        model.withIngredientRenamed('BOURBON', 'rye').ingredients.first,
        Ingredient('rye', stock: StockLevel.in_, tags: const ['oaked']),
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

  group('reference queries', () {
    test('recipesUsingIngredient names them in model order', () {
      final shared = model.withRecipe(
        Recipe(
          'Old Fashioned',
          lines: const [RecipeLine(Amount(2), Unit.part, 'bourbon')],
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

    test('each query looks only at its own side', () {
      final shared = model
          .withTag(TagKind.ingredient, const Tag('sour', color: TagColor.rose))
          .withTag(TagKind.recipe, const Tag('citrus', color: TagColor.sand));
      expect(shared.usersOfTag(TagKind.ingredient, 'sour'), isEmpty);
      expect(shared.usersOfTag(TagKind.recipe, 'citrus'), isEmpty);
    });
  });
}
