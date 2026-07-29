import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

void main() {
  group('inventory screen', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const InventoryScreen());
      expect(find.text('No ingredients yet'), findsOneWidget);
      expect(find.byType(SearchField), findsNothing);
      expect(find.byTooltip('Add ingredient'), findsOneWidget);
    });

    testWidgets('lists every ingredient alphabetically with its stock', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      expect(rowTexts(tester), ['campari', 'Out', 'gin', 'In stock']);
    });

    testWidgets('each chip wears the traffic light its level means', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(
          fixtureModel.withIngredient(
            Ingredient('absinthe', stock: StockLevel.low),
          ),
        ),
      );
      final inStock = chipColor(tester, 'In stock');
      final low = chipColor(tester, 'Low');
      final out = chipColor(tester, 'Out');

      expect(inStock.g, greaterThan(inStock.r), reason: 'in stock reads green');
      expect(out.r, greaterThan(out.g), reason: 'out reads red');
      expect(low.b, lessThan(low.g), reason: 'low reads amber');
      expect(
        {inStock, low, out},
        hasLength(3),
        reason: 'three distinct signals',
      );
    });

    testWidgets('a tap moves the bottle one step through its life', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);

      for (final expected in ['Low', 'Out', 'In stock']) {
        await tester.tap(find.text('gin'));
        await tester.pumpAndSettle();
        expect(rowTexts(tester), ['campari', 'Out', 'gin', expected]);
      }
      expect(store.saved?.ingredientNamed('gin')?.stock, StockLevel.in_);
      expect(store.saveCount, 3);
    });

    testWidgets('search narrows the list by name, ignoring case', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'CAMP');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('ignores space typed around the query', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, '  camp  ');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('finds a capitalised name typed in lower case', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(
          Model(ingredients: [Ingredient('Green Chartreuse')]),
        ),
      );
      await search(tester, 'chartreuse');
      expect(rowTexts(tester), ['Green Chartreuse', 'Out']);
    });

    testWidgets('clearing the search brings the whole list back', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'camp');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(rowTexts(tester), ['campari', 'Out', 'gin', 'In stock']);
    });

    testWidgets('names the query when nothing matches, keeping the field', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'absinthe');
      expect(find.text('No ingredient here is called "absinthe".'), findsOne);
      expect(find.byType(SearchField), findsOneWidget);
    });

    testWidgets('the add button puts a new bottle in the list, out of stock', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), [
        'absinthe',
        'Out',
        'campari',
        'Out',
        'gin',
        'In stock',
      ]);
      expect(store.saved?.ingredientNamed('absinthe')?.stock, StockLevel.out);
    });

    testWidgets('a search that found nothing is one tap from creating it', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'absinthe');
      await tap(tester, find.text('Add "absinthe"'));
      // Saving without typing is what proves the query came along.
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), [
        'absinthe',
        'Out',
        'campari',
        'Out',
        'gin',
        'In stock',
      ]);
    });

    testWidgets('an add backed out of leaves the search where it was', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'camp');
      await tap(tester, find.byTooltip('Add ingredient'));
      await tap(tester, find.text('Cancel'));
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('renaming an ingredient follows it into the recipes', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await chooseOnRow(tester, 'gin', 'Rename');
      // Its own name is not a duplicate of itself.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await type(tester, 'sloe gin');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), ['campari', 'Out', 'sloe gin', 'In stock']);
      expect(
        store.saved?.recipeNamed('Negroni')?.lines.first.ingredient,
        'sloe gin',
      );
    });

    testWidgets('an ingredient a recipe uses will not go', (tester) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await chooseOnRow(tester, 'gin', 'Delete');

      expect(find.text('Cannot delete "gin"'), findsOneWidget);
      expect(find.text('• Negroni'), findsOneWidget);
      await tap(tester, find.text('Close'));
      expect(rowTexts(tester), ['campari', 'Out', 'gin', 'In stock']);
      expect(store.saveCount, 0);
    });

    testWidgets('an ingredient no recipe uses goes once confirmed', (
      tester,
    ) async {
      final store = MemoryModelStore(
        fixtureModel.withIngredient(Ingredient('absinthe')),
      );
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await chooseOnRow(tester, 'absinthe', 'Delete');

      expect(find.text('Delete "absinthe"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(rowTexts(tester), ['campari', 'Out', 'gin', 'In stock']);
      expect(store.saved?.ingredientNamed('absinthe'), isNull);
    });
  });
}
