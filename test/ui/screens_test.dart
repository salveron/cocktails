import 'package:cocktails/data/data.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
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

    testWidgets('a row that acts carries no chevron, one that travels does', (
      tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen());
      Finder chevronOn(String title) => find.descendant(
        of: find.widgetWithText(ListTile, title),
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(chevronOn('Tags'), findsOneWidget);
      expect(chevronOn('Export'), findsNothing);
    });
  });

  group('export', () {
    /// The location the export answered with, and the copy the store was
    /// handed to make it.
    Future<(List<String>, MemoryModelStore)> exportOver(
      WidgetTester tester, {
      Future<void> Function(String)? sharer,
    }) async {
      final shared = <String>[];
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        store: store,
        sharer: sharer ?? (location) async => shared.add(location),
      );
      await tap(tester, find.text('Export'));
      return (shared, store);
    }

    testWidgets('export hands the copy to the sheet (FR-DAT-1)', (
      tester,
    ) async {
      final (shared, store) = await exportOver(tester);
      expect(shared, ['memory:snapshot']);
      // What went out is the collection on screen, not a file re-read (ADR 18).
      expect(store.exported, fixtureModel);
    });

    testWidgets('the row acts where it stands, and does not travel', (
      tester,
    ) async {
      await exportOver(tester);
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    });

    testWidgets('a sheet that opened says nothing more', (tester) async {
      await exportOver(tester);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed export is the only thing that speaks', (
      tester,
    ) async {
      await exportOver(
        tester,
        sharer: (_) async => throw Exception('no room on disk'),
      );
      expect(find.textContaining('Could not export'), findsOneWidget);
      expect(find.textContaining('no room on disk'), findsOneWidget);
    });

    testWidgets('an Error is a failure too, not silence', (tester) async {
      // Nothing awaits the export, so anything uncaught reaches a reader as
      // nothing happening at all — the one outcome worse than a refusal.
      await exportOver(tester, sharer: (_) async => throw StateError('adrift'));
      expect(find.textContaining('Could not export'), findsOneWidget);
    });
  });
}
