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

    test('withIngredientTags replaces the list and keeps the rest', () {
      final edited = model.withIngredientTags('bourbon', const ['citrus']);
      expect(
        edited.ingredientNamed('bourbon'),
        Ingredient('bourbon', stock: StockLevel.in_, tags: const ['citrus']),
      );
      expect(namesOf(edited.ingredients), namesOf(model.ingredients));
    });

    test('withIngredientTags can empty the list', () {
      final edited = model.withIngredientTags('bourbon', const []);
      expect(edited.ingredientNamed('bourbon')?.tags, isEmpty);
    });

    test('withIngredientTags on an unknown ingredient changes nothing', () {
      expect(model.withIngredientTags('rye', const ['oaked']), same(model));
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
    });
  });

  const stirred = Tag('stirred', color: TagColor.plum);
  const sour = Tag('sour', color: TagColor.rose);
  const classic = Tag('classic', color: TagColor.teal);
  const citrus = Tag('citrus', color: TagColor.sand);
  const oaked = Tag('oaked', color: TagColor.slate);

  group('recipe tags', () {
    test('withRecipeTag adds an entry the vocabulary lacked', () {
      final edited = model.withRecipeTag(stirred);
      expect(edited.recipeTags, const [sour, classic, stirred]);
    });

    test('withRecipeTag of an existing name leaves one entry', () {
      expect(model.withRecipeTag(sour).recipeTags, model.recipeTags);
    });

    test('withRecipeTag repaints the entry where it stands', () {
      final edited = model.withRecipeTag(
        const Tag('sour', color: TagColor.indigo),
      );
      expect(edited.recipeTags, const [
        Tag('sour', color: TagColor.indigo),
        classic,
      ]);
    });

    test('withoutRecipeTag removes only that entry', () {
      expect(model.withoutRecipeTag('sour').recipeTags, const [classic]);
    });

    test('withoutRecipeTag leaves the recipes that carried it', () {
      expect(model.withoutRecipeTag('sour').recipes, model.recipes);
    });

    test('withoutRecipeTag of an unknown name changes nothing', () {
      expect(model.withoutRecipeTag('stirred'), model);
    });

    test('neither edit reaches the other vocabulary', () {
      expect(model.withRecipeTag(citrus).ingredientTags, model.ingredientTags);
      expect(
        model.withoutRecipeTag('citrus').ingredientTags,
        model.ingredientTags,
      );
    });
  });

  group('recipe tag rename', () {
    test('renames the entry where it stands, colour and all', () {
      final edited = model.withRecipeTagRenamed('sour', 'sours');
      expect(edited.recipeTags, const [
        Tag('sours', color: TagColor.rose),
        classic,
      ]);
      expect(edited.hasRecipeTag('sour'), isFalse);
    });

    test('rewrites every recipe carrying the tag, in place', () {
      final edited = model.withRecipeTagRenamed('sour', 'sours');
      expect(edited.recipeNamed('Whiskey Sour')?.tags, ['sours', 'classic']);
    });

    test('leaves a recipe that never carried it untouched', () {
      expect(
        model.withRecipeTagRenamed('sour', 'sours').recipeNamed('Negroni'),
        same(negroni),
      );
    });

    test('an unknown name changes nothing', () {
      expect(model.withRecipeTagRenamed('stirred', 'sour'), same(model));
    });

    test('a same-named ingredient tag is left where it stands', () {
      final shared = model.withIngredientTag(sour);
      final edited = shared.withRecipeTagRenamed('sour', 'sours');
      expect(edited.hasIngredientTag('sour'), isTrue);
      expect(edited.hasRecipeTag('sour'), isFalse);
    });

    test('renaming onto an existing name is rejected', () {
      expect(
        () => model.withRecipeTagRenamed('sour', 'classic'),
        throwsArgumentError,
      );
    });
  });

  group('ingredient tags', () {
    test('withIngredientTag adds an entry the vocabulary lacked', () {
      final edited = model.withIngredientTag(stirred);
      expect(edited.ingredientTags, const [citrus, oaked, stirred]);
    });

    test('withIngredientTag repaints the entry where it stands', () {
      final edited = model.withIngredientTag(
        const Tag('citrus', color: TagColor.indigo),
      );
      expect(edited.ingredientTags, const [
        Tag('citrus', color: TagColor.indigo),
        oaked,
      ]);
    });

    test('withoutIngredientTag removes only that entry', () {
      expect(model.withoutIngredientTag('citrus').ingredientTags, const [
        oaked,
      ]);
    });

    test('withoutIngredientTag leaves the ingredients that carried it', () {
      expect(
        model.withoutIngredientTag('citrus').ingredients,
        model.ingredients,
      );
    });

    test('withoutIngredientTag of an unknown name changes nothing', () {
      expect(model.withoutIngredientTag('stirred'), model);
    });

    test('neither edit reaches the other vocabulary', () {
      expect(model.withIngredientTag(sour).recipeTags, model.recipeTags);
      expect(model.withoutIngredientTag('sour').recipeTags, model.recipeTags);
    });
  });

  group('ingredient tag rename', () {
    test('renames the entry where it stands, colour and all', () {
      final edited = model.withIngredientTagRenamed('citrus', 'citrusy');
      expect(edited.ingredientTags, const [
        Tag('citrusy', color: TagColor.sand),
        oaked,
      ]);
      expect(edited.hasIngredientTag('citrus'), isFalse);
    });

    test('rewrites every ingredient carrying the tag, in place', () {
      final edited = model.withIngredientTagRenamed('citrus', 'citrusy');
      expect(edited.ingredientNamed('lemon juice')?.tags, ['citrusy']);
    });

    test('leaves an ingredient that never carried it untouched', () {
      final edited = model.withIngredientTagRenamed('citrus', 'citrusy');
      expect(edited.ingredientNamed('gin'), model.ingredientNamed('gin'));
      expect(edited.ingredientNamed('bourbon')?.tags, ['oaked']);
    });

    test('an unknown name changes nothing', () {
      expect(model.withIngredientTagRenamed('stirred', 'citrus'), same(model));
    });

    test('the recipes are none of its business', () {
      final edited = model.withIngredientTagRenamed('citrus', 'citrusy');
      expect(edited.recipes, model.recipes);
    });

    test('renaming onto an existing name is rejected', () {
      expect(
        () => model.withIngredientTagRenamed('citrus', 'oaked'),
        throwsArgumentError,
      );
    });
  });

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

    test('recipesUsingTag names them in model order', () {
      expect(model.recipesUsingTag('classic'), ['Whiskey Sour', 'Negroni']);
      expect(model.recipesUsingTag('sour'), ['Whiskey Sour']);
    });

    test('recipesUsingTag is empty when nothing carries it', () {
      expect(model.withRecipeTag(stirred).recipesUsingTag('stirred'), isEmpty);
    });

    test('ingredientsUsingTag names them in model order', () {
      final shared = model.withIngredientTags('gin', const ['oaked']);
      expect(shared.ingredientsUsingTag('oaked'), ['bourbon', 'gin']);
      expect(shared.ingredientsUsingTag('citrus'), ['lemon juice']);
    });

    test('ingredientsUsingTag is empty when nothing carries it', () {
      expect(
        model.withIngredientTag(stirred).ingredientsUsingTag('stirred'),
        isEmpty,
      );
    });

    test('each query looks only at its own side', () {
      final shared = model.withIngredientTag(sour).withRecipeTag(citrus);
      expect(shared.ingredientsUsingTag('sour'), isEmpty);
      expect(shared.recipesUsingTag('citrus'), isEmpty);
    });
  });
}
