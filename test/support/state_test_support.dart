/// Support the state suites share: the `ProviderContainer` every state test
/// starts from — a store wired in, the clock named where a test dates
/// something, and the startup load met before the first assertion — the one
/// owned bar the controller suites edit, and the store that logs what reached
/// it. A widget test reaches the same seam through `ui_harness.dart`'s
/// `scoped` instead (docs/components.md#testing).
library;

import 'dart:async';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'domain_test_support.dart';
import 'memory_bar_store.dart';

/// A container over [store], the clock named only where [clock] is given —
/// most of what reads a bar does not date it — and whatever else a test file
/// wires in beyond the two every state test needs.
ProviderContainer containerOver(
  BarStore store, {
  DateTime Function()? clock,
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      barStoreProvider.overrideWithValue(store),
      if (clock != null) clockProvider.overrideWithValue(clock),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// [containerOver], its startup load already resolved — what a test reads
/// rather than a container still on its first load.
Future<ProviderContainer> startedOver(
  BarStore store, {
  DateTime Function()? clock,
  List<Override> overrides = const [],
}) async {
  final container = containerOver(store, clock: clock, overrides: overrides);
  await container.read(shelfProvider.future);
  return container;
}

late final Recipe negroni;
late final Collection stored;

/// What the clock answers, so every stamp a test meets is one it named.
late final DateTime now;

/// The one owned bar the controller suites run over — summarised, as every bar
/// on a shelf this app has written once is.
late final Bar bar;

late MemoryBarStore store;

/// Sets [negroni], [stored], [now] and [bar], and arranges for [store] to
/// hold a fresh copy of them before every test — call once at the top of a
/// file's own `main()`.
void setUpShelf() {
  negroni = negroniRecipe;
  stored = Collection(
    ingredients: [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari', tags: const ['italian']),
    ],
    ingredientTags: const [
      Tag('italian', color: TagColor.teal),
      Tag('juniper', color: TagColor.sand),
    ],
    recipeTags: const [Tag('classic', color: TagColor.rose)],
    recipes: [negroni],
  );
  now = DateTime.utc(2026, 8, 14, 11, 30);
  bar = Bar(
    id: 'a1b2c3',
    name: 'Home bar',
    mode: BarMode.owner,
  ).summarised(stored, at: now);
  setUp(() => store = MemoryBarStore.of(bar, stored));
}

BarContent contentOf(Collection collection, {FixedUnit? display}) =>
    (name: bar.name, display: display ?? bar.display, collection: collection);

/// [containerOver] with the clock already named — the arrangement every test
/// over [bar] wants, since [bar] is stamped [now].
ProviderContainer containerFor(MemoryBarStore store) =>
    containerOver(store, clock: () => now);

/// The same, its startup load already resolved.
Future<ProviderContainer> started([MemoryBarStore? seeded]) =>
    startedOver(seeded ?? store, clock: () => now);

Collection collectionOf(ProviderContainer container) =>
    container.read(collectionProvider);

ShelfController controllerOf(ProviderContainer container) =>
    container.read(shelfProvider.notifier);

/// The write surface, which a guest bar has none of (ADR 23). Non-null over
/// [bar], which is owned.
BarWriter writerOf(ProviderContainer container) =>
    container.read(barWriterProvider)!;

SourcedIssue issueAt(int? line) => SourcedIssue(
  ValidationIssue(
    const ['recipes', 0],
    ValidationIssueKind.unknownIngredient,
    'Unknown ingredient: "rye"',
  ),
  line,
);

base class WriteLog extends MemoryBarStore {
  WriteLog(super.records);

  final calls = <String>[];

  /// Every bar whose bytes were asked for, so a test can show that counting a
  /// shelf costs one read per bar and none for the one already resident.
  final loads = <String>[];

  @override
  Future<Outcome<BarContent>> loadBar(String id) {
    loads.add(id);
    return super.loadBar(id);
  }

  @override
  Future<void> saveBar(Bar bar, Collection collection) {
    calls.add('bar:${bar.id}');
    return super.saveBar(bar, collection);
  }

  @override
  Future<void> saveShelf(ShelfIndex records) {
    calls.add('shelf');
    return super.saveShelf(records);
  }

  @override
  Future<void> removeBar(String id) {
    calls.add('remove:$id');
    return super.removeBar(id);
  }
}

/// A channel that answers nothing until a test says so, so the order two
/// refreshes land in is the test's to choose rather than the scheduler's.
final class FakeChannel implements BarChannel {
  @override
  Transport get transport => Transport.file;

  /// Every source it was handed, in order.
  final asked = <BarSource>[];

  /// One per fetch still out, oldest first.
  final out = <Completer<Outcome<BarContent>?>>[];

  @override
  Future<Outcome<BarContent>?> fetch(BarSource source) {
    asked.add(source);
    final answering = Completer<Outcome<BarContent>?>();
    out.add(answering);
    return answering.future;
  }
}

/// An owner's half that answers when a test says so, so what is in flight is
/// the test's to look at rather than the scheduler's.
final class MemoryOfferings implements BarOfferings {
  @override
  Transport get transport => Transport.lan;

  final offered = <({String id, String name})>[];
  final withdrawn = <String>[];
  final out = <Completer<void>>[];
  Exception? refusing;

  @override
  Future<void> offer(String id, String name) {
    offered.add((id: id, name: name));
    return _answering();
  }

  @override
  Future<void> withdraw(String id) {
    withdrawn.add(id);
    return _answering();
  }

  Future<void> _answering() {
    final refused = refusing;
    if (refused != null) return Future.error(refused);
    final answering = Completer<void>();
    out.add(answering);
    return answering.future;
  }
}
