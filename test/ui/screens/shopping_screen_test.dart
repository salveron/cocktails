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

Future<MemoryModelStore> pumpShopping(WidgetTester tester, [Model? model]) =>
    pumpOver(
      tester,
      const ShoppingScreen(showing: true),
      model ?? shoppingModel,
    );

Future<void> pickBudget(WidgetTester tester, int budget) =>
    tap(tester, find.text('$budget'));

Future<void> toggleLow(WidgetTester tester) => tap(tester, find.byType(Switch));

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
      expect(rowTexts(tester), ['white rum', 'Daiquiri', '1 recipe']);
    });

    testWidgets('a wider budget answers with a basket of exactly that many', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 2);
      expect(rowTexts(tester), [
        'campari + sweet vermouth',
        'Americano · Negroni',
        '2 recipes',
      ]);
      await pickBudget(tester, 3);
      expect(rowTexts(tester), [
        'campari + sweet vermouth + white rum',
        'Americano · Daiquiri · Negroni',
        '3 recipes',
      ]);
    });

    testWidgets('the switch moves what counts as short (FR-DIS-7)', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      expect(rowTexts(tester), ['lime juice', 'Gimlet', '1 recipe']);
    });

    testWidgets('a card opens onto its bottles and every recipe', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 3);
      await tap(tester, find.text('campari + sweet vermouth + white rum'));
      expect(bottlesOnCard(tester), ['campari', 'sweet vermouth', 'white rum']);
      expect(
        find.text('Americano · Daiquiri · Negroni'),
        findsOneWidget,
        reason: 'the clipped subtitle reads in full',
      );
    });

    testWidgets('an open card reads each bottle at the level it stands at', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      await pickBudget(tester, 2);
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
        'campari + sweet vermouth',
        'Americano · Negroni',
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
      expect(rowTexts(tester), ['gin', 'Gin Shot', '1 recipe']);
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
