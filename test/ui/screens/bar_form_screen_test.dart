/// Founding a bar (FR-BAR-2/7): the name, where its contents come from, and —
/// where a file carried them — whose bar it becomes. One file, two destinations
/// (docs/ui-design.md#bars).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/ui_finders.dart';
import '../../support/ui_fixtures.dart';
import '../../support/ui_harness.dart';
import '../../support/memory_bar_store.dart';

void main() {
  /// Three recipes and nine ingredients against the one recipe and two
  /// ingredients the app opens over, so nothing a card counts can be read off
  /// the store and pass for the file's.
  final sharedFile = fileOf(recipeCollection);

  /// The form as a reader reaches it, over a store holding [smallCollection]
  /// in one owned bar, with the system's picker answering [picked].
  Future<MemoryBarStore> openForm(
    WidgetTester tester, {
    Future<String?> Function()? picked,
    List<Override> overrides = const [],
  }) async {
    final store = MemoryBarStore.of(testBar(), smallCollection);
    await pumpApp(tester, store: store, picker: picked, overrides: overrides);
    await tap(tester, find.byTooltip('Settings'));
    await tap(tester, find.text('Change bar'));
    await tap(tester, find.byTooltip('New bar'));
    return store;
  }

  /// The form with [picked] already taken off the picker.
  Future<MemoryBarStore> withFile(WidgetTester tester, String picked) async {
    final store = await openForm(tester, picked: () async => picked);
    await tap(tester, find.text('From import'));
    return store;
  }

  /// The bar the shelf was last written holding open, and what reached its file.
  ({Bar bar, Collection? collection}) founded(MemoryBarStore store) {
    final shelf = store.savedShelf!;
    final bar = shelf.bars.firstWhere((bar) => bar.id == shelf.openId);
    return (bar: bar, collection: store.savedBars[bar.id]?.$2);
  }

  group('a bar of one\'s own, empty', () {
    testWidgets('the name leads, and the making of it opens it', (
      tester,
    ) async {
      final store = await openForm(tester);
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Save'));
      // Past the bar list this was reached through, and into the new bar.
      expect(shellTitle('Recipes', bar: 'Cellar'), findsOneWidget);
      expect(find.text('Negroni'), findsNothing);
      final made = founded(store);
      expect(made.bar.mode, BarMode.owner);
      expect(made.collection, Collection());
    });

    testWidgets('a name of nothing but spaces saves nothing', (tester) async {
      await openForm(tester);
      expect(saveEnabled(tester), isFalse);
      await typeInto(tester, barNameField, '   ');
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('an untouched form pops without asking', (tester) async {
      await openForm(tester);
      await back(tester);
      expect(find.text('Discard this bar?'), findsNothing);
      // Back on the list it was reached from.
      expect(find.widgetWithText(AppBar, 'Bars'), findsOneWidget);
    });

    testWidgets('one with a name typed into it asks first', (tester) async {
      await openForm(tester);
      await typeInto(tester, barNameField, 'Cellar');
      await back(tester);
      expect(find.text('Discard this bar?'), findsOneWidget);
    });
  });

  group('a file picked into it', () {
    testWidgets('names the bar and says what it holds', (tester) async {
      await withFile(tester, sharedFile);
      // The file's own name, the reader having offered none.
      expect(
        tester.widget<TextField>(barNameField).controller?.text,
        "Ada's bar",
      );
      expect(find.text('3 recipes'), findsOneWidget);
      expect(find.text('9 ingredients'), findsOneWidget);
      expect(find.text('2 tags'), findsOneWidget);
      expect(find.text('7 units'), findsOneWidget);
      // Both roads offered, the reader's to choose (FR-BAR-7), under the one
      // word both ends of the form ask the question in.
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
    });

    testWidgets('what it holds stands as the contents of the bar being made', (
      tester,
    ) async {
      await withFile(tester, sharedFile);
      expect(find.text('Contents'), findsOneWidget);
      // Full width, as every field above them: a card inset by its own list's
      // margin here would read as narrower than the form it stands in.
      final card = tester.widget<Card>(
        find
            .ancestor(of: find.text('3 recipes'), matching: find.byType(Card))
            .first,
      );
      expect((card.margin! as EdgeInsets).horizontal, 0);
    });

    testWidgets('a name already typed is left standing', (tester) async {
      await openForm(tester, picked: () async => sharedFile);
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('From import'));
      expect(tester.widget<TextField>(barNameField).controller?.text, 'Cellar');
    });

    testWidgets('a reader who picks nothing has done nothing', (tester) async {
      await openForm(tester, picked: () async => null);
      await tap(tester, find.text('From import'));
      expect(find.byType(SnackBar), findsNothing);
      // Still offering the first pick rather than a second.
      expect(find.text('From import'), findsOneWidget);
    });

    testWidgets('a picker that will not open speaks', (tester) async {
      await openForm(tester, picked: () async => throw Exception('no picker'));
      await tap(tester, find.text('From import'));
      expect(find.textContaining('Could not read that file'), findsOneWidget);
      expect(find.textContaining('no picker'), findsOneWidget);
    });

    testWidgets('one that cannot be read offers no road at all', (
      tester,
    ) async {
      await withFile(tester, damagedFile);
      expect(find.text('This file cannot be read'), findsOneWidget);
      expect(find.textContaining('rye'), findsOneWidget);
      expect(find.textContaining('line '), findsOneWidget);
      // Nothing to be a guest of, and founding an empty bar in its place would
      // be a lie about what became of the file.
      expect(find.text('Guest'), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('clearing it leaves the bar empty again', (tester) async {
      final store = await withFile(tester, sharedFile);
      await tap(tester, find.byTooltip('Leave it empty'));
      expect(find.text('3 recipes'), findsNothing);
      expect(find.text('Guest'), findsNothing);
      // The name arrived with the file and leaves with it: a bar of nothing is
      // the reader's own to name.
      expect(tester.widget<TextField>(barNameField).controller?.text, isEmpty);
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Save'));
      expect(founded(store).collection, Collection());
    });
  });

  group('the owned road', () {
    testWidgets('takes the contents and leaves the bar the reader\'s', (
      tester,
    ) async {
      final store = await withFile(tester, sharedFile);
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Save'));
      final made = founded(store);
      expect(made.bar.mode, BarMode.owner);
      // Theirs: the name they gave it, not the one the file carried.
      expect(made.bar.name, 'Cellar');
      expect(made.collection, recipeCollection);
      // Nothing links it back, so there is nothing to refresh from.
      expect(made.bar.source, isNull);
      expect(shellTitle('Recipes', bar: 'Cellar'), findsOneWidget);
    });

    testWidgets('it is written to like any bar founded here', (tester) async {
      await withFile(tester, sharedFile);
      await tap(tester, find.text('Save'));
      // The add button is built from the writer being non-null (ADR 23).
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.add),
        findsWidgets,
      );
    });

    /// An establishing is where the reader has no pick yet, so the file's own
    /// unit is what they start from (ADR 21).
    testWidgets('the file names the unit it is first read in', (tester) async {
      final store = await withFile(
        tester,
        fileOf(recipeCollection, display: FixedUnit.oz),
      );
      await tap(tester, find.text('Save'));
      expect(founded(store).bar.display, FixedUnit.oz);
    });
  });

  group('the guest road', () {
    testWidgets('lands another owner\'s bar, read-only and refreshable', (
      tester,
    ) async {
      final store = await withFile(tester, sharedFile);
      await tap(tester, find.text('Guest'));
      await tap(tester, find.text('Save'));
      final made = founded(store);
      expect(made.bar.mode, BarMode.guest);
      expect(made.bar.name, "Ada's bar");
      expect(made.collection, recipeCollection);
      // Kept, so a refresh asks the same way again (FR-BAR-5).
      expect(made.bar.source?.via, Transport.file);
      expect(made.bar.refreshed, testNow);
      // Two destinations where an owned bar has three (FR-BAR-4).
      expect(find.text('Shopping'), findsNothing);
    });

    /// FR-BAR-3: what a bar is called here is the reader's on a guest bar as on
    /// one of their own, and no refresh takes it back (ADR 21).
    testWidgets('the name is theirs to choose, on this road as on the other', (
      tester,
    ) async {
      final store = await withFile(tester, sharedFile);
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Guest'));
      // Null is the field's own default, which is live: nothing dims it.
      expect(tester.widget<TextField>(barNameField).enabled ?? true, isTrue);
      await tap(tester, find.text('Save'));
      final made = founded(store);
      expect(made.bar.mode, BarMode.guest);
      expect(made.bar.name, 'Cellar');
    });

    testWidgets('nothing on the shelf is moved to make room', (tester) async {
      final store = await withFile(tester, sharedFile);
      await tap(tester, find.text('Guest'));
      await tap(tester, find.text('Save'));
      expect(store.savedShelf!.bars, hasLength(2));
      // The bar that stood keeps its own file untouched, and no copy of it was
      // taken: nothing was replaced.
      expect(store.savedBars[testBar().id], isNull);
      expect(store.snapshots, isEmpty);
    });
  });

  group('a bar found nearby (FR-BAR-8)', () {
    const ada = BarSource(via: Transport.lan, at: 'ada01/Ada', from: 'Ada');

    /// The form over a network offering [found], the LAN channel answering
    /// [fetched] when one is chosen — the two seams a road over the wire needs
    /// and the whole of what a widget test stands in for (ADR 22).
    Future<MemoryBarStore> withNearby(
      WidgetTester tester, {
      List<Found> found = const [(source: ada, name: "Ada's bar")],
      Outcome<BarContent>? fetched,
    }) async {
      final store = await openForm(
        tester,
        overrides: [
          findersProvider.overrideWithValue({
            Transport.lan: MemoryFinder(found),
          }),
          channelsProvider.overrideWithValue({
            Transport.lan: MemoryChannel(
              fetched ??
                  Ok((
                    name: "Ada's bar",
                    display: FixedUnit.part,
                    collection: recipeCollection,
                  )),
            ),
          }),
        ],
      );
      await tap(tester, find.text('From LAN'));
      return store;
    }

    /// The pick is agreed to in the dialog and what it holds is read here —
    /// which is the one road a picked file already takes.
    testWidgets('a bar chosen nearby is read before it is agreed to', (
      tester,
    ) async {
      await withNearby(tester);
      await tap(tester, find.text("Ada's bar"));
      await tap(tester, find.text('Choose'));
      expect(find.text('3 recipes'), findsOneWidget);
      expect(find.text('Mode'), findsOneWidget);
      // The owner's own name for it is where the field starts (ADR 21).
      expect(
        tester.widget<TextField>(barNameField).controller?.text,
        "Ada's bar",
      );
    });

    testWidgets('the guest road keeps the source it came from', (tester) async {
      final store = await withNearby(tester);
      await tap(tester, find.text("Ada's bar"));
      await tap(tester, find.text('Choose'));
      await tap(tester, find.text('Guest'));
      await tap(tester, find.text('Save'));
      final made = founded(store);
      expect(made.bar.mode, BarMode.guest);
      expect(made.bar.source, ada);
      expect(made.collection, recipeCollection);
    });

    /// FR-BAR-2: the same arrival may simply be copied, with nothing linking
    /// it back — the road a file already offers.
    testWidgets('the owned road keeps no source at all', (tester) async {
      final store = await withNearby(tester);
      await tap(tester, find.text("Ada's bar"));
      await tap(tester, find.text('Choose'));
      await tap(tester, find.text('Save'));
      expect(founded(store).bar.source, isNull);
      expect(founded(store).bar.mode, BarMode.owner);
    });

    /// Nothing arrived, so there is nothing to show and nothing has changed:
    /// the form stands as it was and says why (FR-BAR-5).
    testWidgets('a source that could not be reached leaves the form alone', (
      tester,
    ) async {
      await withNearby(
        tester,
        fetched: const Unreachable(UnreachableReason.notFound),
      );
      await tap(tester, find.text("Ada's bar"));
      await tap(tester, find.text('Choose'));
      expect(find.textContaining('could not be added'), findsOneWidget);
      expect(find.text('Mode'), findsNothing);
    });

    /// A refused document is the same news whichever road carried it.
    testWidgets('a bar the rules refuse shows what and where', (tester) async {
      await withNearby(tester, fetched: const YamlCodec().decode(damagedFile));
      await tap(tester, find.text("Ada's bar"));
      await tap(tester, find.text('Choose'));
      expect(find.text('This file cannot be read'), findsOneWidget);
      expect(find.text('Mode'), findsNothing);
    });

    /// An import opens on a file already in hand, so the road that would put
    /// something off the network in its place is not one that entry offers.
    testWidgets('importing offers the file road alone', (tester) async {
      await pumpApp(
        tester,
        store: MemoryBarStore.of(testBar(), smallCollection),
        picker: () async => sharedFile,
      );
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Import'));
      expect(find.text('Choose another file'), findsOneWidget);
      expect(find.text('From LAN'), findsNothing);
    });
  });
}
