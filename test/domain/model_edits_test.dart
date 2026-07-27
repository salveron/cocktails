import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final whiskeySour = Recipe(
    'Whiskey Sour',
    tags: ['sour', 'classic'],
    lines: const [
      RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
      RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
      RecipeLine(Amount(0.5), Unit.part, 'egg white', isOptional: true),
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
    ingredients: const [
      Ingredient('bourbon', isBase: true, stock: StockLevel.in_),
      Ingredient('lemon juice', stock: StockLevel.low),
      Ingredient('egg white'),
      Ingredient('gin', isBase: true),
    ],
    tags: const [Tag('sour'), Tag('classic')],
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
      final edited = model.withIngredient(const Ingredient('rye'));
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
        const Ingredient('lemon juice', stock: StockLevel.in_),
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
        const Ingredient('bourbon', isBase: true, stock: StockLevel.low),
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
      expect(edited.ingredientNamed('rye')?.isBase, isTrue);
      expect(edited.ingredientNamed('bourbon'), isNull);
    });

    test('rewrites every referencing line', () {
      final edited = model.withIngredientRenamed('bourbon', 'rye');
      expect(edited.recipeNamed('Whiskey Sour')?.lines.first.ingredient, 'rye');
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

  group('tags', () {
    test('withTag adds an entry the vocabulary lacked', () {
      final edited = model.withTag(const Tag('stirred'));
      expect(edited.tags, const [Tag('sour'), Tag('classic'), Tag('stirred')]);
    });

    test('withTag of an existing name leaves one entry', () {
      expect(model.withTag(const Tag('sour')).tags, model.tags);
    });

    test('withoutTag removes only that entry', () {
      expect(model.withoutTag('sour').tags, const [Tag('classic')]);
    });

    test('withoutTag leaves the recipes that carried it', () {
      expect(model.withoutTag('sour').recipes, model.recipes);
    });

    test('withoutTag of an unknown name changes nothing', () {
      expect(model.withoutTag('stirred'), model);
    });
  });

  group('tag rename', () {
    test('renames the entry where it stands', () {
      final edited = model.withTagRenamed('sour', 'sours');
      expect(edited.tags, const [Tag('sours'), Tag('classic')]);
      expect(edited.hasTag('sour'), isFalse);
    });

    test('rewrites every recipe carrying the tag, in place', () {
      final edited = model.withTagRenamed('sour', 'sours');
      expect(edited.recipeNamed('Whiskey Sour')?.tags, ['sours', 'classic']);
    });

    test('leaves a recipe that never carried it untouched', () {
      expect(
        model.withTagRenamed('sour', 'sours').recipeNamed('Negroni'),
        same(negroni),
      );
    });

    test('an unknown name changes nothing', () {
      expect(model.withTagRenamed('stirred', 'sour'), same(model));
    });

    test('renaming onto an existing name is rejected', () {
      expect(
        () => model.withTagRenamed('sour', 'classic'),
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
      expect(
        model.withTag(const Tag('stirred')).recipesUsingTag('stirred'),
        isEmpty,
      );
    });
  });
}
