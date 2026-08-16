import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// A store that cannot write, so the one thing a failed replace must not do —
/// leave for a collection that was never written — can be watched.
final class _UnwritableStore extends MemoryBarStore {
  _UnwritableStore() : super.of(testBar(), fixtureCollection);

  @override
  Future<void> saveBar(Bar bar, Collection collection) async =>
      throw Exception('disk full');
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
    Future<(List<String>, MemoryBarStore)> exportOver(
      WidgetTester tester, {
      Future<void> Function(String)? sharer,
    }) async {
      final shared = <String>[];
      final store = MemoryBarStore.of(testBar(), fixtureCollection);
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
      expect(store.snapshots[ExportPurpose.share]?.$2, fixtureCollection);
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
    /// A file holding three recipes and nine ingredients, against the one recipe
    /// and two ingredients the screen opens over — so a count on the review
    /// cannot be read off the store and pass for the file's.
    final pickedFile = fileOf(recipeCollection);

    /// The Import row tapped over a store holding [fixtureCollection], with the
    /// system's picker answering [picked] — a file, nothing, or a refusal.
    Future<MemoryBarStore> importOver(
      WidgetTester tester,
      Future<String?> Function() picked,
    ) async {
      final store = MemoryBarStore.of(testBar(), fixtureCollection);
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
      // One card a kind, counted in the noun the screen managing it uses.
      expect(find.text('3 recipes'), findsOneWidget);
      expect(find.text('9 ingredients'), findsOneWidget);
      expect(find.text('2 tags'), findsOneWidget);
      expect(find.text('7 units'), findsOneWidget);
      expect(
        find.textContaining('Replace everything this bar holds now'),
        findsOneWidget,
      );
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    testWidgets('a card names what it counts before it is opened', (
      tester,
    ) async {
      await importOver(tester, () async => pickedFile);
      // A→Z, as the recipe list itself reads, and cut off rather than wrapped.
      final line = tester.widget<Text>(
        find.text('Daiquiri, Negroni, Whiskey Sour'),
      );
      expect(line.maxLines, 1);
      expect(line.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an opened card gives every name it counted', (tester) async {
      await importOver(tester, () async => pickedFile);
      await tap(tester, find.text('9 ingredients'));
      for (final ingredient in recipeCollection.ingredients) {
        expect(find.text('• ${ingredient.name}'), findsOneWidget);
      }
      // The line under the title has said all it can; the body says the rest.
      expect(find.textContaining('bourbon, campari,'), findsNothing);
    });

    testWidgets('a card holding thousands still gives them all', (
      tester,
    ) async {
      final many = Collection(
        ingredients: [Ingredient('gin')],
        recipes: [
          for (var index = 0; index < 2000; index++)
            Recipe(
              'Recipe ${index.toString().padLeft(4, '0')}',
              lines: const [
                RecipeLine(Amount(1), 'part', ['gin']),
              ],
            ),
        ],
      );
      await importOver(tester, () async => fileOf(many));
      await tap(tester, find.text('2000 recipes'));
      // The last one as surely as the first: a list cut short is exactly where
      // the entry a reader came looking for would have been.
      expect(find.text('• Recipe 0000'), findsOneWidget);
      expect(find.text('• Recipe 1999'), findsOneWidget);
    });

    testWidgets('the two tag vocabularies stay apart when opened (ADR 07)', (
      tester,
    ) async {
      final both = Collection(
        ingredients: [
          Ingredient('gin', tags: const ['juniper']),
        ],
        ingredientTags: const [Tag('juniper', color: TagColor.sand)],
        recipeTags: const [Tag('classic', color: TagColor.rose)],
      );
      await importOver(tester, () async => fileOf(both));
      // One count over both, the body keeping the lists it came from.
      await tap(tester, find.text('2 tags'));
      expect(find.text('Recipe'), findsOneWidget);
      expect(find.text('• classic'), findsOneWidget);
      expect(find.text('Ingredient'), findsOneWidget);
      expect(find.text('• juniper'), findsOneWidget);
    });

    testWidgets('a vocabulary the file has none of is not labelled', (
      tester,
    ) async {
      // recipeCollection carries recipe tags and no ingredient tags.
      await importOver(tester, () async => pickedFile);
      await tap(tester, find.text('2 tags'));
      expect(find.text('Recipe'), findsOneWidget);
      expect(find.text('Ingredient'), findsNothing);
    });

    testWidgets('a kind the file holds none of does not open', (tester) async {
      await importOver(tester, () async => fileOf(Collection()));
      expect(find.text('0 recipes'), findsOneWidget);
      await tap(tester, find.text('0 recipes'));
      // Nothing to open, so no chevron offered and the tap answered with none.
      expect(find.byIcon(Icons.expand_less), findsNothing);
    });

    testWidgets('the replace lands, keeping a copy of what it replaced '
        '(FR-DAT-3)', (tester) async {
      final store = await importOver(tester, () async => pickedFile);
      // Replace is the road the screen opens on, the file having been picked
      // from the open bar's own gear.
      await tap(tester, find.text('Save'));
      expect(store.saved, recipeCollection);
      expect(
        store.snapshots[ExportPurpose.beforeImport]?.$2,
        fixtureCollection,
      );
      expect(find.text('3 recipes imported.'), findsOneWidget);
    });

    testWidgets('the other road founds a bar of its own and leaves nothing '
        'behind (FR-BAR-7)', (tester) async {
      final store = await importOver(tester, () async => pickedFile);
      await tap(tester, find.text('Guest'));
      await tap(tester, find.text('Save'));
      // The bar that stood is untouched — same name, same contents, still on
      // the shelf beside the one that just arrived.
      final shelf = store.savedShelf!;
      expect(shelf.bars, hasLength(2));
      final added = shelf.bars.firstWhere((bar) => bar.id == shelf.openId);
      expect(added.mode, BarMode.guest);
      expect(added.name, "Ada's bar");
      // Kept, so a refresh asks the same way again (FR-BAR-5).
      expect(added.source?.via, Transport.file);
      expect(store.savedBars[added.id]?.$2, recipeCollection);
      expect(store.savedBars[testBar().id], isNull);
      // Nothing was replaced, so nothing was copied out of the way first.
      expect(store.snapshots, isEmpty);
      // The reader lands in the bar that just arrived, which says it better
      // than a sentence would; only the road that puts them back where they
      // started speaks.
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('both roads are offered, and the chosen one says what it '
        'does', (tester) async {
      await importOver(tester, () async => pickedFile);
      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Guest'), findsOneWidget);
      await tap(tester, find.text('Guest'));
      expect(find.textContaining('read-only'), findsOneWidget);
      expect(find.textContaining('Replace everything'), findsNothing);
    });

    /// The file's own name is a starting value on the road that founds a bar,
    /// and no suggestion at all on the road that leaves one standing (ADR 21).
    testWidgets('the name follows the road until the reader writes one', (
      tester,
    ) async {
      await importOver(tester, () async => pickedFile);
      expect(
        tester.widget<TextField>(barNameField).controller?.text,
        'Home bar',
      );
      await tap(tester, find.text('Guest'));
      expect(
        tester.widget<TextField>(barNameField).controller?.text,
        "Ada's bar",
      );
      await typeInto(tester, barNameField, 'Cellar');
      await tap(tester, find.text('Replace'));
      expect(tester.widget<TextField>(barNameField).controller?.text, 'Cellar');
    });

    testWidgets('one arrived at with a file is left without being asked', (
      tester,
    ) async {
      await importOver(tester, () async => pickedFile);
      await tap(tester, find.byTooltip('Back'));
      // Nothing was typed and nothing chosen, so there is nothing to discard:
      // the pick that opened this screen is not an edit the reader made on it.
      expect(find.text('Discard this import?'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    });

    testWidgets('another file may be chosen in place of the one on show', (
      tester,
    ) async {
      var second = false;
      await pumpScreen(
        tester,
        const SettingsScreen(),
        store: MemoryBarStore.of(testBar(), fixtureCollection),
        picker: () async {
          final answer = second ? fileOf(Collection()) : pickedFile;
          second = true;
          return answer;
        },
      );
      await tap(tester, find.text('Import'));
      expect(find.text('3 recipes'), findsOneWidget);
      await tap(tester, find.text('Choose another file'));
      expect(find.text('0 recipes'), findsOneWidget);
      expect(find.text('3 recipes'), findsNothing);
      // Nothing to empty here: the file is what the screen is for, and the way
      // out of one is the way back.
      expect(find.byTooltip('Leave it empty'), findsNothing);
    });

    testWidgets('a file the rules refuse changes nothing, and says what and '
        'where (FR-DAT-4)', (tester) async {
      final store = await importOver(tester, () async => damagedFile);
      expect(find.text('This file cannot be read'), findsOneWidget);
      expect(find.textContaining('rye'), findsOneWidget);
      expect(find.textContaining('line '), findsOneWidget);
      // Nothing to agree to, and nothing agreed to.
      expect(find.text('Replace'), findsNothing);
      expect(find.text('Guest'), findsNothing);
      expect(saveEnabled(tester), isFalse);
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    testWidgets('a file that is not the format at all is refused too', (
      tester,
    ) async {
      await importOver(tester, () async => 'not a cocktail in sight');
      expect(find.text('This file cannot be read'), findsOneWidget);
      expect(find.text('Replace'), findsNothing);
      expect(find.text('Guest'), findsNothing);
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
      await tap(tester, find.text('Save'));
      expect(find.textContaining('Could not import'), findsOneWidget);
      // Still on the form: leaving for a collection that never reached the
      // disk would read as a replace that worked.
      expect(find.widgetWithText(AppBar, 'Import'), findsOneWidget);
    });

    testWidgets('the replace leaves for the collection it imported', (
      tester,
    ) async {
      await pumpApp(
        tester,
        store: MemoryBarStore.of(testBar(), fixtureCollection),
        picker: () async => pickedFile,
      );
      await tap(tester, find.byTooltip('Settings'));
      await tap(tester, find.text('Import'));
      await tap(tester, find.text('Save'));
      // Two screens back, where what was imported is: a list of recipes that
      // were not there a moment ago is the answer no sentence improves on.
      expect(find.widgetWithText(AppBar, 'Import'), findsNothing);
      expect(find.widgetWithText(AppBar, 'Settings'), findsNothing);
      // Under the name it already had: an import replaces what a bar holds,
      // and what it is called is the reader's (ADR 21).
      expect(shellTitle('Recipes', bar: 'Home bar'), findsOneWidget);
      expect(find.text('Whiskey Sour'), findsOneWidget);
      expect(find.text('3 recipes imported.'), findsOneWidget);
    });
  });
}
