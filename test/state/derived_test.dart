import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final stored = Model(
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

  ProviderContainer containerFor(Model model) {
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(MemoryModelStore(model)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// A container whose startup load has already resolved.
  Future<ProviderContainer> started(Model model) async {
    final container = containerFor(model);
    await container.read(modelProvider.future);
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

    test('holds nothing until the startup load lands', () {
      expect(containerFor(stored).read(availabilityProvider), isEmpty);
    });

    test('one stock tap moves every recipe that bottle stands in', () async {
      final container = await started(stored);
      await container
          .read(modelProvider.notifier)
          .setStock('gin', StockLevel.out);
      expect(container.read(availabilityProvider), {
        'Negroni': Availability.missing,
        'Gin Shot': Availability.missing,
      });
    });
  });
}
