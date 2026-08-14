import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stored = Collection(
    ingredients: [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari', stock: StockLevel.in_),
    ],
    recipes: [
      Recipe(
        'Negroni',
        lines: const [
          RecipeLine(Amount(1), 'part', ['gin']),
          RecipeLine(Amount(1), 'part', ['campari']),
        ],
      ),
      Recipe(
        'Gin Shot',
        lines: const [
          RecipeLine(Amount(1), 'part', ['gin']),
        ],
      ),
    ],
  );

  ProviderContainer containerFor(Collection collection) {
    final container = ProviderContainer(
      overrides: [
        barStoreProvider.overrideWithValue(
          MemoryBarStore.of(
            Bar(id: 'a1b2c3', name: 'Home bar', mode: BarMode.owner),
            collection,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A container whose startup load has already resolved.
  Future<ProviderContainer> started(Collection collection) async {
    final container = containerFor(collection);
    await container.read(shelfProvider.future);
    return container;
  }

  group('availabilityProvider', () {
    test('answers for every recipe, by name', () async {
      final container = await started(stored);
      expect(container.read(availabilityProvider), {
        'Negroni': Availability.makeable,
        'Gin Shot': Availability.makeable,
      });
    });

    test('one stock tap moves every recipe that bottle stands in', () async {
      final container = await started(stored);
      await container.read(barWriterProvider)!.setStock('gin', StockLevel.out);
      expect(container.read(availabilityProvider), {
        'Negroni': Availability.missing,
        'Gin Shot': Availability.missing,
      });
    });
  });

  group('purchasesProvider', () {
    /// A bar out of both bottles: the pair unlocks both recipes and gin alone
    /// unlocks one, so the one answer has to carry two sizes to be complete.
    final short = Collection(
      ingredients: [Ingredient('gin'), Ingredient('campari')],
      recipes: stored.recipes,
    );

    test(
      'searches at the largest budget, every size in the one answer',
      () async {
        final container = await started(short);
        expect(container.read(purchasesProvider(false)).map((p) => p.bottles), [
          ['campari', 'gin'],
          ['gin'],
        ]);
      },
    );

    test('answers each reading of what is short separately (ADR 16)', () async {
      final container = await started(
        Collection(
          ingredients: [Ingredient('gin', stock: StockLevel.low)],
          recipes: [stored.recipes.last],
        ),
      );
      expect(container.read(purchasesProvider(false)), isEmpty);
      expect(container.read(purchasesProvider(true)).single.bottles, ['gin']);
    });
  });

  // What it answers with once the load has landed is proven by every mutation
  // in shelf_controller_test, which reads the open bar's collection through it.
  group('collectionProvider', () {
    // The shell meets the load and draws no screen until it has answered
    // (docs/ui-design.md#app-shell), so this is the reading of a provider no
    // widget can be built early enough to make — a throw, not an empty
    // collection standing in for one nobody has read yet.
    test('refuses to stand in for a collection not yet read', () {
      expect(
        () => containerFor(stored).read(collectionProvider),
        throwsStateError,
      );
    });
  });
}
