/// The in-memory [BarStore] double every suite runs over to stay device-free
/// (docs/components.md#testing).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';

/// `base` rather than `final`: a test needing one method to fail specialises
/// that one and inherits the rest, rather than a sixth implementation.
base class MemoryBarStore implements BarStore {
  /// What the next [loadShelf] returns; a test seeds [Rejected] to exercise
  /// the recovery path. Every [saveShelf] replaces it.
  Outcome<ShelfIndex> shelfOutcome;

  /// Per bar, what its [loadBar] returns. A bar with no entry is [Empty], as a
  /// bar whose file never landed is on disk.
  final Map<String, Outcome<BarContent>> barOutcomes = {};

  /// What has been written, each null or empty until the first save of its
  /// kind: the last index, every bar newest-per-id, how many writes landed in
  /// all, and the last collection whichever bar it belonged to — [saved] being
  /// the reading a one-bar test wants, [savedBars] the whole picture.
  ShelfIndex? savedShelf;
  final Map<String, (Bar, Collection)> savedBars = {};
  int saveCount = 0;
  Collection? saved;

  MemoryBarStore([ShelfIndex? records])
    : shelfOutcome = records == null ? const Empty() : Ok(records);

  /// A store already holding [bar] and its [collection] — what most tests want,
  /// and what a hand-built [barOutcomes] entry gets wrong by leaving the index
  /// empty. Generative, so a specialising double can chain to it.
  MemoryBarStore.of(Bar bar, [Collection? collection])
    : shelfOutcome = Ok((bars: [bar], openId: bar.id)) {
    barOutcomes[bar.id] = Ok((
      name: bar.name,
      display: bar.display,
      collection: collection ?? Collection(),
    ));
  }

  @override
  Future<Outcome<ShelfIndex>> loadShelf() async => shelfOutcome;

  @override
  Future<Outcome<BarContent>> loadBar(String id) async =>
      barOutcomes[id] ?? const Empty();

  @override
  Future<void> saveShelf(ShelfIndex records) async {
    savedShelf = records;
    shelfOutcome = Ok(records);
  }

  @override
  Future<void> saveBar(Bar bar, Collection collection) async {
    savedBars[bar.id] = (bar, collection);
    saved = collection;
    saveCount++;
    barOutcomes[bar.id] = Ok((
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
