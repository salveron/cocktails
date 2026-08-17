import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_bar_store.dart';
import 'bar_store_contract.dart';

void main() {
  final collection = Collection(
    recipeTags: const [Tag('classic', color: TagColor.rose)],
  );
  final home = Bar(id: 'a1b2c3', name: 'Home bar', mode: BarMode.owner);

  group('BarStore contract', () => barStoreContract(MemoryBarStore.new));

  test('a seeded index loads without a save', () async {
    final store = MemoryBarStore((bars: [home], openId: home.id));
    expect(((await store.loadShelf()) as Loaded<Records>).value.bars, [home]);
    expect(store.savedShelf, isNull);
  });

  test('.of seeds the index and the bar together', () async {
    final store = MemoryBarStore.of(home, collection);
    expect(
      ((await store.loadShelf()) as Loaded<Records>).value.openId,
      home.id,
    );
    final payload =
        ((await store.loadBar(home.id)) as Loaded<BarPayload>).value;
    expect(payload.collection, collection);
    expect(store.saveCount, 0, reason: 'seeding is not a save');
  });

  test('saves are recorded for the test that made them', () async {
    final store = MemoryBarStore();
    await store.saveBar(home, collection);
    await store.saveBar(home, collection);
    expect(store.saveCount, 2);
    expect(store.savedBars[home.id]?.$2, collection);
  });

  test('a seeded failure drives the recovery path', () async {
    final issue = SourcedIssue(
      ValidationIssue(
        const ['format'],
        ValidationIssueKind.unsupportedFormat,
        'Unsupported format version 9',
      ),
      1,
    );
    final store = MemoryBarStore()
      ..barOutcomes[home.id] = Corrupt(
        [issue],
        recovered: (
          name: home.name,
          display: home.display,
          collection: collection,
        ),
      );
    final outcome = await store.loadBar(home.id) as Corrupt<BarPayload>;
    expect(outcome.issues, [issue]);
    expect(outcome.recovered?.collection, collection);
  });

  test('each export purpose is kept apart for reading back', () async {
    final store = MemoryBarStore();
    await store.exportSnapshot(home, collection);
    await store.exportSnapshot(
      home,
      Collection(),
      purpose: ExportPurpose.beforeDelete,
    );
    expect(store.snapshots[ExportPurpose.share]?.$2, collection);
    expect(store.snapshots[ExportPurpose.beforeDelete]?.$2, Collection());
  });
}
