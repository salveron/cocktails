/// The in-memory [ModelStore] double: the seam that keeps state and widget
/// tests device-free (docs/components.md#state-contracts).
library;

import 'package:cocktails/domain/domain.dart';

import 'model_store.dart';

final class MemoryModelStore implements ModelStore {
  /// What the next [load] returns; a test seeds [Corrupt] to exercise the
  /// recovery path. Every [save] replaces it with the saved collection.
  LoadOutcome outcome;

  /// The collection of the last [save], null until the first one.
  Collection? saved;

  int saveCount = 0;

  MemoryModelStore([Collection? collection])
    : outcome = collection == null ? const Empty() : Loaded(collection);

  @override
  Future<LoadOutcome> load() async => outcome;

  @override
  Future<void> save(Collection collection) async {
    saved = collection;
    saveCount++;
    outcome = Loaded(collection);
  }

  /// What each purpose was last handed, so a test can tell the copy going out
  /// to a reader from the one an import keeps back (FR-DAT-1, FR-DAT-3).
  final snapshots = <ExportPurpose, Collection>{};

  @override
  Future<String> exportSnapshot(
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  }) async {
    snapshots[purpose] = collection;
    return 'memory:${purpose.name}';
  }
}
