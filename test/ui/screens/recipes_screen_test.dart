import 'package:cocktails/data/data.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

const names = ['Daiquiri', 'Negroni', 'Whiskey Sour'];

Future<void> pumpRecipes(WidgetTester tester) => pumpScreen(
  tester,
  const RecipesScreen(),
  store: MemoryModelStore(recipeModel),
);

/// The recipe names on screen, in list order.
Iterable<String?> namesOn(WidgetTester tester) =>
    rowTexts(tester).where(names.contains);

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
      final store = MemoryModelStore(recipeModel);
      await pumpScreen(tester, const RecipesScreen(), store: store);
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
      expect(find.textContaining('Made'), findsNothing);
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
}
