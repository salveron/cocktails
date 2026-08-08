import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// A store that cannot write, so the one thing a failed replace must not do —
/// leave for a collection that was never written — can be watched.
final class _UnwritableStore implements ModelStore {
  @override
  Future<LoadOutcome> load() async => Loaded(fixtureModel);

  @override
  Future<void> save(Model model) async => throw Exception('disk full');

  @override
  Future<String> exportSnapshot(
    Model model, {
    ExportPurpose purpose = ExportPurpose.share,
  }) async => 'memory:${purpose.name}';
}

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
      // Import acts too: what it opens is the system's picker, and where it
      // goes afterwards depends on what came back.
      expect(chevronOn('Import'), findsNothing);
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
      expect(shared, ['memory:share']);
      // What went out is the collection on screen, not a file re-read (ADR 18).
      expect(store.snapshots[ExportPurpose.share], fixtureModel);
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

  group('import', () {
    /// A file holding three recipes and nine bottles, against the one recipe
    /// and two bottles the screen opens over — so every count on the review
    /// tells the file's collection from the reader's.
    final pickedFile = const YamlCodec().encode(recipeModel);

    /// A file the codec can read but the rules refuse: nothing declares "rye".
    const damagedFile = '''
format: 1
recipes:
  - name: Sazerac
    lines: ["2 parts rye"]
''';

    /// The Import row tapped over a store holding [fixtureModel], with the
    /// system's picker answering [picked] — a file, nothing, or a refusal.
    Future<MemoryModelStore> importOver(
      WidgetTester tester,
      Future<String?> Function() picked,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(
        tester,
        const SettingsScreen(),
        store: store,
        picker: picked,
      );
      await tap(tester, find.text('Import'));
      return store;
    }

    testWidgets('a picked file is put in front of the reader before anything '
        'moves (FR-DAT-3)', (tester) async {
      final store = await importOver(tester, () async => pickedFile);
      expect(find.widgetWithText(AppBar, 'Import'), findsOneWidget);
      expect(find.text('This file holds'), findsOneWidget);
      expect(find.text('3 recipes'), findsOneWidget);
      expect(find.text('9 bottles'), findsOneWidget);
      expect(find.text('2 tags'), findsOneWidget);
      expect(find.text('7 units'), findsOneWidget);
      // What it stands to replace, in the same terms.
      expect(
        find.textContaining('Replaces the 1 recipe and 2 bottles'),
        findsOneWidget,
      );
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    testWidgets('the replace lands, keeping a copy of what it replaced '
        '(FR-DAT-3)', (tester) async {
      final store = await importOver(tester, () async => pickedFile);
      await tap(tester, find.text('Replace everything'));
      expect(store.saved, recipeModel);
      expect(store.snapshots[ExportPurpose.beforeImport], fixtureModel);
      expect(find.text('3 recipes imported.'), findsOneWidget);
    });

    testWidgets('a file the rules refuse changes nothing, and says what and '
        'where (FR-DAT-4)', (tester) async {
      final store = await importOver(tester, () async => damagedFile);
      expect(find.text('This file cannot be imported'), findsOneWidget);
      expect(find.textContaining('rye'), findsOneWidget);
      expect(find.textContaining('line '), findsOneWidget);
      // Nothing to agree to, and nothing agreed to.
      expect(find.text('Replace everything'), findsNothing);
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    testWidgets('a file that is not the format at all is refused too', (
      tester,
    ) async {
      await importOver(tester, () async => 'not a cocktail in sight');
      expect(find.text('This file cannot be imported'), findsOneWidget);
      expect(find.text('Replace everything'), findsNothing);
    });

    testWidgets('a reader who picks nothing has done nothing', (tester) async {
      final store = await importOver(tester, () async => null);
      expect(find.widgetWithText(AppBar, 'Import'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(store.saveCount, 0);
    });

    testWidgets('a picker that will not open speaks', (tester) async {
      await importOver(tester, () async => throw Exception('no picker here'));
      expect(find.textContaining('Could not read that file'), findsOneWidget);
      expect(find.textContaining('no picker here'), findsOneWidget);
    });

    testWidgets('an Error is a failure too, not silence', (tester) async {
      await importOver(tester, () async => throw StateError('adrift'));
      expect(find.textContaining('Could not read that file'), findsOneWidget);
    });

    testWidgets('a replace that could not be written stays where it is', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SettingsScreen(),
        store: _UnwritableStore(),
        picker: () async => pickedFile,
      );
      await tap(tester, find.text('Import'));
      await tap(tester, find.text('Replace everything'));
      expect(find.textContaining('Could not import'), findsOneWidget);
      // Still on the review: leaving for a collection that never reached the
      // disk would read as a replace that worked.
      expect(find.widgetWithText(AppBar, 'Import'), findsOneWidget);
    });

    testWidgets('the replace leaves for the collection it imported', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: MemoryModelStore(fixtureModel),
        picker: () async => pickedFile,
      );
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Import'));
      await tap(tester, find.text('Replace everything'));
      // Two screens back, where what was imported is: a list of recipes that
      // were not there a moment ago is the answer no sentence improves on.
      expect(find.widgetWithText(AppBar, 'Import'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Settings'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Recipes'), findsOneWidget);
      expect(find.text('Whiskey Sour'), findsOneWidget);
      expect(find.text('3 recipes imported.'), findsOneWidget);
    });
  });
}
