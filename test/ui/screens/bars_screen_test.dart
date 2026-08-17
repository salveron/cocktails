import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/bar_form_screen.dart';
import 'package:cocktails/ui/screens/bars_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_bar_store.dart';
import '../harness.dart';

void main() {
  final annaCollection = Collection(
    ingredients: [Ingredient('white rum'), Ingredient('lime juice')],
    recipes: [Recipe('Daiquiri')],
  );

  /// Three hours before the clock every widget test runs under, so a bar dated
  /// here reads as something a reader would recognise.
  final earlier = testNow.subtract(const Duration(hours: 3));

  final home = testBar().summarised(fixtureCollection, at: earlier);
  final anna = Bar(
    id: 'anna01',
    name: 'Anna',
    mode: BarMode.owner,
  ).summarised(annaCollection, at: earlier);

  /// A guest bar, so the mode chip and the refresh line have something to say.
  final ada = Bar(
    id: 'ada001',
    name: "Ada's bar",
    mode: BarMode.guest,
    source: const BarSource(via: Transport.file, at: 'ada.yaml', from: 'Ada'),
    refreshed: testNow.subtract(const Duration(days: 2)),
  ).summarised(annaCollection);

  /// A shelf of [bars] with the first open, each holding what [collections]
  /// gives it — the arrangement the screen only becomes interesting over.
  MemoryBarStore shelfOf(List<Bar> bars, Map<String, Collection> collections) {
    final store = MemoryBarStore((bars: bars, openId: bars.first.id));
    for (final bar in bars) {
      store.barOutcomes[bar.id] = Loaded((
        name: bar.name,
        display: bar.display,
        collection: collections[bar.id] ?? Collection(),
      ));
    }
    return store;
  }

  MemoryBarStore twoBars() => shelfOf(
    [home, anna],
    {home.id: fixtureCollection, anna.id: annaCollection},
  );

  /// The screen as a reader reaches it: the gear, then the row that travels.
  Future<void> openBars(WidgetTester tester, {BarStore? store}) async {
    await pumpApp(tester, store: store ?? twoBars());
    await tap(tester, find.byTooltip('Settings'));
    await tap(tester, find.text('Change bar'));
  }

  /// Opens the card of the bar named [name].
  Future<void> openCard(WidgetTester tester, String name) =>
      tap(tester, find.text(name));

  /// The dialog's Delete, told apart from the card's own behind it.
  Future<void> agreeToDelete(WidgetTester tester) => tap(
    tester,
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    ),
  );

  group('the bars this device holds', () {
    testWidgets('every bar is listed, whichever one is open', (tester) async {
      await openBars(tester);
      expect(find.widgetWithText(AppBar, 'Bars'), findsOneWidget);
      expect(find.text('Home bar'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('a closed card keeps what the bar holds to itself', (
      tester,
    ) async {
      await openBars(tester);
      expect(find.textContaining('recipe'), findsNothing);
      expect(find.text('Open bar'), findsNothing);
    });

    testWidgets('the closed card says how current the bar is', (tester) async {
      await openBars(tester, store: shelfOf([home, anna, ada], {}));
      // The bar on show dates itself as every other does: opening one loads
      // nothing a card could report, so no card says which is loaded.
      expect(find.text('Updated: 3 hours ago'), findsNWidgets(2));
      // A guest bar dates its source's last answer, not an edit of its own.
      expect(find.text('Refreshed: 2 days ago'), findsOneWidget);
    });

    testWidgets('a bar never yet dated says nothing rather than guessing', (
      tester,
    ) async {
      final undated = Bar(id: 'old001', name: 'Cellar', mode: BarMode.owner);
      await openBars(tester, store: shelfOf([home, undated], {}));
      expect(find.text('Cellar'), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
    });

    testWidgets('whose bar it is rides beside the menu (FR-BAR-3)', (
      tester,
    ) async {
      await openBars(tester, store: shelfOf([home, ada], {}));
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
      // Each wears its own reading off the app's one traffic light, which
      // `palette_test.dart` is where the two are pinned to.
      expect(chipColor(tester, 'Owned'), isNot(chipColor(tester, 'Guest')));
    });

    testWidgets('a card opens onto what its bar holds', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      // Read off Anna's own file: the list itself knows only the index.
      expect(bullet('1 recipe'), findsOneWidget);
      expect(bullet('2 ingredients'), findsOneWidget);
      expect(bullet('0 tags'), findsOneWidget);
      expect(bullet('${defaultUnits.length} units'), findsOneWidget);
    });

    testWidgets('the bar on show counts what is already resident', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Home bar');
      expect(bullet('1 recipe'), findsOneWidget);
      expect(bullet('2 ingredients'), findsOneWidget);
    });

    testWidgets('every bar offers the way in, the one loaded included', (
      tester,
    ) async {
      await openBars(tester);
      for (final name in ['Anna', 'Home bar']) {
        await openCard(tester, name);
        expect(find.text('Open bar'), findsOneWidget, reason: name);
        await openCard(tester, name);
      }
    });

    testWidgets('what is done to a bar is behind the ⋮, not on the card', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(rowMenu('Anna'), findsOneWidget);
    });

    testWidgets('a guest bar is renamed like any other, what it is called '
        "here being the reader's (FR-BAR-3)", (tester) async {
      await openBars(tester, store: shelfOf([home, ada], {}));
      await chooseOnRow(tester, "Ada's bar", 'Rename');
      await type(tester, 'The Ada Room');
      await tap(tester, find.text('Save'));
      expect(find.text('The Ada Room'), findsOneWidget);
      expect(find.text("Ada's bar"), findsNothing);
    });

    testWidgets('a card closed again puts away what it held open', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      await openCard(tester, 'Anna');
      expect(bullet('1 recipe'), findsNothing);
    });

    testWidgets('a bar whose file never landed counts as the empty one '
        'opening it would give', (tester) async {
      final never = Bar(id: 'new001', name: 'Cellar', mode: BarMode.owner);
      final store = shelfOf([home, never], {})
        ..barOutcomes[never.id] = const Empty();
      await openBars(tester, store: store);
      await openCard(tester, 'Cellar');
      expect(bullet('0 recipes'), findsOneWidget);
    });

    testWidgets('a bar whose file will not read at all says so', (
      tester,
    ) async {
      final torn = Bar(id: 'torn01', name: 'Torn', mode: BarMode.owner);
      final store = shelfOf([home, torn], {});
      store.barOutcomes[torn.id] = Corrupt([
        SourcedIssue(
          ValidationIssue(
            const [],
            ValidationIssueKind.unknownIngredient,
            'Unknown ingredient: "rye"',
          ),
          4,
        ),
      ]);
      await openBars(tester, store: store);
      await openCard(tester, 'Torn');
      // Nothing was recovered, so "0 recipes" would be a lie about a bar that
      // may hold plenty.
      expect(find.text('This bar could not be read.'), findsOneWidget);
      expect(bullet('0 recipes'), findsNothing);
    });
  });

  group('crossing to another bar', () {
    testWidgets('the reader lands in the bar, not back on the gear', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Open bar'));
      // Past the gear it was reached through, onto the bar itself (FR-BAR-1).
      expect(find.byType(BarsScreen), findsNothing);
      expect(shellTitle('Recipes', bar: 'Anna'), findsOneWidget);
      expect(find.text('Daiquiri'), findsOneWidget);
      expect(find.text('Negroni'), findsNothing);
    });

    testWidgets('nothing of the last bar comes across (FR-BAR-1)', (
      tester,
    ) async {
      await pumpApp(tester, store: twoBars());
      await typeInto(tester, find.byType(TextField).first, 'Negroni');
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Change bar'));
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Open bar'));
      // The subtree is keyed by the open bar, so the search went with it.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
      expect(find.text('Daiquiri'), findsOneWidget);
    });

    testWidgets('the bar already loaded is crossed into just the same', (
      tester,
    ) async {
      await pumpApp(tester, store: twoBars());
      await goTo(tester, 'Ingredients');
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Change bar'));
      await openCard(tester, 'Home bar');
      await tap(tester, find.text('Open bar'));
      // Nothing was read again, and the reader lands where the crossing would
      // have left them rather than back on the destination they came from.
      expect(find.byType(BarsScreen), findsNothing);
      expect(shellTitle('Recipes'), findsOneWidget);
    });

    testWidgets('a crossing leaves nothing for back to undo', (tester) async {
      await pumpApp(tester, store: twoBars());
      await goTo(tester, 'Shopping');
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Change bar'));
      await openCard(tester, 'Home bar');
      await tap(tester, find.text('Open bar'));
      // A landing is not a jump: the reader chose the bar, so back is left
      // unclaimed rather than stepping them home to Shopping (ADR 19).
      expect(showing(tester), 'Recipes');
      await systemBack(tester);
      expect(showing(tester), 'Recipes');
    });
  });

  group('a new bar', () {
    testWidgets('the button opens the form, not a dialog', (tester) async {
      await openBars(tester);
      await tap(tester, find.byTooltip('New bar'));
      // A name and where the contents come from need room a dialog has not got
      // (FR-BAR-2/7); what the form then does with them is its own test.
      expect(find.byType(BarFormScreen), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('renaming a bar', () {
    testWidgets('the card and the title behind it both follow', (tester) async {
      await openBars(tester);
      await chooseOnRow(tester, 'Home bar', 'Rename');
      await type(tester, 'Downstairs');
      await tap(tester, find.text('Save'));
      expect(find.text('Downstairs'), findsOneWidget);
      expect(find.text('Home bar'), findsNothing);

      await tap(tester, find.byTooltip('Back'));
      await tap(tester, find.byTooltip('Back'));
      expect(shellTitle('Recipes', bar: 'Downstairs'), findsOneWidget);
    });

    testWidgets('the dialog opens on the name it is changing', (tester) async {
      await openBars(tester);
      await chooseOnRow(tester, 'Anna', 'Rename');
      expect(tester.widget<TextField>(dialogField).controller?.text, 'Anna');
    });
  });

  group('deleting a bar', () {
    testWidgets('it is asked first, and the copy is promised (FR-BAR-2)', (
      tester,
    ) async {
      await openBars(tester);
      await chooseOnRow(tester, 'Anna', 'Delete');
      expect(find.text('Delete "Anna"?'), findsOneWidget);
      expect(find.textContaining('A copy is kept first'), findsOneWidget);
    });

    testWidgets('cancelling leaves the bar where it was', (tester) async {
      await openBars(tester);
      await chooseOnRow(tester, 'Anna', 'Delete');
      await tap(tester, find.text('Cancel'));
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('confirmed, the bar goes and the copy is kept', (tester) async {
      final store = twoBars();
      await openBars(tester, store: store);
      await chooseOnRow(tester, 'Anna', 'Delete');
      await agreeToDelete(tester);
      expect(find.text('Anna'), findsNothing);
      expect(find.text('Home bar'), findsOneWidget);
      expect(store.snapshots[ExportPurpose.beforeDelete]?.$2, annaCollection);
    });

    testWidgets('deleting the bar on show leaves the reader on the list', (
      tester,
    ) async {
      await openBars(tester);
      await chooseOnRow(tester, 'Home bar', 'Delete');
      await agreeToDelete(tester);
      // No bar is open, so this screen is home rather than a route above one.
      expect(find.byType(BarsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Anna'), findsOneWidget);
    });
  });

  group('a shelf with nothing on it', () {
    testWidgets('is what the app opens on, and it says what a bar is', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: MemoryBarStore((bars: const [], openId: null)),
      );
      expect(find.byType(BarsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('No bars'), findsOneWidget);
    });

    testWidgets('a first bar made here is where the reader ends up', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: MemoryBarStore((bars: const [], openId: null)),
      );
      await tap(tester, find.byTooltip('New bar'));
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Save'));
      expect(shellTitle('Recipes', bar: 'Cellar'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
