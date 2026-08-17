/// The in-memory [BarStore] double: the seam that keeps state and widget tests
/// device-free (docs/components.md#data-contracts).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';

/// `base` rather than `final`: a test that needs one method to fail — a load
/// that throws, a save that cannot write — specialises that one and inherits
/// the rest, instead of standing up a sixth implementation of the interface.
base class MemoryBarStore implements BarStore {
  /// What the next [loadShelf] returns; a test seeds [Corrupt] to exercise the
  /// recovery path. Every [saveShelf] replaces it.
  LoadOutcome<Records> shelfOutcome;

  /// Per bar, what its [loadBar] returns. A bar with no entry is [Empty], as a
  /// bar whose file never landed is on disk.
  final Map<String, LoadOutcome<BarPayload>> barOutcomes = {};

  /// The records of the last [saveShelf], null until the first one.
  Records? savedShelf;

  /// Every bar written, newest per id, and how many writes have landed in all.
  final Map<String, (Bar, Collection)> savedBars = {};
  int saveCount = 0;

  /// The collection of the last [saveBar], whichever bar it was — the reading
  /// a one-bar test wants, where [savedBars] is the whole picture.
  Collection? saved;

  MemoryBarStore([Records? records])
    : shelfOutcome = records == null ? const Empty() : Loaded(records);

  /// A store already holding [bar] and its [collection] — the arrangement most
  /// tests want, and the one a hand-built [barOutcomes] entry gets wrong by
  /// leaving the index empty. Generative, so a specialising double can chain
  /// to it.
  MemoryBarStore.of(Bar bar, [Collection? collection])
    : shelfOutcome = Loaded((bars: [bar], openId: bar.id)) {
    barOutcomes[bar.id] = Loaded((
      name: bar.name,
      display: bar.display,
      collection: collection ?? Collection(),
    ));
  }

  @override
  Future<LoadOutcome<Records>> loadShelf() async => shelfOutcome;

  @override
  Future<LoadOutcome<BarPayload>> loadBar(String id) async =>
      barOutcomes[id] ?? const Empty();

  @override
  Future<void> saveShelf(Records records) async {
    savedShelf = records;
    shelfOutcome = Loaded(records);
  }

  @override
  Future<void> saveBar(Bar bar, Collection collection) async {
    savedBars[bar.id] = (bar, collection);
    saved = collection;
    saveCount++;
    barOutcomes[bar.id] = Loaded((
      name: bar.name,
      display: bar.display,
      collection: collection,
    ));
  }

  @override
  Future<void> removeBar(String id) async {
    savedBars.remove(id);
    barOutcomes.remove(id);
  }

  /// What each purpose was last handed, so a test can tell the copy going out
  /// to a reader from the nets an import and a delete keep back.
  final snapshots = <ExportPurpose, (Bar, Collection)>{};

  @override
  Future<String> exportSnapshot(
    Bar bar,
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  }) async {
    snapshots[purpose] = (bar, collection);
    return 'memory:${purpose.name}';
  }
}
