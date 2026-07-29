import 'package:cocktails/data/data.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:cocktails/ui/screens/shopping_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  group('settings screen', () {
    testWidgets('the tags tile opens both vocabularies', (tester) async {
      await pumpScreen(tester, const SettingsScreen());
      await tap(tester, find.text('Tags'));
      expect(find.widgetWithText(Tab, 'Recipe'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Ingredient'), findsOneWidget);
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
