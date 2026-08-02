import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/palette.dart';
import 'package:cocktails/ui/screens/tags_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Both vocabularies stocked, each holding one tag something references and one
/// nothing does — so blocked and free deletes are both a tap away.
final tagged = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('lemon juice', tags: const ['citrus']),
  ],
  ingredientTags: const [
    Tag('citrus', color: TagColor.sand),
    Tag('homemade', color: TagColor.slate),
  ],
  recipeTags: const [
    Tag('classic', color: TagColor.rose),
    Tag('sour', color: TagColor.teal),
  ],
  recipes: [
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
      ],
    ),
  ],
);

/// The screen over its store, opened on the Recipe tab.
Future<MemoryModelStore> pumpTags(WidgetTester tester, {Model? model}) =>
    pumpOver(tester, const TagsScreen(), model ?? tagged);

Future<void> openTab(WidgetTester tester, String tab) =>
    tap(tester, find.text(tab));

void main() {
  group('tags screen', () {
    testWidgets('a tab of its own for each vocabulary', (tester) async {
      await pumpTags(tester);
      expect(find.widgetWithText(Tab, 'Recipe'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Ingredient'), findsOneWidget);
    });

    testWidgets('a tab lists its own vocabulary and no other', (tester) async {
      await pumpTags(tester);
      expect(rowTexts(tester), ['classic', 'sour']);
      await openTab(tester, 'Ingredient');
      expect(rowTexts(tester), ['citrus', 'homemade']);
    });

    testWidgets('a vocabulary opens A→Z and can be read by colour', (
      tester,
    ) async {
      await pumpTags(tester);
      await openSort(tester);
      expect(sortedBy(tester), ('Name', false));
      expect(rowTexts(tester), ['classic', 'sour']);

      // The palette's own order, which teal leads and rose does not.
      await sortBy(tester, 'Colour');
      expect(rowTexts(tester), ['sour', 'classic']);
    });

    testWidgets('every tag is lettered on the colour it carries', (
      tester,
    ) async {
      await pumpTags(tester);
      expect(
        chipColor(tester, 'classic'),
        tagColors(TagColor.rose, Brightness.light).fill,
      );
      expect(
        chipColor(tester, 'sour'),
        tagColors(TagColor.teal, Brightness.light).fill,
      );
    });

    testWidgets('says what would fill a vocabulary with nothing in it', (
      tester,
    ) async {
      await pumpTags(tester, model: Model());
      expect(find.text('No recipe tags yet'), findsOneWidget);
      await openTab(tester, 'Ingredient');
      expect(find.text('No ingredient tags yet'), findsOneWidget);
    });

    testWidgets('a new tag opens on a colour the vocabulary has not spent', (
      tester,
    ) async {
      await pumpTags(tester);
      await tap(tester, find.byTooltip('Add recipe tag'));
      // teal and rose are taken; indigo is the next the palette offers.
      expect(isChosen(tester, 'indigo'), isTrue);
    });

    testWidgets('a new tag joins its own vocabulary in the colour picked', (
      tester,
    ) async {
      final store = await pumpTags(tester);
      await tap(tester, find.byTooltip('Add recipe tag'));
      await type(tester, 'tiki');
      await pick(tester, TagColor.plum);
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), ['classic', 'sour', 'tiki']);
      expect(
        store.saved?.recipeTags.last,
        const Tag('tiki', color: TagColor.plum),
      );
      expect(store.saved?.ingredientTags, tagged.ingredientTags);
    });

    testWidgets('the row itself opens the editor on that tag', (tester) async {
      await pumpTags(tester);
      await tap(tester, find.text('classic'));
      expect(find.text('Edit "classic"'), findsOneWidget);
      expect(isChosen(tester, 'rose'), isTrue);
    });

    testWidgets('a rename follows the tag into the recipes', (tester) async {
      final store = await pumpTags(tester);
      await chooseOnRow(tester, 'classic', 'Edit');
      await type(tester, 'vintage');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), ['sour', 'vintage']);
      expect(store.saved?.recipeNamed('Negroni')?.tags, ['vintage']);
      // One entry, one save: a rename must not spend two backup rotations.
      expect(store.saveCount, 1);
    });

    testWidgets('a name and a colour changed together are one write', (
      tester,
    ) async {
      final store = await pumpTags(tester);
      await chooseOnRow(tester, 'classic', 'Edit');
      await type(tester, 'vintage');
      await pick(tester, TagColor.plum);
      await tap(tester, find.text('Save'));

      expect(store.saved?.recipeTags, const [
        Tag('vintage', color: TagColor.plum),
        Tag('sour', color: TagColor.teal),
      ]);
      expect(store.saved?.recipeNamed('Negroni')?.tags, ['vintage']);
      expect(store.saveCount, 1);
    });

    testWidgets('a rename on one side leaves the other vocabulary alone', (
      tester,
    ) async {
      final store = await pumpTags(tester);
      await openTab(tester, 'Ingredient');
      await chooseOnRow(tester, 'citrus', 'Edit');
      await type(tester, 'fresh citrus');
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientNamed('lemon juice')?.tags, [
        'fresh citrus',
      ]);
      expect(store.saved?.recipeTags, tagged.recipeTags);
    });

    testWidgets('a colour changed alone is the only thing that moves', (
      tester,
    ) async {
      final store = await pumpTags(tester);
      await chooseOnRow(tester, 'sour', 'Edit');
      await pick(tester, TagColor.slate);
      await tap(tester, find.text('Save'));

      expect(store.saved?.recipeTags, const [
        Tag('classic', color: TagColor.rose),
        Tag('sour', color: TagColor.slate),
      ]);
      expect(
        store.saveCount,
        1,
        reason: 'a name left alone is no second write',
      );
    });

    testWidgets('a recipe tag a recipe wears will not go', (tester) async {
      final store = await pumpTags(tester);
      await chooseOnRow(tester, 'classic', 'Delete');

      expect(find.text('Cannot delete "classic"'), findsOneWidget);
      expect(find.text('Remove it from these recipes first:'), findsOneWidget);
      expect(find.text('• Negroni'), findsOneWidget);
      await tap(tester, find.text('Close'));
      expect(rowTexts(tester), ['classic', 'sour']);
      expect(store.saveCount, 0);
    });

    testWidgets('an ingredient tag is blocked by the bottles wearing it', (
      tester,
    ) async {
      await pumpTags(tester);
      await openTab(tester, 'Ingredient');
      await chooseOnRow(tester, 'citrus', 'Delete');

      expect(find.text('Cannot delete "citrus"'), findsOneWidget);
      expect(
        find.text('Remove it from these ingredients first:'),
        findsOneWidget,
      );
      expect(find.text('• lemon juice'), findsOneWidget);
    });

    testWidgets('a tag nothing wears goes once confirmed', (tester) async {
      final store = await pumpTags(tester);
      await openTab(tester, 'Ingredient');
      await chooseOnRow(tester, 'homemade', 'Delete');
      await tap(tester, find.text('Delete'));

      expect(rowTexts(tester), ['citrus']);
      expect(store.saved?.ingredientTags, const [
        Tag('citrus', color: TagColor.sand),
      ]);
    });

    testWidgets('one name may stand in both vocabularies at once', (
      tester,
    ) async {
      final store = await pumpTags(tester);
      await openTab(tester, 'Ingredient');
      await tap(tester, find.byTooltip('Add ingredient tag'));
      await type(tester, 'classic');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientTags.last.name, 'classic');
      expect(store.saved?.recipeTags, tagged.recipeTags);
    });

    testWidgets(
      'search narrows a tab, and names the query when nothing is left',
      (tester) async {
        await pumpTags(tester);
        await search(tester, 'sou');
        expect(rowTexts(tester), ['sour']);

        await search(tester, 'tiki');
        expect(
          find.text('No recipe tag here answers to "tiki".'),
          findsOneWidget,
        );
      },
    );
  });
}
