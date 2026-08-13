import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/bars_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

void main() {
  final home = testBar();
  final anna = Bar(id: 'anna01', name: 'Anna', mode: BarMode.owner);
  final annaCollection = Collection(
    ingredients: [Ingredient('white rum'), Ingredient('lime juice')],
    recipes: [Recipe('Daiquiri')],
  );

  /// A shelf of two owned bars with the first open — the arrangement the screen
  /// only becomes interesting over.
  MemoryBarStore twoBars() =>
      MemoryBarStore((bars: [home, anna], openId: home.id))
        ..barOutcomes[home.id] = Loaded((
          name: home.name,
          display: home.display,
          collection: fixtureCollection,
        ))
        ..barOutcomes[anna.id] = Loaded((
          name: anna.name,
          display: anna.display,
          collection: annaCollection,
        ));

  /// The screen as a reader reaches it: the gear, then the row that travels.
  Future<void> openBars(WidgetTester tester, {BarStore? store}) async {
    await pumpApp(tester, store: store ?? twoBars());
    await tap(tester, find.byTooltip('Settings'));
    await tap(tester, find.text('Switch bar…'));
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

    testWidgets('a closed card says the name and nothing else', (tester) async {
      await openBars(tester);
      expect(find.textContaining('recipe'), findsNothing);
      expect(find.text('Open bar'), findsNothing);
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

    testWidgets('the bar on show offers no way into itself', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Home bar');
      // Which is how the list says which bar that is.
      expect(find.text('Open bar'), findsNothing);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('another bar opens onto the way in', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      expect(find.text('Open bar'), findsOneWidget);
    });

    testWidgets('a card closed again forgets what it read', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      await openCard(tester, 'Anna');
      expect(bullet('1 recipe'), findsNothing);
    });

    testWidgets('a bar whose file never landed counts as the empty one '
        'opening it would give', (tester) async {
      await openBars(
        tester,
        store: twoBars()..barOutcomes[anna.id] = const Empty(),
      );
      await openCard(tester, 'Anna');
      expect(bullet('0 recipes'), findsOneWidget);
    });

    testWidgets('a bar whose file will not read at all says so', (
      tester,
    ) async {
      final torn = twoBars();
      torn.barOutcomes[anna.id] = Corrupt([
        SourcedIssue(
          ValidationIssue(
            const [],
            ValidationIssueKind.unknownIngredient,
            'Unknown ingredient: "rye"',
          ),
          4,
        ),
      ]);
      await openBars(tester, store: torn);
      await openCard(tester, 'Anna');
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
      await tap(tester, find.text('Switch bar…'));
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Open bar'));
      // The subtree is keyed by the open bar, so the search went with it.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller?.text,
        isEmpty,
      );
      expect(find.text('Daiquiri'), findsOneWidget);
    });
  });

  group('a new bar', () {
    testWidgets('is named, made and opened by the making of it', (
      tester,
    ) async {
      await openBars(tester);
      await tap(tester, find.byTooltip('New bar'));
      await type(tester, 'Cellar');
      await tap(tester, find.text('Save'));
      expect(shellTitle('Recipes', bar: 'Cellar'), findsOneWidget);
      // Empty, and the reader is standing in it.
      expect(find.text('Negroni'), findsNothing);
    });

    testWidgets('a name of nothing but spaces is refused', (tester) async {
      await openBars(tester);
      await tap(tester, find.byTooltip('New bar'));
      await type(tester, '   ');
      expect(
        tester.widget<TextField>(dialogField).decoration?.errorText,
        'A name of spaces is no name',
      );
    });

    testWidgets('backing out of the dialog makes nothing', (tester) async {
      await openBars(tester);
      await tap(tester, find.byTooltip('New bar'));
      await tap(tester, find.text('Cancel'));
      expect(find.byType(BarsScreen), findsOneWidget);
      expect(find.text('Home bar'), findsOneWidget);
      expect(find.text('Anna'), findsOneWidget);
    });
  });

  group('renaming a bar', () {
    testWidgets('the card and the title behind it both follow', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Home bar');
      await tap(tester, find.text('Rename'));
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
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Rename'));
      expect(tester.widget<TextField>(dialogField).controller?.text, 'Anna');
    });
  });

  group('deleting a bar', () {
    testWidgets('it is asked first, and the copy is promised (FR-BAR-2)', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Delete'));
      expect(find.text('Delete "Anna"?'), findsOneWidget);
      expect(find.textContaining('A copy is kept first'), findsOneWidget);
    });

    testWidgets('cancelling leaves the bar where it was', (tester) async {
      await openBars(tester);
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Delete'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('Anna'), findsOneWidget);
    });

    testWidgets('confirmed, the bar goes and the copy is kept', (tester) async {
      final store = twoBars();
      await openBars(tester, store: store);
      await openCard(tester, 'Anna');
      await tap(tester, find.text('Delete'));
      await agreeToDelete(tester);
      expect(find.text('Anna'), findsNothing);
      expect(find.text('Home bar'), findsOneWidget);
      expect(store.snapshots[ExportPurpose.beforeDelete]?.$2, annaCollection);
    });

    testWidgets('deleting the bar on show leaves the reader on the list', (
      tester,
    ) async {
      await openBars(tester);
      await openCard(tester, 'Home bar');
      await tap(tester, find.text('Delete'));
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
      await type(tester, 'Cellar');
      await tap(tester, find.text('Save'));
      expect(shellTitle('Recipes', bar: 'Cellar'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
