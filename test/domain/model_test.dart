import 'package:cocktails/domain/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Amount', () {
    test('single value is not a range', () {
      const amount = Amount(1.5);
      expect(amount.min, 1.5);
      expect(amount.max, 1.5);
      expect(amount.isRange, isFalse);
    });

    test('range exposes both ends', () {
      const amount = Amount.range(1.5, 2);
      expect(amount.min, 1.5);
      expect(amount.max, 2);
      expect(amount.isRange, isTrue);
    });

    test('range with equal ends equals the single value', () {
      expect(const Amount.range(2, 2), const Amount(2));
    });

    test('equality and hashCode isolate each field', () {
      const amount = Amount.range(1.5, 2);
      expect(amount, const Amount.range(1.5, 2));
      expect(amount.hashCode, const Amount.range(1.5, 2).hashCode);
      expect(amount, isNot(const Amount.range(1, 2)));
      expect(amount, isNot(const Amount.range(1.5, 3)));
    });
  });

  group('Ingredient', () {
    Ingredient build({
      String name = 'gin',
      bool isBase = false,
      StockLevel stock = StockLevel.outOfStock,
    }) => Ingredient(name, isBase: isBase, stock: stock);

    test('defaults: not a base spirit, out of stock', () {
      const ingredient = Ingredient('bourbon');
      expect(ingredient.isBase, isFalse);
      expect(ingredient.stock, StockLevel.outOfStock);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(name: 'rum')));
      expect(build(), isNot(build(isBase: true)));
      expect(build(), isNot(build(stock: StockLevel.lowStock)));
    });
  });

  group('Tag', () {
    test('equality and hashCode', () {
      expect(const Tag('sour'), const Tag('sour'));
      expect(const Tag('sour').hashCode, const Tag('sour').hashCode);
      expect(const Tag('sour'), isNot(const Tag('classic')));
    });
  });

  group('RecipeLine', () {
    RecipeLine build({
      Amount amount = const Amount(0.5),
      Unit unit = Unit.part,
      String ingredient = 'egg white',
      bool isOptional = false,
    }) => RecipeLine(amount, unit, ingredient, isOptional: isOptional);

    test('defaults to required', () {
      const line = RecipeLine(Amount(1.5), Unit.part, 'bourbon');
      expect(line.isOptional, isFalse);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(amount: const Amount(1))));
      expect(build(), isNot(build(unit: Unit.ml)));
      expect(build(), isNot(build(ingredient: 'gin')));
      expect(build(), isNot(build(isOptional: true)));
    });
  });

  group('MadeHistory', () {
    test('keeps the date, drops the time of day', () {
      final history = MadeHistory(DateTime(2026, 7, 18, 23, 59), 12);
      expect(history.last, DateTime(2026, 7, 18));
      expect(history, MadeHistory(DateTime(2026, 7, 18), 12));
    });

    test('equality and hashCode isolate each field', () {
      MadeHistory build({int day = 18, int times = 12}) =>
          MadeHistory(DateTime(2026, 7, day), times);
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(day: 19)));
      expect(build(), isNot(build(times: 13)));
    });
  });

  group('Settings', () {
    test('defaults match the data-format example', () {
      const settings = Settings();
      expect(settings.partMl, 30);
      expect(settings.display, DisplayUnit.part);
    });

    test('equality and hashCode isolate each field', () {
      expect(const Settings(), const Settings());
      expect(const Settings().hashCode, const Settings().hashCode);
      expect(const Settings(), isNot(const Settings(partMl: 22.5)));
      expect(const Settings(), isNot(const Settings(display: DisplayUnit.ml)));
    });
  });

  group('Recipe', () {
    Recipe build({
      String name = 'Whiskey Sour',
      List<String> tags = const ['sour'],
      List<RecipeLine> lines = const [
        RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
      ],
      String notes = 'dry shake, then shake with ice',
      int? madeTimes = 12,
    }) => Recipe(
      name,
      tags: tags,
      lines: lines,
      notes: notes,
      made: madeTimes == null
          ? null
          : MadeHistory(DateTime(2026, 7, 18), madeTimes),
    );

    test('defaults: no tags, no lines, empty notes, never made', () {
      final recipe = Recipe('Whiskey Sour');
      expect(recipe.tags, isEmpty);
      expect(recipe.lines, isEmpty);
      expect(recipe.notes, isEmpty);
      expect(recipe.made, isNull);
    });

    test('collections are unmodifiable', () {
      final recipe = Recipe('Whiskey Sour', tags: ['sour']);
      expect(() => recipe.tags.add('classic'), throwsUnsupportedError);
      expect(
        () => recipe.lines.add(const RecipeLine(Amount(1), Unit.part, 'gin')),
        throwsUnsupportedError,
      );
    });

    test('detached from the lists it was built from', () {
      final tags = ['sour'];
      final recipe = Recipe('Whiskey Sour', tags: tags);
      tags.add('classic');
      expect(recipe.tags, ['sour']);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(name: 'Sazerac')));
      expect(build(), isNot(build(tags: const ['sour', 'classic'])));
      expect(
        build(),
        isNot(
          build(lines: const [RecipeLine(Amount(2), Unit.part, 'bourbon')]),
        ),
      );
      expect(build(), isNot(build(notes: 'stirred')));
      expect(build(), isNot(build(madeTimes: 13)));
      expect(build(), isNot(build(madeTimes: null)));
    });
  });

  group('Model', () {
    Model build({
      Settings settings = const Settings(partMl: 25),
      List<Ingredient> ingredients = const [
        Ingredient('bourbon', isBase: true),
      ],
      List<Tag> tags = const [Tag('sour')],
      List<Recipe>? recipes,
    }) => Model(
      settings: settings,
      ingredients: ingredients,
      tags: tags,
      recipes:
          recipes ??
          [
            Recipe('Whiskey Sour', tags: ['sour']),
          ],
    );

    test('starts empty with default settings', () {
      final model = Model();
      expect(model.ingredients, isEmpty);
      expect(model.tags, isEmpty);
      expect(model.recipes, isEmpty);
      expect(model.settings, const Settings());
    });

    test('rejects duplicate names within each kind', () {
      expect(
        () => Model(
          ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ingredient'), contains('gin')),
          ),
        ),
      );
      expect(
        () => Model(tags: [const Tag('sour'), const Tag('sour')]),
        throwsArgumentError,
      );
      expect(
        () => Model(recipes: [Recipe('Negroni'), Recipe('Negroni')]),
        throwsArgumentError,
      );
    });

    test('allows the same name across kinds', () {
      final model = Model(
        ingredients: [const Ingredient('sour')],
        tags: [const Tag('sour')],
        recipes: [Recipe('sour')],
      );
      expect(model.ingredients.single.name, 'sour');
    });

    test('collections are unmodifiable', () {
      final model = Model();
      expect(
        () => model.ingredients.add(const Ingredient('gin')),
        throwsUnsupportedError,
      );
      expect(() => model.tags.add(const Tag('sour')), throwsUnsupportedError);
      expect(
        () => model.recipes.add(Recipe('Negroni')),
        throwsUnsupportedError,
      );
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(settings: const Settings())));
      expect(build(), isNot(build(ingredients: const [Ingredient('gin')])));
      expect(build(), isNot(build(tags: const [Tag('classic')])));
      expect(build(), isNot(build(recipes: [Recipe('Negroni')])));
    });
  });

  group('duplicateNameIndexes', () {
    test('empty and unique lists have no duplicates', () {
      expect(duplicateNameIndexes([]), isEmpty);
      expect(duplicateNameIndexes(['a', 'b']), isEmpty);
    });

    test('reports every repeated position', () {
      expect(duplicateNameIndexes(['a', 'b', 'a', 'a']), [2, 3]);
    });
  });
}
