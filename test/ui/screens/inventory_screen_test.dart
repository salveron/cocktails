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

/// The overflow menu of the row named [name].
Finder rowMenu(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: find.byTooltip('More'),
);

/// Picks [action] out of that row's menu.
Future<void> chooseOnRow(
  WidgetTester tester,
  String name,
  String action,
) async {
  await tester.tap(rowMenu(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

/// The dialog's own field, told apart from the search field behind it.
final dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

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

    testWidgets('the add button puts a new bottle in the list, out of stock', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await tap(tester, find.byTooltip('Add ingredient'));
      await tester.enterText(dialogField, 'absinthe');
      await tester.pumpAndSettle();
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
      await tester.enterText(find.byType(TextField), 'absinthe');
      await tester.pumpAndSettle();
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
      await tester.enterText(dialogField, 'sloe gin');
      await tester.pumpAndSettle();
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
        fixtureModel.withIngredient(const Ingredient('absinthe')),
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
