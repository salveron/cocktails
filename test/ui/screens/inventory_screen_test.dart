import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Every row's text in list order — names and stock chips interleaved.
Iterable<String?> rowTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
    )
    .map((text) => text.data);

void main() {
  group('inventory screen', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const InventoryScreen());
      expect(find.text('No ingredients yet'), findsOneWidget);
      expect(find.byType(SearchField), findsNothing);
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
      await tester.enterText(find.byType(TextField), 'CAMP');
      await tester.pumpAndSettle();
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('ignores space typed around the query', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await tester.enterText(find.byType(TextField), '  camp  ');
      await tester.pumpAndSettle();
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('finds a capitalised name typed in lower case', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(
          Model(ingredients: const [Ingredient('Green Chartreuse')]),
        ),
      );
      await tester.enterText(find.byType(TextField), 'chartreuse');
      await tester.pumpAndSettle();
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
      await tester.enterText(find.byType(TextField), 'camp');
      await tester.pumpAndSettle();
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
      await tester.enterText(find.byType(TextField), 'absinthe');
      await tester.pumpAndSettle();
      expect(find.text('No ingredient here is called "absinthe".'), findsOne);
      expect(find.byType(SearchField), findsOneWidget);
    });
  });
}
