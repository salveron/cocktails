import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_store_contract.dart';

void main() {
  final model = Model(recipeTags: const [Tag('classic', color: TagColor.rose)]);

  group('ModelStore contract', () => modelStoreContract(MemoryModelStore.new));

  test('a seeded model loads without a save', () async {
    final store = MemoryModelStore(model);
    expect(((await store.load()) as Loaded).model, model);
    expect(store.saved, isNull);
  });

  test('saves are recorded for the test that made them', () async {
    final store = MemoryModelStore();
    await store.save(model);
    await store.save(model);
    expect(store.saveCount, 2);
    expect(store.saved, model);
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
      ..outcome = Corrupt([issue], recoveredFromBackup: model);
    final outcome = await store.load() as Corrupt;
    expect(outcome.issues, [issue]);
    expect(outcome.recoveredFromBackup, model);
  });
}
