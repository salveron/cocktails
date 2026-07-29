import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Three recipes off their reading order, covering every card section: tags,
/// marks, a range, notes and made-history — and each section's absence too.
final recipeModel = Model(
  ingredients: [
    Ingredient('bourbon'),
    Ingredient('campari'),
    Ingredient('egg white'),
    Ingredient('gin'),
    Ingredient('lemon juice'),
    Ingredient('lime juice'),
    Ingredient('sugar syrup'),
    Ingredient('sweet vermouth'),
    Ingredient('white rum'),
  ],
  recipeTags: const [
    Tag('classic', color: TagColor.rose),
    Tag('sour', color: TagColor.sand),
  ],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(Amount(2), Unit.part, 'bourbon', mark: LineMark.base),
        RecipeLine(Amount(1), Unit.part, 'lemon juice'),
        RecipeLine(Amount(0.75), Unit.part, 'sugar syrup'),
        RecipeLine(Amount(1), Unit.piece, 'egg white', mark: LineMark.optional),
      ],
    ),
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin', mark: LineMark.base),
        RecipeLine(Amount(1), Unit.part, 'campari'),
        RecipeLine(Amount(1), Unit.part, 'sweet vermouth'),
      ],
      notes: 'Stir over ice.',
      made: MadeHistory(DateTime(2026, 7, 12), 4),
    ),
    Recipe(
      'Daiquiri',
      lines: const [
        RecipeLine(
          Amount.range(1.5, 2),
          Unit.part,
          'white rum',
          mark: LineMark.base,
        ),
        RecipeLine(Amount(1), Unit.part, 'lime juice'),
      ],
      made: MadeHistory(DateTime(2026, 1, 3), 1),
    ),
  ],
);

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

    testWidgets('offers no add until the form lands', (tester) async {
      await pumpRecipes(tester);
      expect(find.byType(FloatingActionButton), findsNothing);
      await search(tester, 'Mai Tai');
      expect(find.text('No recipe here is called "Mai Tai".'), findsOneWidget);
      expect(find.text('Add "Mai Tai"'), findsNothing);
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
