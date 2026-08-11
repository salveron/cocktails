import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_store_contract.dart';

void main() {
  final collection = Collection(
    recipeTags: const [Tag('classic', color: TagColor.rose)],
  );

  group('ModelStore contract', () => modelStoreContract(MemoryModelStore.new));

  test('a seeded collection loads without a save', () async {
    final store = MemoryModelStore(collection);
    expect(((await store.load()) as Loaded).collection, collection);
    expect(store.saved, isNull);
  });

  test('saves are recorded for the test that made them', () async {
    final store = MemoryModelStore();
    await store.save(collection);
    await store.save(collection);
    expect(store.saveCount, 2);
    expect(store.saved, collection);
  });

  test('a seeded failure drives the recovery path', () async {
    final issue = SourcedIssue(
      ValidationIssue(
        const ['format'],
        ValidationIssueKind.unsupportedFormat,
        'Unsupported format version 2',
      ),
      1,
    );
    final store = MemoryModelStore()
      ..outcome = Corrupt([issue], recoveredFromBackup: collection);
    final outcome = await store.load() as Corrupt;
    expect(outcome.issues, [issue]);
    expect(outcome.recoveredFromBackup, collection);
  });
}
