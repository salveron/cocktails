/// The in-memory [ModelStore] double: the seam that keeps state and widget
/// tests device-free (docs/components.md#state-contracts).
library;

import 'package:cocktails/domain/domain.dart';

import 'model_store.dart';

final class MemoryModelStore implements ModelStore {
  /// What the next [load] returns; a test seeds [Corrupt] to exercise the
  /// recovery path. Every [save] replaces it with the saved model.
  LoadOutcome outcome;

  /// The model of the last [save], null until the first one.
  Model? saved;

  int saveCount = 0;

  MemoryModelStore([Model? model])
    : outcome = model == null ? const Empty() : Loaded(model);

  @override
  Future<LoadOutcome> load() async => outcome;

  @override
  Future<void> save(Model model) async {
    saved = model;
    saveCount++;
    outcome = Loaded(model);
  }

  /// The model of the last [exportSnapshot], null until the first one.
  Model? exported;

  @override
  Future<String> exportSnapshot(Model model) async {
    exported = model;
    return 'memory:snapshot';
  }
}
