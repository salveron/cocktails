/// What the optimizer is asked (FR-SET-2, ADR 24). Every control settles on
/// the tap, so each test is one tap and one reading of the bar's record — and
/// the record is where it lands, never the collection's file.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/shopping_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_bar_store.dart';
import '../harness.dart';

void main() {
  Future<MemoryBarStore> pumpShoppingSettings(
    WidgetTester tester, [
    Shopping shopping = const Shopping(),
  ]) => pumpOver(
    tester,
    const ShoppingSettingsScreen(),
    fixtureCollection,
    bar: testBar(shopping: shopping),
  );

  /// The switch standing beside [title], the two being told apart by nothing
  /// else on the row they share.
  Finder switchOn(String title) => find.descendant(
    of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
    matching: find.byType(Switch),
  );

  Shopping asked(MemoryBarStore store) =>
      store.savedShelf!.bars.single.shopping;

  group('shopping settings', () {
    testWidgets('every control opens where the record stands', (tester) async {
      await pumpShoppingSettings(
        tester,
        const Shopping(aiming: true, budget: 3, most: 50, restocking: true),
      );
      expect(find.text('Baskets rank by how many'), findsNothing);
      expect(
        tester.widget<Switch>(switchOn('Low too')).value,
        isTrue,
        reason: 'the switch reads the record rather than a default',
      );
    });

    testWidgets('the tag reading is picked and settles at once', (
      tester,
    ) async {
      final store = await pumpShoppingSettings(tester);
      await tap(tester, find.text('Aim'));
      expect(asked(store).aiming, isTrue);
      await tap(tester, find.text('Sift'));
      expect(asked(store).aiming, isFalse);
    });

    testWidgets('its note turns with the pick', (tester) async {
      await pumpShoppingSettings(tester);
      expect(
        find.textContaining('every tag picked is unlocked'),
        findsOneWidget,
      );
      await tap(tester, find.text('Aim'));
      expect(find.textContaining('rank by how many'), findsOneWidget);
    });

    testWidgets('how many baskets of a size are offered (ADR 15)', (
      tester,
    ) async {
      final store = await pumpShoppingSettings(tester);
      await tap(tester, find.text('50'));
      expect(asked(store).most, 50);
    });

    testWidgets('the budget the screen opens at (FR-DIS-6)', (tester) async {
      final store = await pumpShoppingSettings(tester);
      await tap(tester, find.text('3'));
      expect(asked(store).budget, 3);
    });

    testWidgets('both switches, each on its own line', (tester) async {
      final store = await pumpShoppingSettings(tester);
      await tap(tester, switchOn('Low too'));
      expect(asked(store).restocking, isTrue);
      expect(asked(store).buyingOptional, isFalse);
      await tap(tester, switchOn('Optional lines'));
      expect(asked(store).buyingOptional, isTrue);
      expect(asked(store).restocking, isTrue, reason: 'the other stands');
    });

    /// ADR 24: a way of looking is the reader's and never reaches the file a
    /// stranger reads.
    testWidgets('nothing here touches the collection', (tester) async {
      final store = await pumpShoppingSettings(tester);
      await tap(tester, find.text('Aim'));
      expect(store.saved, isNull);
    });

    /// Nothing here can be half-entered, so there is nothing to save or lose.
    testWidgets('offers no Save and asks nothing on the way out', (
      tester,
    ) async {
      await pumpShoppingSettings(tester);
      await tap(tester, find.text('Aim'));
      expect(find.text('Save'), findsNothing);
    });
  });
}
