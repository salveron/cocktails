/// The write surface `barWriterProvider` hands out, and every mutation made
/// through it. ADR 23: the surface is withheld whole rather than refusing per
/// call, so the null a screen reads is the same fact that hides its control.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/state_test_support.dart';
import '../support/test_support.dart';

void main() {
  setUpShelf();

  group('who gets one', () {
    /// A guest bar, which nothing but a refresh may write (FR-BAR-3).
    final visiting = Bar(
      id: 'f7a2b8',
      name: "Ada's bar",
      mode: BarMode.guest,
      source: const BarSource(
        via: Transport.file,
        at: 'ada.yaml',
        from: "Ada's bar",
      ),
    );

    test('an owned bar has one', () async {
      final container = await started();
      expect(container.read(barWriterProvider), isNotNull);
    });

    // The null must mean "someone else's bar", never "not loaded yet": a tap
    // landing during startup used to queue behind the load and still must.
    test('a bar still loading has one, so an early edit lands', () async {
      final container = containerFor(store);
      expect(container.read(barWriterProvider), isNotNull);
      await writerOf(container).setStock('campari', StockLevel.in_);
      expect(
        collectionOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
    });

    test('a guest bar has none', () async {
      final seeded = MemoryBarStore.of(visiting, stored);
      final container = await started(seeded);
      expect(container.read(barWriterProvider), isNull);
    });
  });

  group('mutations', () {
    test('setSettings replaces the settings', () async {
      final container = await started();
      await writerOf(container).setSettings(const Settings(partMl: 25));
      expect(collectionOf(container).settings, const Settings(partMl: 25));
    });

    test('upsertIngredient adds and replaces by name', () async {
      final container = await started();
      await writerOf(container).upsertIngredient(Ingredient('sweet vermouth'));
      expect(
        collectionOf(container).ingredientNamed('sweet vermouth'),
        isNotNull,
      );
      await writerOf(
        container,
      ).upsertIngredient(Ingredient('campari', stock: StockLevel.in_));
      expect(collectionOf(container).ingredients, hasLength(3));
      expect(
        collectionOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
    });

    test('upsertIngredient replacing a name renames in one edit', () async {
      final container = await started();
      await writerOf(container).upsertIngredient(
        Ingredient('dry gin', stock: StockLevel.in_, tags: const ['juniper']),
        replacing: 'gin',
      );
      final collection = collectionOf(container);
      expect(collection.ingredientNamed('gin'), isNull);
      expect(collection.ingredientNamed('dry gin')?.tags, ['juniper']);
      expect(
        collection.recipeNamed('Negroni')?.lines.first.ingredients.single,
        'dry gin',
      );
      // The whole entry is one edit, so one backup rotation covers it.
      expect(store.saveCount, 1);
    });

    test(
      'upsertIngredient replacing the name it keeps drops nothing',
      () async {
        final container = await started();
        await writerOf(container).upsertIngredient(
          Ingredient('gin', tags: const ['juniper']),
          replacing: 'gin',
        );
        expect(collectionOf(container).ingredients, hasLength(2));
        expect(collectionOf(container).ingredientNamed('gin')?.tags, [
          'juniper',
        ]);
      },
    );

    test('upsertIngredient replaces the tags the entry carried', () async {
      final container = await started();
      final writer = writerOf(container);
      final gin = Ingredient('gin', stock: StockLevel.in_);
      await writer.upsertIngredient(gin.copyWith(tags: const ['juniper']));
      expect(collectionOf(container).ingredientNamed('gin')?.tags, ['juniper']);
      await writer.upsertIngredient(gin);
      expect(collectionOf(container).ingredientNamed('gin')?.tags, isEmpty);
    });

    test('removeIngredient drops the entry', () async {
      final container = await started();
      await writerOf(container).removeIngredient('campari');
      expect(collectionOf(container).ingredientNamed('campari'), isNull);
    });

    test('setStock changes only the stock level', () async {
      final container = await started();
      await writerOf(container).setStock('gin', StockLevel.low);
      expect(
        collectionOf(container).ingredientNamed('gin'),
        Ingredient('gin', stock: StockLevel.low),
      );
    });

    test('upsertTag lands in the vocabulary it names and no other', () async {
      final container = await started();
      const bitter = Tag('bitter', color: TagColor.plum);
      await writerOf(container).upsertTag(TagKind.recipe, bitter);
      expect(collectionOf(container).hasTag(TagKind.recipe, 'bitter'), isTrue);
      expect(
        collectionOf(container).hasTag(TagKind.ingredient, 'bitter'),
        isFalse,
      );
    });

    test('upsertTag replacing a name propagates in one edit', () async {
      final container = await started();
      await writerOf(container).upsertTag(
        TagKind.recipe,
        const Tag('classics', color: TagColor.plum),
        replacing: 'classic',
      );
      final collection = collectionOf(container);
      expect(collection.hasTag(TagKind.recipe, 'classic'), isFalse);
      expect(collection.recipeNamed('Negroni')?.tags, ['classics']);
      // The whole entry is one edit, so one backup rotation covers it.
      expect(store.saveCount, 1);
    });

    test('upsertTag reaches the other vocabulary too', () async {
      final container = await started();
      await writerOf(container).upsertTag(
        TagKind.ingredient,
        const Tag('italiano', color: TagColor.teal),
        replacing: 'italian',
      );
      final collection = collectionOf(container);
      expect(collection.hasTag(TagKind.ingredient, 'italiano'), isTrue);
      expect(collection.ingredientNamed('campari')?.tags, ['italiano']);
    });

    test('upsertTag replacing the name it keeps drops nothing', () async {
      final container = await started();
      await writerOf(container).upsertTag(
        TagKind.ingredient,
        const Tag('juniper', color: TagColor.plum),
        replacing: 'juniper',
      );
      final collection = collectionOf(container);
      expect(collection.ingredientTags, hasLength(2));
      expect(collection.tagsOf(TagKind.ingredient).last.color, TagColor.plum);
    });

    test('removeTag drops the entry', () async {
      final container = await started();
      await writerOf(container).removeTag(TagKind.ingredient, 'juniper');
      expect(
        collectionOf(container).hasTag(TagKind.ingredient, 'juniper'),
        isFalse,
      );
    });

    test('upsertIngredient renames onto an alias it lets go of', () async {
      final container = await started(
        MemoryBarStore.of(
          bar,
          stored.withIngredient(
            Ingredient(
              'gin',
              stock: StockLevel.in_,
              aliases: const ['jenever'],
            ),
          ),
        ),
      );
      await writerOf(
        container,
      ).upsertIngredient(Ingredient('jenever'), replacing: 'gin');
      final collection = collectionOf(container);
      expect(collection.ingredientNamed('gin'), isNull);
      expect(collection.ingredientNamed('jenever')?.aliases, isEmpty);
      expect(
        collection.recipeNamed('Negroni')?.lines.first.ingredients.single,
        'jenever',
      );
    });

    test('upsertRecipe adds and replaces by name', () async {
      final container = await started();
      await writerOf(container).upsertRecipe(Recipe('Americano'));
      expect(collectionOf(container).recipes, hasLength(2));
      await writerOf(
        container,
      ).upsertRecipe(Recipe('Negroni', notes: 'stir with ice'));
      expect(collectionOf(container).recipes, hasLength(2));
      expect(
        collectionOf(container).recipeNamed('Negroni')?.notes,
        'stir with ice',
      );
    });

    test('upsertRecipe carries the ingredients it introduced', () async {
      final container = await started();
      await writerOf(container).upsertRecipe(
        Recipe(
          'Sazerac',
          lines: const [
            RecipeLine(Amount(2), 'part', ['rye']),
          ],
        ),
        addingIngredients: [Ingredient('rye'), Ingredient('absinthe')],
      );
      final collection = collectionOf(container);
      expect(collection.ingredientNamed('rye'), Ingredient('rye'));
      expect(collection.ingredientNamed('absinthe'), Ingredient('absinthe'));
      expect(collection.recipeNamed('Sazerac'), isNotNull);
      // The whole entry is one edit, so one collection reaches the disk and one
      // backup rotation covers the action.
      expect(store.saveCount, 1);
    });

    test(
      'upsertRecipe stores every line under the ingredient it names',
      () async {
        final container = await started(
          MemoryBarStore.of(
            bar,
            stored.withIngredient(
              Ingredient(
                'gin',
                stock: StockLevel.in_,
                aliases: const ['jenever'],
              ),
            ),
          ),
        );
        await writerOf(container).upsertRecipe(
          Recipe(
            'Gin Fizz',
            lines: const [
              RecipeLine(Amount(2), 'part', ['jenever']),
              RecipeLine(Amount(1), 'part', ['CAMPARI']),
            ],
          ),
        );
        expect(
          collectionOf(container)
              .recipeNamed('Gin Fizz')!
              .lines
              .map((line) => line.ingredients.single),
          ['gin', 'campari'],
        );
      },
    );

    test(
      'an ingredient this edit introduces answers for its own line',
      () async {
        final container = await started();
        await writerOf(container).upsertRecipe(
          Recipe(
            'Sazerac',
            lines: const [
              RecipeLine(Amount(2), 'part', ['RYE']),
            ],
          ),
          addingIngredients: [Ingredient('rye')],
        );
        expect(
          collectionOf(
            container,
          ).recipeNamed('Sazerac')!.lines.single.ingredients.single,
          'rye',
        );
        expect(store.saveCount, 1);
      },
    );

    test('upsertRecipe replacing a name renames in one edit', () async {
      final container = await started();
      await writerOf(container).upsertRecipe(
        negroni.copyWith(name: 'Boulevardier'),
        replacing: 'Negroni',
      );
      final collection = collectionOf(container);
      expect(collection.recipeNamed('Negroni'), isNull);
      expect(collection.recipeNamed('Boulevardier'), isNotNull);
      expect(store.saveCount, 1);
    });

    test('upsertRecipe replacing the name it keeps drops nothing', () async {
      final container = await started();
      await writerOf(container).upsertRecipe(
        negroni.copyWith(notes: 'stir with ice'),
        replacing: 'Negroni',
      );
      expect(collectionOf(container).recipes, hasLength(1));
      expect(
        collectionOf(container).recipeNamed('Negroni')?.notes,
        'stir with ice',
      );
    });

    test('removeRecipe drops the recipe', () async {
      final container = await started();
      await writerOf(container).removeRecipe('Negroni');
      expect(collectionOf(container).recipes, isEmpty);
    });
  });

  // ADR 23: the write surface is withheld whole rather than refusing per call,
  // so the null a screen reads is the same fact that hides its control.
}
