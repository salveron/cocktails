import 'dart:convert';
import 'dart:typed_data';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final negroni = Recipe(
    'Negroni',
    tags: ['classic'],
    lines: const [
      RecipeLine(Amount(1), 'part', ['gin']),
      RecipeLine(Amount(1), 'part', ['campari']),
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
      expect(
        model.recipeNamed('Negroni')?.lines.first.ingredients.single,
        'dry gin',
      );
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

    test('upsertTag lands in the vocabulary it names and no other', () async {
      final container = await started();
      const bitter = Tag('bitter', color: TagColor.plum);
      await controllerOf(container).upsertTag(TagKind.recipe, bitter);
      expect(modelOf(container).hasTag(TagKind.recipe, 'bitter'), isTrue);
      expect(modelOf(container).hasTag(TagKind.ingredient, 'bitter'), isFalse);
    });

    test('upsertTag replacing a name propagates in one edit', () async {
      final container = await started();
      await controllerOf(container).upsertTag(
        TagKind.recipe,
        const Tag('classics', color: TagColor.plum),
        replacing: 'classic',
      );
      final model = modelOf(container);
      expect(model.hasTag(TagKind.recipe, 'classic'), isFalse);
      expect(model.recipeNamed('Negroni')?.tags, ['classics']);
      // The whole entry is one edit, so one backup rotation covers it.
      expect(store.saveCount, 1);
    });

    test('upsertTag reaches the other vocabulary too', () async {
      final container = await started();
      await controllerOf(container).upsertTag(
        TagKind.ingredient,
        const Tag('italiano', color: TagColor.teal),
        replacing: 'italian',
      );
      final model = modelOf(container);
      expect(model.hasTag(TagKind.ingredient, 'italiano'), isTrue);
      expect(model.ingredientNamed('campari')?.tags, ['italiano']);
    });

    test('upsertTag replacing the name it keeps drops nothing', () async {
      final container = await started();
      await controllerOf(container).upsertTag(
        TagKind.ingredient,
        const Tag('juniper', color: TagColor.plum),
        replacing: 'juniper',
      );
      final model = modelOf(container);
      expect(model.ingredientTags, hasLength(2));
      expect(model.tagsOf(TagKind.ingredient).last.color, TagColor.plum);
    });

    test('removeTag drops the entry', () async {
      final container = await started();
      await controllerOf(container).removeTag(TagKind.ingredient, 'juniper');
      expect(modelOf(container).hasTag(TagKind.ingredient, 'juniper'), isFalse);
    });

    test('upsertIngredient renames onto an alias it lets go of', () async {
      final container = await started(
        MemoryModelStore(
          stored.withIngredient(
            Ingredient(
              'gin',
              stock: StockLevel.in_,
              aliases: const ['jenever'],
            ),
          ),
        ),
      );
      await controllerOf(
        container,
      ).upsertIngredient(Ingredient('jenever'), replacing: 'gin');
      final model = modelOf(container);
      expect(model.ingredientNamed('gin'), isNull);
      expect(model.ingredientNamed('jenever')?.aliases, isEmpty);
      expect(
        model.recipeNamed('Negroni')?.lines.first.ingredients.single,
        'jenever',
      );
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
          lines: const [
            RecipeLine(Amount(2), 'part', ['rye']),
          ],
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

    test('upsertRecipe stores every line under the bottle it names', () async {
      final container = await started(
        MemoryModelStore(
          stored.withIngredient(
            Ingredient(
              'gin',
              stock: StockLevel.in_,
              aliases: const ['jenever'],
            ),
          ),
        ),
      );
      await controllerOf(container).upsertRecipe(
        Recipe(
          'Gin Fizz',
          lines: const [
            RecipeLine(Amount(2), 'part', ['jenever']),
            RecipeLine(Amount(1), 'part', ['CAMPARI']),
          ],
        ),
      );
      expect(
        modelOf(
          container,
        ).recipeNamed('Gin Fizz')!.lines.map((line) => line.ingredients.single),
        ['gin', 'campari'],
      );
    });

    test('a bottle this edit introduces answers for its own line', () async {
      final container = await started();
      await controllerOf(container).upsertRecipe(
        Recipe(
          'Sazerac',
          lines: const [
            RecipeLine(Amount(2), 'part', ['RYE']),
          ],
        ),
        addingIngredients: [Ingredient('rye')],
      );
      expect(
        modelOf(
          container,
        ).recipeNamed('Sazerac')!.lines.single.ingredients.single,
        'rye',
      );
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

    test('setMade puts a history back, and a null clears it', () async {
      final container = await started();
      final controller = controllerOf(container);
      final before = MadeHistory(DateTime(2026, 1, 3), 4);

      await controller.setMade('Negroni', before);
      expect(modelOf(container).recipeNamed('Negroni')?.made, before);
      await controller.setMade('Negroni', null);
      expect(modelOf(container).recipeNamed('Negroni')?.made, isNull);
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
      await controller.upsertTag(
        TagKind.recipe,
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
      await controller.upsertTag(
        TagKind.recipe,
        const Tag('classic', color: TagColor.rose),
        replacing: 'classic',
      );
      await controller.markMade('Sazerac');
      await controller.setMade('Negroni', null);
      expect(store.saveCount, 0);
      expect(modelOf(container), same(stored));
    });

    test('export hands the store the model on screen (FR-DAT-1)', () async {
      final container = await started();
      expect(await controllerOf(container).export(), isNotEmpty);
      expect(store.snapshots[ExportPurpose.share], stored);
    });

    test('an export asked for before the load waits for it', () async {
      final container = containerFor(store, now: today);
      await controllerOf(container).export();
      expect(store.snapshots[ExportPurpose.share], stored);
    });

    test('a session recovered from a damaged file exports what it '
        'recovered, not that file (ADR 18)', () async {
      final damaged = MemoryModelStore()
        ..outcome = Corrupt([issueAt(4)], recoveredFromBackup: stored);
      final container = await started(damaged);
      await controllerOf(container).export();
      expect(damaged.snapshots[ExportPurpose.share], stored);
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

  group('import', () {
    final incoming = Model(
      ingredients: [Ingredient('rye', stock: StockLevel.low)],
      recipes: [
        Recipe(
          'Sazerac',
          lines: const [
            RecipeLine(Amount(2), 'part', ['rye']),
          ],
        ),
      ],
    );
    final incomingFile = const YamlCodec().encode(incoming);

    test('a file that decodes reviews as the collection it holds', () async {
      final container = await started();
      final review = controllerOf(container).review(incomingFile);
      expect(review.model, incoming);
      expect(review.issues, isEmpty);
    });

    test('a review touches nothing on its own (FR-DAT-3)', () async {
      final container = await started();
      controllerOf(container).review(incomingFile);
      expect(modelOf(container), stored);
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    test('a file that does not decode reviews as issues, placed '
        '(FR-DAT-4)', () async {
      final container = await started();
      final review = controllerOf(container).review('''
format: 1
recipes:
  - name: Sazerac
    lines: ["2 parts rye"]
''');
      expect(review.model, isNull);
      expect(review.issues, hasLength(1));
      expect(review.issues.single, contains('rye'));
      expect(review.issues.single, startsWith('line '));
    });

    test('a file that is not the format at all is refused, not crashed', () {
      final review = ModelController().review('not a cocktail in sight');
      expect(review.model, isNull);
      expect(review.issues, hasLength(1));
    });

    test('replacing keeps a copy of what it replaced first '
        '(FR-DAT-3)', () async {
      final container = await started();
      await controllerOf(container).replaceAll(incoming);
      // The copy is the collection that stood before, never the one arriving.
      expect(store.snapshots[ExportPurpose.beforeImport], stored);
      expect(modelOf(container), incoming);
      expect(store.saved, incoming);
    });

    test('the copy it keeps is not the one an export shares', () async {
      final container = await started();
      await controllerOf(container).export();
      await controllerOf(container).replaceAll(incoming);
      // Two copies, two purposes: the export slot still holds what went out to
      // a reader, so an import cannot write over it.
      expect(store.snapshots[ExportPurpose.share], stored);
      expect(store.snapshots[ExportPurpose.beforeImport], stored);
    });

    test('a replace asked for before the load waits for it', () async {
      final container = containerFor(store, now: today);
      await controllerOf(container).replaceAll(incoming);
      // Not the empty model the copy would hold had it run before the load.
      expect(store.snapshots[ExportPurpose.beforeImport], stored);
      expect(modelOf(container), incoming);
    });

    test(
      'an exported file imports as the same collection (FR-DAT-5)',
      () async {
        final container = await started();
        final controller = controllerOf(container);
        await controller.export();
        final exported = store.snapshots[ExportPurpose.share]!;
        final review = controller.review(const YamlCodec().encode(exported));
        expect(review.issues, isEmpty);
        expect(review.model, stored);
      },
    );
  });

  /// The seam's own reading, over a file shaped the way `file_selector_android`
  /// answers: `XFile.fromData`, whose `readAsString` ignores the encoding asked
  /// of it. Overriding the picker with a plain `String` never reached this.
  group('a picked file reads as UTF-8', () {
    test('a name outside ASCII arrives as it left', () async {
      final picked = XFile.fromData(utf8.encode('Orange Curaçao'));
      expect(await pickedText(picked), 'Orange Curaçao');
    });

    test('an export picked back keeps the spelling it went out with', () async {
      final exported = Model(ingredients: [Ingredient('Orange Curaçao')]);
      final onDisk = const YamlCodec().encode(exported);
      final container = await started();

      final text = await pickedText(XFile.fromData(utf8.encode(onDisk)));

      expect(controllerOf(container).review(text).model, exported);
    });

    test('bytes that are not UTF-8 are refused, not guessed at', () async {
      final picked = XFile.fromData(Uint8List.fromList([0x61, 0xFF, 0x62]));
      await expectLater(pickedText(picked), throwsFormatException);
    });
  });
}
