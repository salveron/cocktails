import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

const names = ['Daiquiri', 'Negroni', 'Whiskey Sour'];

/// The day the screen's clock is stopped on, so a stamp reads back exactly.
final today = DateTime(2026, 7, 30);

Future<MemoryModelStore> pumpRecipes(WidgetTester tester, [Model? model]) =>
    pumpOver(tester, const RecipesScreen(), model ?? recipeModel, today: today);

/// The recipe names on screen, in list order.
Iterable<String?> namesOn(WidgetTester tester) =>
    rowTexts(tester).where(names.contains);

/// The three verdicts at once (FR-DIS-1), and an optional line the verdict
/// passes over though the card still marks it.
final stockedModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari', stock: StockLevel.low),
    Ingredient('sweet vermouth'),
  ],
  recipes: [
    Recipe(
      'Gin Shot',
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin'),
        RecipeLine(
          Amount(1),
          Unit.dash,
          'sweet vermouth',
          mark: LineMark.optional,
        ),
      ],
    ),
    Recipe(
      'Campari Shot',
      lines: const [RecipeLine(Amount(1), Unit.part, 'campari')],
    ),
    Recipe(
      'Negroni',
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin'),
        RecipeLine(Amount(1), Unit.part, 'campari'),
        RecipeLine(Amount(1), Unit.part, 'sweet vermouth'),
      ],
    ),
  ],
);

/// What the verdict chip on the row named [name] reads.
String verdictOn(WidgetTester tester, String name) => tester
    .widget<Text>(
      find.descendant(
        of: find.descendant(
          of: find.ancestor(
            of: find.text(name),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(AvailabilityChip),
        ),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// What the dot beside the line reading [line] reports, or null when that line
/// carries none — which is how an in-stock bottle reads.
StockLevel? dotOnLine(WidgetTester tester, String line) {
  final dots = tester
      .widgetList<StockDot>(
        find.descendant(
          of: find
              .ancestor(of: find.text(line), matching: find.byType(Row))
              .first,
          matching: find.byType(StockDot),
        ),
      )
      .toList();
  return dots.isEmpty ? null : dots.single.stock;
}

final madeButton = find.widgetWithText(FilledButton, 'Made it');
final undoButton = find.widgetWithText(TextButton, 'Undo');

/// Whatever an open card reports about its history — never the button's own
/// words, which are there whether or not there is a history to report.
final historyLine = find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data != 'Made it' &&
      (widget.data?.startsWith('Made ') ?? false),
);

void main() {
  group('recipe list', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const RecipesScreen());
      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('reads A to Z whatever order the file keeps', (tester) async {
      await pumpRecipes(tester);
      expect(namesOn(tester), names);
    });

    testWidgets('the search narrows by name', (tester) async {
      await pumpRecipes(tester);
      await search(tester, 'daiq');
      expect(namesOn(tester), ['Daiquiri']);
    });

    testWidgets('offers add, edit and delete since the form landed', (
      tester,
    ) async {
      await pumpRecipes(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(rowMenu('Negroni'), findsOneWidget);
      await search(tester, 'Mai Tai');
      expect(find.text('No recipe here is called "Mai Tai".'), findsOneWidget);
      expect(find.text('Add "Mai Tai"'), findsOneWidget);
    });

    testWidgets('delete asks once and is never blocked', (tester) async {
      final store = await pumpRecipes(tester);
      await chooseOnRow(tester, 'Negroni', 'Delete');
      expect(find.text('Delete "Negroni"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(find.text('Negroni'), findsNothing);
      expect(store.saved!.recipeNamed('Negroni'), isNull);
    });

    testWidgets('the menu is there on an expanded card too', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('Stir over ice.'), findsOneWidget);
      expect(rowMenu('Negroni'), findsOneWidget);
    });

    testWidgets('a renamed card stays open under its new name', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await typeInto(tester, nameField, 'Boulevardier');
      await tap(tester, find.text('Save'));
      expect(find.text('Boulevardier'), findsOneWidget);
      // The card it opened is still the card it opens: the notes are showing.
      expect(find.text('Stir over ice.'), findsOneWidget);
    });
  });

  group('compact card', () {
    testWidgets('sums the build up without the amounts', (tester) async {
      await pumpRecipes(tester);
      expect(find.text('gin · campari · sweet vermouth'), findsOneWidget);
      expect(find.textContaining('1 part'), findsNothing);
    });

    testWidgets('the optional ingredient is listed undistinguished', (
      tester,
    ) async {
      await pumpRecipes(tester);
      expect(
        find.text('bourbon · lemon juice · sugar syrup · egg white'),
        findsOneWidget,
      );
    });

    testWidgets('wears its tags as dots in vocabulary order', (tester) async {
      await pumpRecipes(tester);
      expect(dotsOn(tester, 'Whiskey Sour'), ['classic', 'sour']);
      expect(dotsOn(tester, 'Daiquiri'), isEmpty);
    });

    testWidgets('wears the verdict of its own bottles (FR-DIS-1)', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      expect(verdictOn(tester, 'Gin Shot'), 'Ready');
      expect(verdictOn(tester, 'Campari Shot'), 'Low');
      expect(verdictOn(tester, 'Negroni'), 'Missing');
    });

    testWidgets('the verdict stays put while the card is open', (tester) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Negroni'));
      expect(verdictOn(tester, 'Negroni'), 'Missing');
    });
  });

  group('full card', () {
    testWidgets('a tap opens the lines as the file writes them', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part gin (base)'), findsOneWidget);
      expect(find.text('1 part campari'), findsOneWidget);
      expect(find.text('1 part sweet vermouth'), findsOneWidget);
    });

    testWidgets('marks and ranges keep their own words', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(find.text('2 part bourbon (base)'), findsOneWidget);
      expect(find.text('1 piece egg white (optional)'), findsOneWidget);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('1.5-2 part white rum (base)'), findsOneWidget);
    });

    testWidgets('the summaries give way to the real thing', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('gin · campari · sweet vermouth'), findsNothing);
      expect(dotsOn(tester, 'Negroni'), isEmpty);
      expect(find.text('classic'), findsOneWidget);
    });

    testWidgets('only the lines with something to report are dotted', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Negroni'));
      expect(dotOnLine(tester, '1 part gin'), isNull);
      expect(dotOnLine(tester, '1 part campari'), StockLevel.low);
      expect(dotOnLine(tester, '1 part sweet vermouth'), StockLevel.out);
    });

    testWidgets('an optional line is marked though it does not count', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Gin Shot'));
      expect(verdictOn(tester, 'Gin Shot'), 'Ready');
      expect(
        dotOnLine(tester, '1 dash sweet vermouth (optional)'),
        StockLevel.out,
      );
    });

    testWidgets('the chips wear the tags\' own colours', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(find.text('classic'), findsOneWidget);
      expect(find.text('sour'), findsOneWidget);
      expect(chipColor(tester, 'sour'), isNot(chipColor(tester, 'classic')));
    });

    testWidgets('notes and made-history close the card', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('Stir over ice.'), findsOneWidget);
      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
    });

    testWidgets('made once reads as once', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('Made once · 3 Jan 2026'), findsOneWidget);
    });

    testWidgets('a section with nothing to say is absent', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(historyLine, findsNothing);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('Stir over ice.'), findsNothing);
    });

    testWidgets('the same tap closes it again', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part campari'), findsNothing);
      expect(find.text('gin · campari · sweet vermouth'), findsOneWidget);
    });

    testWidgets('cards open and close independently', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('1 part campari'), findsOneWidget);
      expect(find.text('1 part lime juice'), findsOneWidget);
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part campari'), findsNothing);
      expect(find.text('1 part lime juice'), findsOneWidget);
    });

    testWidgets('an open card stays open through a search', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await search(tester, 'daiq');
      await search(tester, '');
      expect(find.text('1 part campari'), findsOneWidget);
    });
  });

  group('made it', () {
    testWidgets('every open card offers it, history or not', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(madeButton, findsOneWidget);
      expect(historyLine, findsNothing);
    });

    testWidgets('the first time stamps today and counts once', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await tap(tester, madeButton);

      expect(find.text('Made once · 30 Jul 2026'), findsOneWidget);
      expect(
        store.saved?.recipeNamed('Whiskey Sour')?.made,
        MadeHistory(today, 1),
      );
      expect(store.saveCount, 1);
    });

    testWidgets('every next time counts up and moves the date', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);

      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
      expect(store.saved?.recipeNamed('Negroni')?.made, MadeHistory(today, 5));
    });

    testWidgets('nothing to take back until something is stamped', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(undoButton, findsNothing);
      await tap(tester, madeButton);
      expect(undoButton, findsOneWidget);
    });

    testWidgets('undo puts the date back, not only the count', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, undoButton);

      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
      expect(
        store.saved?.recipeNamed('Negroni')?.made,
        MadeHistory(DateTime(2026, 7, 12), 4),
      );
      expect(undoButton, findsNothing);
      expect(store.saveCount, 2, reason: 'the stamp, then the taking back');
    });

    testWidgets('undone, a first stamp leaves the recipe never made', (
      tester,
    ) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await tap(tester, madeButton);
      await tap(tester, undoButton);

      expect(historyLine, findsNothing);
      expect(store.saved?.recipeNamed('Whiskey Sour')?.made, isNull);
    });

    testWidgets('undo takes back one stamp, not the run of them', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, madeButton);
      expect(find.text('Made 6 times · last 30 Jul 2026'), findsOneWidget);

      await tap(tester, undoButton);
      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
    });

    testWidgets('closing the card takes the undo with it', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Negroni'));

      expect(undoButton, findsNothing);
      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
    });

    testWidgets('a long press asks before it resets', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await longPress(tester, madeButton);
      expect(find.text('Reset "Negroni"\'s history?'), findsOneWidget);

      await tap(tester, find.text('Cancel'));
      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
      expect(store.saveCount, 0);
    });

    testWidgets('a reset confirmed takes the history and nothing else', (
      tester,
    ) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await longPress(tester, madeButton);
      await tap(tester, find.text('Reset'));

      expect(historyLine, findsNothing);
      final negroni = store.saved?.recipeNamed('Negroni');
      expect(negroni?.made, isNull);
      expect(negroni?.notes, 'Stir over ice.');
      expect(negroni?.lines, recipeModel.recipeNamed('Negroni')?.lines);
      expect(store.saveCount, 1);
    });

    testWidgets('a recipe never made has nothing to reset', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await longPress(tester, madeButton);

      expect(find.text('Reset "Whiskey Sour"\'s history?'), findsNothing);
      // No reset to reach: the press lands as the tap it also is.
      expect(
        store.saved?.recipeNamed('Whiskey Sour')?.made,
        MadeHistory(today, 1),
      );
    });
  });
}
