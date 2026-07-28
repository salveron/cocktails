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
    ingredients: const [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari'),
    ],
    tags: const [Tag('classic')],
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
      ).upsertIngredient(const Ingredient('sweet vermouth'));
      expect(modelOf(container).ingredientNamed('sweet vermouth'), isNotNull);
      await controllerOf(
        container,
      ).upsertIngredient(const Ingredient('campari', stock: StockLevel.in_));
      expect(modelOf(container).ingredients, hasLength(3));
      expect(
        modelOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
    });

    test('renameIngredient propagates into the recipes', () async {
      final container = await started();
      await controllerOf(container).renameIngredient('gin', 'dry gin');
      expect(
        modelOf(container).ingredientNamed('dry gin')?.stock,
        StockLevel.in_,
      );
      expect(
        modelOf(container).recipeNamed('Negroni')?.lines.first.ingredient,
        'dry gin',
      );
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
        const Ingredient('gin', stock: StockLevel.low),
      );
    });

    test('upsertTag adds an entry the vocabulary lacked', () async {
      final container = await started();
      await controllerOf(container).upsertTag(const Tag('bitter'));
      expect(modelOf(container).hasTag('bitter'), isTrue);
    });

    test('renameTag propagates into the recipes', () async {
      final container = await started();
      await controllerOf(container).renameTag('classic', 'classics');
      expect(modelOf(container).hasTag('classics'), isTrue);
      expect(modelOf(container).recipeNamed('Negroni')?.tags, ['classics']);
    });

    test('removeTag drops the entry', () async {
      final container = await started();
      await controllerOf(container).removeTag('classic');
      expect(modelOf(container).hasTag('classic'), isFalse);
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
      await controller.upsertTag(const Tag('bitter'));
      await controller.setStock('campari', StockLevel.low);
      await controller.markMade('Negroni');
      expect(store.saveCount, 3);
      expect(store.saved, modelOf(container));
    });

    test('an edit that changes nothing is not written', () async {
      final container = await started();
      final controller = controllerOf(container);
      await controller.setStock('rye', StockLevel.in_);
      await controller.renameTag('sour', 'sours');
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
