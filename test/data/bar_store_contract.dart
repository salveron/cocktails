import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every [BarStore] promises, whatever it stores into — run by the file
/// and memory store suites alike (docs/components.md#data-contracts).
void barStoreContract(BarStore Function() storeOf) {
  final collection = Collection(
    ingredients: [Ingredient('gin', stock: StockLevel.in_)],
    recipeTags: const [Tag('classic', color: TagColor.rose)],
  );
  final home = Bar(id: 'a1b2c3', name: 'Home bar', mode: BarMode.owner);
  final beach = Bar(
    id: 'd4e5f6',
    name: 'Beach bar',
    mode: BarMode.owner,
    display: FixedUnit.oz,
  );

  test('an untouched store holds no index', () async {
    expect(await storeOf().loadShelf(), isA<Empty<Records>>());
  });

  test('a bar the store never held is Empty, not a failure', () async {
    expect(await storeOf().loadBar('a1b2c3'), isA<Empty<BarPayload>>());
  });

  test('loadShelf returns what saveShelf was given', () async {
    final store = storeOf();
    await store.saveShelf((bars: [home, beach], openId: beach.id));
    final outcome = await store.loadShelf();
    expect(outcome, isA<Ok<Records>>());
    expect((outcome as Ok<Records>).value.bars, [home, beach]);
    expect(outcome.value.openId, beach.id);
  });

  test('a shelf with no bar open round-trips as one', () async {
    final store = storeOf();
    await store.saveShelf((bars: [home], openId: null));
    expect(((await store.loadShelf()) as Ok<Records>).value.openId, isNull);
  });

  test('loadBar returns the collection saveBar was given', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    final outcome = await store.loadBar(home.id);
    expect(outcome, isA<Ok<BarPayload>>());
    expect((outcome as Ok<BarPayload>).value.collection, collection);
  });

  test('a bar\'s file carries its name and reading unit (ADR 21)', () async {
    final store = storeOf();
    await store.saveBar(beach, collection);
    final payload = ((await store.loadBar(beach.id)) as Ok<BarPayload>).value;
    expect(payload.name, 'Beach bar');
    expect(payload.display, FixedUnit.oz);
  });

  test('the last of several saves of one bar wins', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(home, Collection());
    final payload = ((await store.loadBar(home.id)) as Ok<BarPayload>).value;
    expect(payload.collection.ingredients, isEmpty);
  });

  test('saving one bar leaves another\'s contents alone (FR-BAR-1)', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(beach, Collection());
    final payload = ((await store.loadBar(home.id)) as Ok<BarPayload>).value;
    expect(payload.collection, collection);
  });

  test('removeBar takes that bar and leaves the rest (FR-BAR-2)', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(beach, collection);
    await store.removeBar(home.id);
    expect(await store.loadBar(home.id), isA<Empty<BarPayload>>());
    expect(await store.loadBar(beach.id), isA<Ok<BarPayload>>());
  });

  test('removing a bar the store never held changes nothing', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.removeBar('nothing');
    expect(await store.loadBar(home.id), isA<Ok<BarPayload>>());
  });

  test('every export purpose answers with a location', () async {
    final store = storeOf();
    for (final purpose in ExportPurpose.values) {
      expect(
        await store.exportSnapshot(home, collection, purpose: purpose),
        isNotEmpty,
        reason: purpose.name,
      );
    }
  });
}
