/// A guest bar is another owner's, read and never written (FR-BAR-3/4). The
/// rule is one fact — `barWriterProvider` answering null — so it is tested
/// where a reader would meet it: the destinations offered, the controls each
/// screen draws, and the rows Settings leads to.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/destinations.dart';
import 'package:cocktails/ui/screens/amounts_screen.dart';
import 'package:cocktails/ui/screens/ingredients_screen.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:cocktails/ui/screens/shopping_settings_screen.dart';
import 'package:cocktails/ui/screens/tags_screen.dart';
import 'package:cocktails/ui/screens/units_screen.dart';
import 'package:cocktails/ui/widgets/vocabulary_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_bar_store.dart';
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
        Destination.ingredients,
      ]);
    });

    testWidgets('the shopping optimizer is absent on a guest, not empty', (
      tester,
    ) async {
      await pumpShell(tester, guestBar());
      expect(barDestinations(tester), ['Recipes', 'Ingredients']);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('an owned bar keeps all three', (tester) async {
      await pumpShell(tester, testBar());
      expect(barDestinations(tester), ['Recipes', 'Ingredients', 'Shopping']);
    });

    /// The stack is indexed by position in the offered list, never by the
    /// enum's own index — on a guest the two part company, and an off-by-one
    /// here would draw the wrong screen under the right label.
    testWidgets('the second destination draws the second screen', (
      tester,
    ) async {
      await pumpShell(tester, guestBar());
      await goTo(tester, 'Ingredients');
      expect(showing(tester), 'Ingredients');
      expect(find.byType(IngredientsScreen), findsOneWidget);
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

    testWidgets('the ingredients screen offers no way to add an ingredient', (
      tester,
    ) async {
      await pumpOver(
        tester,
        const IngredientsScreen(),
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
    testWidgets('and tapping an ingredient does not move its stock', (
      tester,
    ) async {
      final store = await pumpOver(
        tester,
        const IngredientsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(find.text('In stock'), findsOneWidget);
      await tap(tester, find.text('gin'));
      expect(find.text('In stock'), findsOneWidget);
      expect(store.saved, isNull, reason: 'nothing reached the store');
    });

    testWidgets('an owned bar still offers every one of them', (tester) async {
      await pumpOver(tester, const IngredientsScreen(), fixtureCollection);
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

    testWidgets('what reads stays live, and only Shopping dims', (
      tester,
    ) async {
      await pumpOver(
        tester,
        const SettingsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      // The owner's vocabularies and sizes are the guest's to read (FR-BAR-4),
      // so every row leading to one opens; the optimizer is absent there, so
      // its settings are the one thing with nothing to say.
      for (final row in ['Tags', 'Units', 'Amounts', 'Export', 'Change bar']) {
        expect(live(tester, row), isTrue, reason: row);
      }
      expect(live(tester, 'Shopping'), isFalse);
      // The file row is not dimmed but read the other way round: this bar takes
      // no file in, and asks its source for one instead (FR-BAR-5).
      expect(find.text('Import'), findsNothing);
      expect(live(tester, 'Refresh'), isTrue);
    });

    testWidgets('the live rows open and the dimmed one leads nowhere', (
      tester,
    ) async {
      await pumpOver(
        tester,
        const SettingsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      await tap(tester, find.text('Shopping'));
      expect(find.byType(ShoppingSettingsScreen), findsNothing);
      await tap(tester, find.text('Tags'));
      expect(find.byType(TagsScreen), findsOneWidget);
    });

    testWidgets('every row is live on an owned bar', (tester) async {
      await pumpOver(tester, const SettingsScreen(), fixtureCollection);
      for (final row in [
        'Tags',
        'Units',
        'Amounts',
        'Shopping',
        'Export',
        'Import',
      ]) {
        expect(live(tester, row), isTrue, reason: row);
      }
      // Nothing to ask: an owned bar has no source (FR-BAR-5).
      expect(find.text('Refresh'), findsNothing);
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

  // FR-BAR-4: the owner's vocabularies are the guest's to read. What goes is
  // every way in to changing one, and none of them is left to be refused.
  group('tags on a guest bar', () {
    testWidgets('reads and offers no way to write', (tester) async {
      await pumpOver(
        tester,
        const TagsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(find.text('classic'), findsOneWidget);
      expect(find.byTooltip('Add recipe tag'), findsNothing);
      expect(rowMenu('classic'), findsNothing);
      await tap(tester, find.text('classic'));
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'the search alone — a tapped row opened no edit',
      );
    });

    testWidgets('the search still narrows the owner\'s tags', (tester) async {
      await pumpOver(
        tester,
        const TagsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      await typeInto(tester, find.byType(TextField), 'zzz');
      expect(find.text('Nothing matches'), findsOneWidget);
      expect(
        find.textContaining('Add "zzz"'),
        findsNothing,
        reason: 'nothing to add on someone else\'s bar',
      );
    });

    testWidgets('an owned bar offers all three ways in', (tester) async {
      await pumpOver(tester, const TagsScreen(), fixtureCollection);
      expect(find.byTooltip('Add recipe tag'), findsOneWidget);
      expect(rowMenu('classic'), findsOneWidget);
    });
  });

  group('units on a guest bar', () {
    testWidgets('the rows read and nothing writes them', (tester) async {
      await pumpOver(
        tester,
        const UnitsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      // A name and a plural per unit, and no spare row inviting another.
      expect(fields, hasLength(defaultUnits.length * 2));
      expect(fields.every((field) => field.enabled ?? true), isFalse);
      expect(find.text('Save'), findsNothing);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(
        find.byTooltip('Fixed unit'),
        findsNothing,
        reason: 'the lock marks the three nobody renames, not every row',
      );
    });

    testWidgets('an owned bar keeps its spare row, its Save and its locks', (
      tester,
    ) async {
      await pumpOver(tester, const UnitsScreen(), fixtureCollection);
      expect(
        find.byType(TextField),
        findsNWidgets((defaultUnits.length + 1) * 2),
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.byTooltip('Fixed unit'), findsNWidgets(3));
    });
  });

  group('amounts on a guest bar', () {
    /// The pick is a preference for reading someone else's collection; the
    /// sizes are the owner's, the recipes having been written against them —
    /// so both are on show and only one of them moves.
    testWidgets('the sizes read and refuse the finger', (tester) async {
      await pumpOver(
        tester,
        const AmountsScreen(),
        fixtureCollection,
        bar: guestBar(),
      );
      expect(find.byType(SegmentedButton<FixedUnit>), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      expect(fields.every((field) => field.enabled ?? true), isFalse);
    });

    testWidgets('an owned bar may type in them', (tester) async {
      await pumpOver(tester, const AmountsScreen(), fixtureCollection);
      expect(find.byType(SegmentedButton<FixedUnit>), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      expect(fields.every((field) => field.enabled ?? true), isTrue);
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
      // The rows name ml too, so the segment is reached through its button.
      await tap(
        tester,
        find.descendant(
          of: find.byType(SegmentedButton<FixedUnit>),
          matching: find.text('ml'),
        ),
      );
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
      await goTo(tester, 'Ingredients');
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

    /// The same ask from the gear, where the row an owned bar imports through
    /// stands: a reader who went looking for it finds it in the menu, and there
    /// is no list under them to pull on.
    group('from the gear', () {
      Future<void> askThere(WidgetTester tester) async {
        await tap(tester, find.byTooltip('Settings'));
        await tap(tester, find.text('Refresh'));
      }

      testWidgets('it lands, and says so where the lists cannot', (
        tester,
      ) async {
        await pumpShell(
          tester,
          guestBar(),
          picker: () async => fileOf(fixtureCollection),
        );
        await askThere(tester);
        expect(find.text('Refreshed.'), findsOneWidget);
        await tap(tester, find.byTooltip('Back'));
        expect(find.text('Negroni'), findsOneWidget);
      });

      /// One answer, one telling: the banner would carry this where the reader
      /// pulled for it, and has nothing left to say once the snackbar has.
      testWidgets('what it came to is said here and not again behind', (
        tester,
      ) async {
        await pumpShell(tester, guestBar(), picker: () async => damagedFile);
        await askThere(tester);
        expect(find.textContaining('could not be read'), findsOneWidget);
        expect(find.textContaining('rye'), findsOneWidget);
        await tap(tester, find.byTooltip('Back'));
        expect(find.byType(MaterialBanner), findsNothing);
        expect(find.text('Whiskey Sour'), findsOneWidget);
      });

      testWidgets('a reader who picks nothing is told nothing', (tester) async {
        await pumpShell(tester, guestBar(), picker: () async => null);
        await askThere(tester);
        expect(find.byType(SnackBar), findsNothing);
      });
    });
  });
}
