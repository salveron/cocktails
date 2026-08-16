/// A guest bar is another owner's, read and never written (FR-BAR-3/4). The
/// rule is one fact — `barWriterProvider` answering null — so it is tested
/// where a reader would meet it: the destinations offered, the controls each
/// screen draws, and the rows Settings leads to.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/destinations.dart';
import 'package:cocktails/ui/screens/amounts_screen.dart';
import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:cocktails/ui/screens/tags_screen.dart';
import 'package:cocktails/ui/screens/units_screen.dart';
import 'package:cocktails/ui/widgets/vocabulary_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  /// The shell over [bar], pumped past its startup load — [picker] being what
  /// the system's file picker answers a refresh with (FR-BAR-7).
  Future<void> pumpShell(
    WidgetTester tester,
    Bar bar, {
    Collection? collection,
    Future<String?> Function()? picker,
  }) => pumpApp(
    tester,
    store: MemoryBarStore.of(bar, collection ?? recipeCollection),
    picker: picker,
  );

  /// Which destinations the bottom bar is offering, in the order drawn.
  List<String> barDestinations(WidgetTester tester) => [
    for (final destination in tester.widgetList<NavigationDestination>(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(NavigationDestination),
      ),
    ))
      destination.label,
  ];

  group('what a bar offers', () {
    test('an owned bar offers all three, a guest the two that read', () {
      expect(destinationsOf(BarMode.owner), Destination.values);
      expect(destinationsOf(BarMode.guest), [
        Destination.recipes,
        Destination.inventory,
      ]);
    });

    testWidgets('the shopping optimizer is absent on a guest, not empty', (
      tester,
    ) async {
      await pumpShell(tester, guestBar());
      expect(barDestinations(tester), ['Recipes', 'Inventory']);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('an owned bar keeps all three', (tester) async {
      await pumpShell(tester, testBar());
      expect(barDestinations(tester), ['Recipes', 'Inventory', 'Shopping']);
    });

    /// The stack is indexed by position in the offered list, never by the
    /// enum's own index — on a guest the two part company, and an off-by-one
    /// here would draw the wrong screen under the right label.
    testWidgets('the second destination draws the second screen', (
      tester,
    ) async {
      await pumpShell(tester, guestBar());
      await goTo(tester, 'Inventory');
      expect(showing(tester), 'Inventory');
      expect(find.byType(InventoryScreen), findsOneWidget);
      await goTo(tester, 'Recipes');
      expect(showing(tester), 'Recipes');
    });
  });

  group('nothing writes a guest bar', () {
    testWidgets('the recipes offer no way to add one', (tester) async {
      await pumpOver(
        tester,
        const RecipesScreen(),
        recipeCollection,
        bar: guestBar(),
      );
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.add),
        findsNothing,
      );
    });

    /// The draw is a way of reading the list, so it survives (FR-BAR-4).
    testWidgets('but the random pick still rolls', (tester) async {
      await pumpOver(
        tester,
        const RecipesScreen(),
        recipeCollection,
        bar: guestBar(),
      );
      expect(dice, findsOneWidget);
    });

    testWidgets('a closed recipe card carries no menu at all', (tester) async {
      await pumpOver(
        tester,
        const RecipesScreen(),
        recipeCollection,
        bar: guestBar(),
      );
      expect(rowMenu('Negroni'), findsNothing);
    });

    /// Scaling reads the owner's line rather than changing it, so the menu
    /// comes back for it — and holds nothing else.
    testWidgets('an open one offers scaling and nothing more', (tester) async {
      await pumpOver(
        tester,
        const RecipesScreen(),
        recipeCollection,
        bar: guestBar(),
      );
      await tap(tester, find.text('Negroni'));
      await tap(tester, rowMenu('Negroni'));
      expect(find.text('Scale & convert'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('the inventory offers no way to add a bottle', (tester) async {
      await pumpOver(
        tester,
        const InventoryScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.add),
        findsNothing,
      );
      expect(rowMenu('gin'), findsNothing);
    });

    /// The stock is the owner's reading of their own shelf: a tap that moved it
    /// would be the reader judging one bar by another.
    testWidgets('and tapping a bottle does not move its stock', (tester) async {
      final store = await pumpOver(
        tester,
        const InventoryScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(find.text('In stock'), findsOneWidget);
      await tap(tester, find.text('gin'));
      expect(find.text('In stock'), findsOneWidget);
      expect(store.saved, isNull, reason: 'nothing reached the store');
    });

    testWidgets('an owned bar still offers every one of them', (tester) async {
      await pumpOver(tester, const InventoryScreen(), fixtureCollection);
      expect(
        find.widgetWithIcon(FloatingActionButton, Icons.add),
        findsOneWidget,
      );
      expect(rowMenu('gin'), findsOneWidget);
      await tap(tester, find.text('gin'));
      expect(find.text('Low'), findsOneWidget);
    });
  });

  group('settings on a guest bar', () {
    /// Whether the row named [title] answers a tap at all.
    bool live(WidgetTester tester, String title) => tester
        .widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        )
        .enabled;

    testWidgets('the rows that would write dim rather than vanish', (
      tester,
    ) async {
      await pumpOver(
        tester,
        const SettingsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      for (final row in ['Tags', 'Units', 'Import']) {
        expect(live(tester, row), isFalse, reason: row);
      }
      for (final row in ['Amounts', 'Export', 'Change bar']) {
        expect(live(tester, row), isTrue, reason: row);
      }
    });

    testWidgets('and a dimmed row leads nowhere', (tester) async {
      await pumpOver(
        tester,
        const SettingsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      await tap(tester, find.text('Tags'));
      expect(find.byType(TagsScreen), findsNothing);
      await tap(tester, find.text('Units'));
      expect(find.byType(UnitsScreen), findsNothing);
    });

    testWidgets('every row is live on an owned bar', (tester) async {
      await pumpOver(tester, const SettingsScreen(), fixtureCollection);
      for (final row in ['Tags', 'Units', 'Amounts', 'Export', 'Import']) {
        expect(live(tester, row), isTrue, reason: row);
      }
    });

    /// A guest already holds what the file would carry (FR-DAT-1).
    testWidgets('export works on a guest bar', (tester) async {
      var shared = 0;
      await pumpScreen(
        tester,
        const SettingsScreen(),
        store: MemoryBarStore.of(guestBar(), fixtureCollection),
        sharer: (_) async => shared++,
      );
      await tap(tester, find.text('Export'));
      expect(shared, 1);
    });
  });

  group('amounts on a guest bar', () {
    /// The pick is a preference for reading someone else's collection; the
    /// sizes are the owner's, the recipes having been written against them.
    testWidgets('the pick is offered and the sizes are not', (tester) async {
      await pumpOver(
        tester,
        const AmountsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(find.byType(SegmentedButton<FixedUnit>), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('an owned bar is offered both', (tester) async {
      await pumpOver(tester, const AmountsScreen(), fixtureCollection);
      expect(find.byType(SegmentedButton<FixedUnit>), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('picking one saves it and leaves the collection alone', (
      tester,
    ) async {
      final store = await pumpOver(
        tester,
        const AmountsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      await tap(tester, find.text('ml'));
      await tap(tester, find.text('Save'));
      expect(store.savedShelf!.bars.single.display, FixedUnit.ml);
      expect(store.saved, isNull, reason: "the owner's file is untouched");
    });
  });

  group('a menu with nothing in it', () {
    testWidgets('draws no ⋮ rather than one opening onto nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RowMenu({}))),
      );
      expect(find.byTooltip('More'), findsNothing);
    });
  });

  group('asking the source again (FR-BAR-5)', () {
    /// The pull a reader makes down the list, let run to its answer.
    Future<void> pull(WidgetTester tester) async {
      await tester.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a guest bar\'s lists answer a pull and an owned one\'s do '
        'not', (tester) async {
      await pumpShell(tester, guestBar());
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // Both of a guest's destinations, not just the one it opens on.
      await goTo(tester, 'Inventory');
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // An owned bar has no source to ask, so the gesture is not offered — and
      // the shell needs no refresh control of its own either.
      await pumpShell(tester, testBar());
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('what arrives replaces what stood, wholesale', (tester) async {
      await pumpShell(
        tester,
        guestBar(),
        picker: () async => fileOf(fixtureCollection),
      );
      expect(find.text('Whiskey Sour'), findsOneWidget);
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsNothing);
      expect(find.text('Negroni'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    /// Where the gesture is the only way in: there are no rows to pull on, so a
    /// body with nothing to scroll has to answer one anyway.
    testWidgets('a guest bar holding nothing can still be pulled', (
      tester,
    ) async {
      await pumpShell(
        tester,
        guestBar(),
        collection: Collection(),
        picker: () async => fileOf(recipeCollection),
      );
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsOneWidget);
    });

    testWidgets('what will not read leaves the bar as it stood, and says why', (
      tester,
    ) async {
      await pumpShell(tester, guestBar(), picker: () async => damagedFile);
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('rye'), findsOneWidget);
      expect(find.textContaining('line '), findsOneWidget);
    });

    /// A source naming a transport this build has no adapter for — an index
    /// carrying `cloud` before its channel lands (ADR 22).
    testWidgets('a source that could not be reached says which way', (
      tester,
    ) async {
      await pumpShell(
        tester,
        Bar(
          id: 'cld1',
          name: "Ada's bar",
          mode: BarMode.guest,
          source: const BarSource(
            via: Transport.cloud,
            at: 'somewhere',
            from: 'Ada',
          ),
        ),
      );
      await pull(tester);
      expect(
        find.textContaining('its source could not be found'),
        findsOneWidget,
      );
      await tap(tester, find.text('Dismiss'));
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('a reader who picks nothing has failed at nothing', (
      tester,
    ) async {
      await pumpShell(tester, guestBar(), picker: () async => null);
      await pull(tester);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.text('Whiskey Sour'), findsOneWidget);
    });
  });
}
