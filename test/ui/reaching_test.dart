import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

RecipeLine _line(List<String> ingredients, {LineMark? mark}) =>
    RecipeLine(const Amount(1), 'part', ingredients, mark: mark);

/// A shelf short in every way a jump has to cope with: baskets to open on the
/// shopping screen, a line naming one bottle by an alias and offering a second
/// beside it, and tags on both vocabularies — so a jump has narrowings to clear
/// whichever way it goes. At a budget of two, `campari + sweet vermouth` is the
/// one basket worth buying, and it unlocks both of the recipes waiting on it.
final reachingCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_, tags: const ['spirit']),
    Ingredient('campari', tags: const ['bitter']),
    Ingredient('sweet vermouth'),
    Ingredient('cognac', aliases: const ['brandy']),
    Ingredient('rye'),
  ],
  recipeTags: const [Tag('classic', color: TagColor.rose)],
  ingredientTags: const [
    Tag('bitter', color: TagColor.rose),
    Tag('spirit', color: TagColor.sand),
  ],
  recipes: [
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: [
        _line(const ['gin'], mark: LineMark.base),
        _line(const ['campari']),
        _line(const ['sweet vermouth']),
      ],
    ),
    Recipe(
      'Americano',
      lines: [
        _line(const ['campari']),
        _line(const ['sweet vermouth']),
      ],
    ),
    Recipe(
      'Sidecar',
      lines: [
        _line(const ['brandy', 'rye']),
      ],
    ),
  ],
);

/// A collection too long to read at once, whose one basket unlocks the recipe
/// standing last in it: the fillers are all makeable, so the availability order
/// the list opens in puts `Zzz Nightcap` off the bottom of the screen and a
/// reveal has somewhere to scroll.
final longCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
  ],
  recipes: [
    for (var i = 1; i <= 25; i++)
      Recipe(
        'Filler ${i.toString().padLeft(2, '0')}',
        lines: [
          _line(const ['gin']),
        ],
      ),
    Recipe(
      'Zzz Nightcap',
      lines: [
        _line(const ['campari']),
      ],
    ),
  ],
);

Future<void> pumpShell(WidgetTester tester, [Collection? collection]) =>
    pumpApp(tester, store: MemoryModelStore(collection ?? reachingCollection));

/// Opens the one basket worth buying two bottles, whose card then names both
/// bottles and both recipes.
Future<void> openBasket(WidgetTester tester) async {
  await goTo(tester, 'Shopping');
  await tap(tester, find.text('2'));
  await tap(tester, find.text('Shopping Cart #1'));
}

/// Opens the recipe card named [name] on the Recipes screen.
Future<void> openRecipe(WidgetTester tester, String name) async {
  await goTo(tester, 'Recipes');
  await tap(tester, find.text(name));
}

void main() {
  group('a destination sends the reader to another', () {
    testWidgets('a basket\'s recipe opens on the Recipes (FR-DIS-9)', (
      tester,
    ) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      expect(showing(tester), 'Recipes');
      expect(cardOpen(tester, 'Negroni'), isTrue);
    });

    testWidgets('a basket\'s bottle opens on the Inventory', (tester) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('sweet vermouth'));
      expect(showing(tester), 'Inventory');
      expect(find.text('sweet vermouth'), findsOneWidget);
    });

    testWidgets('the revealed recipe is the only one left open', (
      tester,
    ) async {
      await pumpShell(tester);
      await openRecipe(tester, 'Sidecar');
      await openBasket(tester);
      await tap(tester, bullet('Americano'));
      expect(openCards(tester, ['Negroni', 'Americano', 'Sidecar']), [
        'Americano',
      ]);
    });

    testWidgets('a line reaches its bottle on the Inventory', (tester) async {
      await pumpShell(tester);
      await openRecipe(tester, 'Negroni');
      // The name alone: the measure before it and the mark after are inert.
      await tester.tapOnText(find.textRange.ofSubstring('gin'));
      await tester.pumpAndSettle();
      expect(showing(tester), 'Inventory');
      expect(find.text('gin'), findsOneWidget);
    });

    testWidgets('a group offers one target per alternative (ADR 11)', (
      tester,
    ) async {
      await pumpShell(tester);
      await openRecipe(tester, 'Sidecar');
      await tester.tapOnText(find.textRange.ofSubstring('rye'));
      await tester.pumpAndSettle();
      expect(showing(tester), 'Inventory');
    });

    testWidgets('a line spelling a bottle otherwise reaches its own row', (
      tester,
    ) async {
      await pumpShell(tester);
      await openRecipe(tester, 'Sidecar');
      await tester.tapOnText(find.textRange.ofSubstring('brandy'));
      await tester.pumpAndSettle();
      // The line says "brandy", the vocabulary keeps the bottle under "cognac",
      // and a list finds its rows under their own names (ADR 10).
      expect(find.text('cognac'), findsOneWidget);
      expect(find.text('brandy'), findsNothing);
    });

    testWidgets('the search and the picks in the way are cleared (ADR 19)', (
      tester,
    ) async {
      await pumpShell(tester);
      await goTo(tester, 'Recipes');
      await search(tester, 'Negroni');
      await pickTag(tester, 'classic');
      await openBasket(tester);
      await tap(tester, bullet('Americano'));
      expect(cardOpen(tester, 'Americano'), isTrue);
      expect(isPicked(tester, 'classic'), isFalse);
      expect(tester.widget<TextField>(searchBox).controller?.text, '');
    });

    testWidgets('a base pick in the way is cleared too (FR-DIS-4)', (
      tester,
    ) async {
      await pumpShell(tester);
      await goTo(tester, 'Recipes');
      await pickBase(tester, 'gin');
      expect(find.text('Americano'), findsNothing);
      await openBasket(tester);
      await tap(tester, bullet('Americano'));
      expect(basePick(tester), 'Base: Any');
      expect(cardOpen(tester, 'Americano'), isTrue);
    });

    testWidgets('the order in the way goes back to the list\'s own', (
      tester,
    ) async {
      await pumpShell(tester);
      await goTo(tester, 'Recipes');
      await sortBy(tester, 'Name');
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      // The chips stay on show — which order is in force is the narrowing, and
      // whether they are offered is not.
      expect(sortedBy(tester), ('Availability', false));
    });

    testWidgets('a row off the bottom of a long list is scrolled to', (
      tester,
    ) async {
      await pumpShell(tester, longCollection);
      await goTo(tester, 'Recipes');
      expect(find.text('Zzz Nightcap'), findsNothing);
      await goTo(tester, 'Shopping');
      await tap(tester, find.text('Shopping Cart #1'));
      await tap(tester, bullet('Zzz Nightcap'));
      expect(cardInView(tester, 'Zzz Nightcap'), isTrue);
    });

    testWidgets('a narrowed list goes home first, then lands on the row', (
      tester,
    ) async {
      await pumpShell(tester, longCollection);
      await goTo(tester, 'Recipes');
      // Narrowed, the list is marked for home; the reveal waits on the
      // measurement that re-anchoring forces (ADR 13, ADR 19).
      await search(tester, 'Filler 2');
      await goTo(tester, 'Shopping');
      await tap(tester, find.text('Shopping Cart #1'));
      await tap(tester, bullet('Zzz Nightcap'));
      expect(cardInView(tester, 'Zzz Nightcap'), isTrue);
    });

    testWidgets('back undoes a jump and leaves the screen as it was', (
      tester,
    ) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      await systemBack(tester);
      expect(showing(tester), 'Shopping');
      // Every destination stays alive, so the basket is found open (NFR-1).
      expect(bullet('Negroni'), findsOneWidget);
    });

    testWidgets('a chain of jumps unwinds one at a time', (tester) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      await tester.tapOnText(find.textRange.ofSubstring('gin'));
      await tester.pumpAndSettle();
      expect(showing(tester), 'Inventory');
      await systemBack(tester);
      expect(showing(tester), 'Recipes');
      await systemBack(tester);
      expect(showing(tester), 'Shopping');
    });

    testWidgets('a destination the reader chose clears the way back', (
      tester,
    ) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      await goTo(tester, 'Inventory');
      await systemBack(tester);
      // The jump's way back went with the tap, so this is left for the route
      // the shell stands on rather than undoing a move the reader made.
      expect(showing(tester), 'Inventory');
    });

    testWidgets('the same row asked for twice is revealed twice', (
      tester,
    ) async {
      await pumpShell(tester);
      await openBasket(tester);
      await tap(tester, bullet('Negroni'));
      await tap(tester, find.text('Negroni'));
      expect(cardOpen(tester, 'Negroni'), isFalse);
      await goTo(tester, 'Shopping');
      await tap(tester, bullet('Negroni'));
      expect(showing(tester), 'Recipes');
      expect(cardOpen(tester, 'Negroni'), isTrue);
    });
  });
}
