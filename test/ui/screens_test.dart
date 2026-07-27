import 'package:cocktails/data/data.dart';
import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/screens/shopping_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('recipes screen', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const RecipesScreen());
      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('shows what the loaded model holds', (tester) async {
      await pumpScreen(
        tester,
        const RecipesScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      expect(find.text('Recipes: 1'), findsOneWidget);
      expect(find.text('No recipes yet'), findsNothing);
    });
  });

  group('inventory screen', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const InventoryScreen());
      expect(find.text('No ingredients yet'), findsOneWidget);
    });

    testWidgets('shows what the loaded model holds', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      expect(find.text('Ingredients: 2'), findsOneWidget);
      expect(find.text('No ingredients yet'), findsNothing);
    });
  });

  group('shopping screen', () {
    testWidgets('says what would put suggestions there', (tester) async {
      await pumpScreen(
        tester,
        const ShoppingScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      expect(find.text('Nothing to shop for'), findsOneWidget);
    });
  });
}
