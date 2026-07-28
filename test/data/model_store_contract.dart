import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every [ModelStore] promises, whatever it stores into — run by the
/// file and memory store suites alike (docs/components.md#data-contracts).
void modelStoreContract(ModelStore Function() storeOf) {
  final model = Model(
    ingredients: const [Ingredient('gin', stock: StockLevel.in_)],
    tags: const [Tag('classic')],
  );

  test('an untouched store loads as Empty', () async {
    expect(await storeOf().load(), isA<Empty>());
  });

  test('load returns what save was given', () async {
    final store = storeOf();
    await store.save(model);
    final outcome = await store.load();
    expect(outcome, isA<Loaded>());
    expect((outcome as Loaded).model, model);
  });

  test('the last of several saves wins', () async {
    final store = storeOf();
    await store.save(model);
    await store.save(Model(tags: const [Tag('sour')]));
    expect(((await store.load()) as Loaded).model.ingredients, isEmpty);
  });

  test('exportSnapshot answers with a location', () async {
    final store = storeOf();
    await store.save(model);
    expect(await store.exportSnapshot(), isNotEmpty);
  });
}
