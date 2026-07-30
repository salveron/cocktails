import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final negroni = Recipe(
    'Negroni',
    tags: ['classic'],
    lines: const [
      RecipeLine(Amount(1), Unit.part, 'gin'),
      RecipeLine(Amount(1), Unit.part, 'campari'),
    ],
  );
  final stored = Model(
    ingredients: [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari', tags: const ['italian']),
    ],
    ingredientTags: const [
      Tag('italian', color: TagColor.teal),
      Tag('juniper', color: TagColor.sand),
    ],
    recipeTags: const [Tag('classic', color: TagColor.rose)],
    recipes: [negroni],
  );
  // A date the real clock cannot return, so the stamp proves the injection.
  final today = DateTime(2024, 3, 5);

  late MemoryModelStore store;
  setUp(() => store = MemoryModelStore(stored));

  ProviderContainer containerFor(MemoryModelStore store, {DateTime? now}) {
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(store),
        if (now != null) clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A container whose startup load has already resolved.
  Future<ProviderContainer> started([MemoryModelStore? seeded]) async {
    final container = containerFor(seeded ?? store, now: today);
    await container.read(modelProvider.future);
    return container;
  }

  Model modelOf(ProviderContainer container) =>
      container.read(modelProvider).requireValue;

  ModelController controllerOf(ProviderContainer container) =>
      container.read(modelProvider.notifier);

  SourcedIssue issueAt(int? line) => SourcedIssue(
    ValidationIssue(
      const ['recipes', 0],
      ValidationIssueKind.unknownIngredient,
      'Unknown ingredient: "rye"',
    ),
    line,
  );

  group('startup load', () {
    test('an empty store starts the app on an empty model', () async {
      final container = await started(MemoryModelStore());
      expect(modelOf(container), Model());
      expect(container.read(startupIssuesProvider), isEmpty);
    });

    test('a stored model is loaded as it stands', () async {
      final container = await started();
      expect(modelOf(container), stored);
      expect(container.read(startupIssuesProvider), isEmpty);
    });

    test('a corrupt store starts on the recovered backup', () async {
      store.outcome = Corrupt([issueAt(4)], recoveredFromBackup: stored);
      final container = await started();
      expect(modelOf(container), stored);
      expect(container.read(startupIssuesProvider), [
        'line 4: Unknown ingredient: "rye"',
      ]);
    });

    test('a corrupt store with nothing to recover starts empty', () async {
      store.outcome = Corrupt([issueAt(4)]);
      final container = await started();
      expect(modelOf(container), Model());
      expect(container.read(startupIssuesProvider), hasLength(1));
    });

    test('an issue without a line still reports what is wrong', () async {
      store.outcome = Corrupt([issueAt(null)]);
      final container = await started();
      expect(container.read(startupIssuesProvider), [
        'Unknown ingredient: "rye"',
      ]);
    });

    test('the issues are published when the load resolves', () async {
      store.outcome = Corrupt([issueAt(4)]);
      final container = containerFor(store);
      expect(container.read(startupIssuesProvider), isEmpty);
      await container.read(modelProvider.future);
      expect(container.read(startupIssuesProvider), hasLength(1));
    });
  });

  group('mutations', () {
    test('setSettings replaces the settings', () async {
      final container = await started();
      await controllerOf(container).setSettings(const Settings(partMl: 25));
      expect(modelOf(container).settings, const Settings(partMl: 25));
    });

    test('upsertIngredient adds and replaces by name', () async {
      final container = await started();
      await controllerOf(
        container,
      ).upsertIngredient(Ingredient('sweet vermouth'));
      expect(modelOf(container).ingredientNamed('sweet vermouth'), isNotNull);
      await controllerOf(
        container,
      ).upsertIngredient(Ingredient('campari', stock: StockLevel.in_));
      expect(modelOf(container).ingredients, hasLength(3));
      expect(
        modelOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
    });

    test('upsertIngredient replacing a name renames in one edit', () async {
      final container = await started();
      await controllerOf(container).upsertIngredient(
        Ingredient('dry gin', stock: StockLevel.in_, tags: const ['juniper']),
        replacing: 'gin',
      );
      final model = modelOf(container);
      expect(model.ingredientNamed('gin'), isNull);
      expect(model.ingredientNamed('dry gin')?.tags, ['juniper']);
      expect(model.recipeNamed('Negroni')?.lines.first.ingredient, 'dry gin');
      // The whole entry is one edit, so one backup rotation covers it.
      expect(store.saveCount, 1);
    });

    test(
      'upsertIngredient replacing the name it keeps drops nothing',
      () async {
        final container = await started();
        await controllerOf(container).upsertIngredient(
          Ingredient('gin', tags: const ['juniper']),
          replacing: 'gin',
        );
        expect(modelOf(container).ingredients, hasLength(2));
        expect(modelOf(container).ingredientNamed('gin')?.tags, ['juniper']);
      },
    );

    test('upsertIngredient replaces the tags the entry carried', () async {
      final container = await started();
      final controller = controllerOf(container);
      final gin = Ingredient('gin', stock: StockLevel.in_);
      await controller.upsertIngredient(gin.copyWith(tags: const ['juniper']));
      expect(modelOf(container).ingredientNamed('gin')?.tags, ['juniper']);
      await controller.upsertIngredient(gin);
      expect(modelOf(container).ingredientNamed('gin')?.tags, isEmpty);
    });

    test('removeIngredient drops the entry', () async {
      final container = await started();
      await controllerOf(container).removeIngredient('campari');
      expect(modelOf(container).ingredientNamed('campari'), isNull);
    });

    test('setStock changes only the stock level', () async {
      final container = await started();
      await controllerOf(container).setStock('gin', StockLevel.low);
      expect(
        modelOf(container).ingredientNamed('gin'),
        Ingredient('gin', stock: StockLevel.low),
      );
    });

    test('upsertRecipeTag adds an entry the vocabulary lacked', () async {
      final container = await started();
      await controllerOf(
        container,
      ).upsertRecipeTag(const Tag('bitter', color: TagColor.plum));
      expect(modelOf(container).hasRecipeTag('bitter'), isTrue);
    });

    test('renameRecipeTag propagates into the recipes', () async {
      final container = await started();
      await controllerOf(container).renameRecipeTag('classic', 'classics');
      expect(modelOf(container).hasRecipeTag('classics'), isTrue);
      expect(modelOf(container).recipeNamed('Negroni')?.tags, ['classics']);
    });

    test('removeRecipeTag drops the entry', () async {
      final container = await started();
      await controllerOf(container).removeRecipeTag('classic');
      expect(modelOf(container).hasRecipeTag('classic'), isFalse);
    });

    test('upsertIngredientTag lands in the other vocabulary', () async {
      final container = await started();
      await controllerOf(
        container,
      ).upsertIngredientTag(const Tag('bitter', color: TagColor.plum));
      expect(modelOf(container).hasIngredientTag('bitter'), isTrue);
      expect(modelOf(container).hasRecipeTag('bitter'), isFalse);
    });

    test('renameIngredientTag propagates into the ingredients', () async {
      final container = await started();
      await controllerOf(container).renameIngredientTag('italian', 'italiano');
      expect(modelOf(container).hasIngredientTag('italiano'), isTrue);
      expect(modelOf(container).ingredientNamed('campari')?.tags, ['italiano']);
    });

    test('removeIngredientTag drops the entry', () async {
      final container = await started();
      await controllerOf(container).removeIngredientTag('juniper');
      expect(modelOf(container).hasIngredientTag('juniper'), isFalse);
    });

    test('upsertRecipe adds and replaces by name', () async {
      final container = await started();
      await controllerOf(container).upsertRecipe(Recipe('Americano'));
      expect(modelOf(container).recipes, hasLength(2));
      await controllerOf(
        container,
      ).upsertRecipe(Recipe('Negroni', notes: 'stir with ice'));
      expect(modelOf(container).recipes, hasLength(2));
      expect(modelOf(container).recipeNamed('Negroni')?.notes, 'stir with ice');
    });

    test('upsertRecipe carries the ingredients it introduced', () async {
      final container = await started();
      await controllerOf(container).upsertRecipe(
        Recipe(
          'Sazerac',
          lines: const [RecipeLine(Amount(2), Unit.part, 'rye')],
        ),
        addingIngredients: [Ingredient('rye'), Ingredient('absinthe')],
      );
      final model = modelOf(container);
      expect(model.ingredientNamed('rye'), Ingredient('rye'));
      expect(model.ingredientNamed('absinthe'), Ingredient('absinthe'));
      expect(model.recipeNamed('Sazerac'), isNotNull);
      // The whole entry is one edit, so one model reaches the disk and one
      // backup rotation covers the action.
      expect(store.saveCount, 1);
    });

    test('upsertRecipe replacing a name renames in one edit', () async {
      final container = await started();
      await controllerOf(container).upsertRecipe(
        negroni.copyWith(name: 'Boulevardier'),
        replacing: 'Negroni',
      );
      final model = modelOf(container);
      expect(model.recipeNamed('Negroni'), isNull);
      expect(model.recipeNamed('Boulevardier'), isNotNull);
      expect(store.saveCount, 1);
    });

    test('upsertRecipe replacing the name it keeps drops nothing', () async {
      final container = await started();
      await controllerOf(container).upsertRecipe(
        negroni.copyWith(notes: 'stir with ice'),
        replacing: 'Negroni',
      );
      expect(modelOf(container).recipes, hasLength(1));
      expect(modelOf(container).recipeNamed('Negroni')?.notes, 'stir with ice');
    });

    test('removeRecipe drops the recipe', () async {
      final container = await started();
      await controllerOf(container).removeRecipe('Negroni');
      expect(modelOf(container).recipes, isEmpty);
    });

    test('markMade stamps the clock and counts up', () async {
      final container = await started();
      await controllerOf(container).markMade('Negroni');
      expect(
        modelOf(container).recipeNamed('Negroni')?.made,
        MadeHistory(today, 1),
      );
      await controllerOf(container).markMade('Negroni');
      expect(
        modelOf(container).recipeNamed('Negroni')?.made,
        MadeHistory(today, 2),
      );
    });

    test('the clock is the real one unless a test replaces it', () async {
      final container = containerFor(store);
      expect(container.read(clockProvider), DateTime.now);
    });
  });

  group('persistence', () {
    test('an edit reaches the store as the model the app now holds', () async {
      final container = await started();
      await controllerOf(container).setStock('campari', StockLevel.in_);
      expect(store.saved, modelOf(container));
      expect(store.saveCount, 1);
    });

    test('every edit is written, in the order it was made', () async {
      final container = await started();
      final controller = controllerOf(container);
      await controller.upsertRecipeTag(
        const Tag('bitter', color: TagColor.plum),
      );
      await controller.setStock('campari', StockLevel.low);
      await controller.markMade('Negroni');
      expect(store.saveCount, 3);
      expect(store.saved, modelOf(container));
    });

    test('an edit that changes nothing is not written', () async {
      final container = await started();
      final controller = controllerOf(container);
      await controller.setStock('rye', StockLevel.in_);
      await controller.renameRecipeTag('sour', 'sours');
      await controller.markMade('Sazerac');
      expect(store.saveCount, 0);
      expect(modelOf(container), same(stored));
    });

    test('an edit made before the load resolves lands on top of it', () async {
      final container = containerFor(store, now: today);
      await controllerOf(container).setStock('campari', StockLevel.in_);
      expect(
        modelOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
      expect(modelOf(container).ingredientNamed('gin')?.stock, StockLevel.in_);
      expect(modelOf(container).recipes, [negroni]);
    });
  });
}
