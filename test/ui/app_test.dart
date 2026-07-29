import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/screens/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('app shell', () {
    testWidgets('starts on recipes with every destination one tap away', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(find.widgetWithText(AppBar, 'Recipes'), findsOneWidget);
      expect(find.byType(RecipesScreen), findsOneWidget);
      for (final label in ['Recipes', 'Inventory', 'Shopping']) {
        expect(find.widgetWithText(NavigationBar, label), findsOneWidget);
      }
    });

    testWidgets('a destination tap switches the screen and the title', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Inventory'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Inventory'), findsOneWidget);
      expect(find.byType(InventoryScreen), findsOneWidget);
      expect(find.byType(RecipesScreen), findsNothing);
    });

    testWidgets('a screen switched away from stays alive behind the stack', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      expect(find.byType(ShoppingScreen), findsOneWidget);
      expect(find.byType(RecipesScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('the gear opens settings, and back returns to the shell', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Recipes'), findsOneWidget);
    });

    testWidgets('what the startup load could not read sits above the screen', (
      tester,
    ) async {
      await pumpApp(tester, store: corruptStore());
      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(
        find.textContaining('line 4: Unknown ingredient: "rye"'),
        findsOneWidget,
      );
      expect(find.byType(RecipesScreen), findsOneWidget);
    });

    testWidgets('both schemes are generated from the amber seed', (
      tester,
    ) async {
      const seed = Color(0xFFB26A00);
      await pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.colorScheme, ColorScheme.fromSeed(seedColor: seed));
      expect(
        app.darkTheme?.colorScheme,
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      );
    });
  });
}
