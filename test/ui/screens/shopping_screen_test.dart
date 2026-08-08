import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/shopping_screen.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

RecipeLine _line(String ingredient) =>
    RecipeLine(const Amount(1), 'part', [ingredient]);

Recipe _recipe(String name, List<String> ingredients) =>
    Recipe(name, lines: [for (final one in ingredients) _line(one)]);

/// A shelf short in both ways at once: three bottles there are none of, and one
/// running low. Every budget answers, and each answers differently — and the
/// switch moves the one-bottle answer off the missing bottle onto the low one,
/// rather than merely lengthening the list.
final shoppingModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('lime juice', stock: StockLevel.low),
    Ingredient('campari'),
    Ingredient('sweet vermouth'),
    Ingredient('white rum'),
  ],
  recipes: [
    _recipe('Negroni', ['gin', 'campari', 'sweet vermouth']),
    _recipe('Americano', ['campari', 'sweet vermouth']),
    _recipe('Gimlet', ['gin', 'lime juice']),
    _recipe('Daiquiri', ['white rum', 'lime juice']),
  ],
);

/// Two recipes short of the same pair, so no single bottle answers and the
/// two-bottle basket does.
final pairedModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
    Ingredient('sweet vermouth'),
  ],
  recipes: [
    _recipe('Negroni', ['gin', 'campari', 'sweet vermouth']),
    _recipe('Americano', ['campari', 'sweet vermouth']),
  ],
);

/// Three recipes short of a bottle each, so three baskets tie at one recipe
/// apiece and the list has ranks to read.
final spreadModel = Model(
  ingredients: [
    Ingredient('white rum'),
    Ingredient('vodka'),
    Ingredient('tequila'),
  ],
  recipes: [
    _recipe('Rum Neat', ['white rum']),
    _recipe('Vodka Neat', ['vodka']),
    _recipe('Tequila Neat', ['tequila']),
  ],
);

Future<MemoryModelStore> pumpShopping(WidgetTester tester, [Model? model]) =>
    pumpOver(
      tester,
      const ShoppingScreen(showing: true),
      model ?? shoppingModel,
    );

Future<void> pickBudget(WidgetTester tester, int budget) =>
    tap(tester, find.text('$budget'));

Future<void> toggleLow(WidgetTester tester) => tap(tester, find.byType(Switch));

Future<void> openCard(WidgetTester tester, [int rank = 1]) =>
    tap(tester, find.text('Shopping Cart #$rank'));

/// Every bottle named on the open card, told apart from the recipes beside them
/// by the dot each carries.
Iterable<String> bottlesOnCard(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.ancestor(
          of: find.byType(StockDot),
          matching: find.byType(Row),
        ),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data!);

void main() {
  group('shopping screen', () {
    testWidgets('opens on the single bottles worth buying', (tester) async {
      await pumpShopping(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'white rum', '1 recipe']);
    });

    testWidgets('a wider budget answers with a basket of exactly that many', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 2);
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth',
        '2 recipes',
      ]);
      await pickBudget(tester, 3);
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth + white rum',
        '3 recipes',
      ]);
    });

    testWidgets('the switch moves what counts as short (FR-DIS-7)', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'lime juice', '1 recipe']);
    });

    testWidgets('baskets are numbered by where they rank', (tester) async {
      await pumpShopping(tester, spreadModel);
      expect(rowTexts(tester).where((text) => text!.startsWith('Shopping')), [
        'Shopping Cart #1',
        'Shopping Cart #2',
        'Shopping Cart #3',
      ]);
    });

    testWidgets('a card opens onto its bottles and every recipe', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 3);
      await openCard(tester);
      expect(bottlesOnCard(tester), [
        '• campari',
        '• sweet vermouth',
        '• white rum',
      ]);
      for (final recipe in ['• Americano', '• Daiquiri', '• Negroni']) {
        expect(find.text(recipe), findsOneWidget);
      }
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Unlocks'), findsOneWidget);
      expect(
        find.text('campari + sweet vermouth + white rum'),
        findsNothing,
        reason: 'the bottles read in the body rather than twice over',
      );
    });

    testWidgets('an open card is remembered by its bottles, not its rank', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 2);
      await openCard(tester);
      await pickBudget(tester, 3);
      expect(
        find.text('Ingredients'),
        findsNothing,
        reason: '#1 is another basket now, and it was never opened',
      );
      await pickBudget(tester, 2);
      expect(
        find.text('Ingredients'),
        findsOneWidget,
        reason: 'the basket that was opened is still open where it stands',
      );
    });

    testWidgets('an open card reads each bottle at the level it stands at', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      await pickBudget(tester, 2);
      // By its bottles rather than its rank: this is the one basket of the
      // several at this size that holds both readings of short.
      await tap(tester, find.text('lime juice + white rum'));
      expect(
        tester.widgetList<StockDot>(find.byType(StockDot)).map((d) => d.stock),
        [StockLevel.low, StockLevel.out],
        reason:
            'restocking mixes a bottle running low with one there is none of',
      );
    });

    testWidgets('nothing at this size offers the size that answers', (
      tester,
    ) async {
      await pumpShopping(tester, pairedModel);
      expect(find.text('Nothing worth buying in 1'), findsOneWidget);
      await tap(tester, find.text('Try 2 bottles'));
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth',
        '2 recipes',
      ]);
    });

    testWidgets('nothing short says which reading it is short by', (
      tester,
    ) async {
      await pumpShopping(
        tester,
        Model(
          ingredients: [Ingredient('gin', stock: StockLevel.low)],
          recipes: [
            _recipe('Gin Shot', ['gin']),
          ],
        ),
      );
      expect(
        find.text(
          'Every recipe you have can be made from what is on the shelf.',
        ),
        findsOneWidget,
      );
      await toggleLow(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'gin', '1 recipe']);
    });

    testWidgets('says what would put baskets there while it is empty', (
      tester,
    ) async {
      await pumpShopping(tester, Model());
      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('searches only while it is the destination on show', (
      tester,
    ) async {
      await pumpApp(tester, store: MemoryModelStore(shoppingModel));
      expect(find.text('Buy'), findsNothing);
      await tap(tester, find.text('Shopping'));
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('white rum'), findsOneWidget);
      await tap(tester, find.text('Recipes'));
      expect(
        find.text('Buy'),
        findsNothing,
        reason: 'the answer is let go along with the screen that asked for it',
      );
    });

    testWidgets('both controls stand on the one row on a phone', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShopping(tester);
      expect(
        tester.getCenter(find.text('Buy')).dy,
        tester.getCenter(find.text('Low too')).dy,
      );
    });

    testWidgets('and fall to two rows rather than off the edge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShopping(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.text('Buy')).dy,
        lessThan(tester.getCenter(find.text('Low too')).dy),
      );
    });
  });
}
