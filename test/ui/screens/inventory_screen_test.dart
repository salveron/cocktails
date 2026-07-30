import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/palette.dart';
import 'package:cocktails/ui/screens/inventory_screen.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:cocktails/ui/widgets/search_field.dart';
import 'package:cocktails/ui/widgets/tag_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// Three tags over four bottles, every combination the filter has to tell
/// apart: one bottle bare, one wearing a single tag, one wearing two.
final taggedModel = Model(
  ingredientTags: const [
    Tag('citrus', color: TagColor.sand),
    Tag('homemade', color: TagColor.plum),
    Tag('syrup', color: TagColor.teal),
  ],
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('lemon juice', tags: const ['citrus']),
    Ingredient('orgeat', tags: const ['homemade', 'syrup']),
    Ingredient('sugar syrup', tags: const ['syrup']),
  ],
);

Future<void> pumpTagged(WidgetTester tester, [MemoryModelStore? store]) =>
    pumpScreen(
      tester,
      const InventoryScreen(),
      store: store ?? MemoryModelStore(taggedModel),
    );

/// Every ingredient name on screen, the stock words dropped.
Iterable<String?> namesOn(WidgetTester tester) => rowTexts(
  tester,
).where((text) => !const {'In stock', 'Low', 'Out'}.contains(text));

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

    testWidgets('each chip wears the traffic light its level means', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(
          fixtureModel.withIngredient(
            Ingredient('absinthe', stock: StockLevel.low),
          ),
        ),
      );
      final inStock = chipColor(tester, 'In stock');
      final low = chipColor(tester, 'Low');
      final out = chipColor(tester, 'Out');

      expect(inStock.g, greaterThan(inStock.r), reason: 'in stock reads green');
      expect(out.r, greaterThan(out.g), reason: 'out reads red');
      expect(low.b, lessThan(low.g), reason: 'low reads amber');
      expect(
        {inStock, low, out},
        hasLength(3),
        reason: 'three distinct signals',
      );
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
      await search(tester, 'CAMP');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('ignores space typed around the query', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, '  camp  ');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('finds a capitalised name typed in lower case', (tester) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(
          Model(ingredients: [Ingredient('Green Chartreuse')]),
        ),
      );
      await search(tester, 'chartreuse');
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
      await search(tester, 'camp');
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
      await search(tester, 'absinthe');
      expect(find.text('No ingredient here is called "absinthe".'), findsOne);
      expect(find.byType(SearchField), findsOneWidget);
    });

    testWidgets('the add button puts a new bottle in the list, out of stock', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'absinthe');
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
      await search(tester, 'absinthe');
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

    testWidgets('an add backed out of leaves the search where it was', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      await search(tester, 'camp');
      await tap(tester, find.byTooltip('Add ingredient'));
      await tap(tester, find.text('Cancel'));
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('renaming an ingredient follows it into the recipes', (
      tester,
    ) async {
      final store = MemoryModelStore(fixtureModel);
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await chooseOnRow(tester, 'gin', 'Edit');
      // Its own name is not a duplicate of itself.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await type(tester, 'sloe gin');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), ['campari', 'Out', 'sloe gin', 'In stock']);
      expect(
        store.saved?.recipeNamed('Negroni')?.lines.first.ingredient,
        'sloe gin',
      );
      // One entry, one save: a rename must not spend two backup rotations.
      expect(store.saveCount, 1);
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
        fixtureModel.withIngredient(Ingredient('absinthe')),
      );
      await pumpScreen(tester, const InventoryScreen(), store: store);
      await chooseOnRow(tester, 'absinthe', 'Delete');

      expect(find.text('Delete "absinthe"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(rowTexts(tester), ['campari', 'Out', 'gin', 'In stock']);
      expect(store.saved?.ingredientNamed('absinthe'), isNull);
    });
  });

  group('inventory tags', () {
    testWidgets('a bottle wears a dot per tag, in vocabulary order', (
      tester,
    ) async {
      await pumpTagged(tester);
      expect(dotsOn(tester, 'gin'), isEmpty);
      expect(dotsOn(tester, 'lemon juice'), ['citrus']);
      expect(dotsOn(tester, 'orgeat'), ['homemade', 'syrup']);
    });

    testWidgets('a dot wears the colour its chip wears in the legend', (
      tester,
    ) async {
      await pumpTagged(tester);
      final sand = tagColors(TagColor.sand, Brightness.light);
      expect(dotColor(tester, 'lemon juice'), sand.fill);
      expect(chipColor(tester, 'citrus'), sand.fill);
    });

    testWidgets('the legend scrolls sideways instead of growing downward', (
      tester,
    ) async {
      await pumpTagged(tester);
      final scroller = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(TagChoices),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(scroller.scrollDirection, Axis.horizontal);
    });

    testWidgets('the legend waits until the vocabulary has something in it', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const InventoryScreen(),
        store: MemoryModelStore(fixtureModel),
      );
      expect(find.byType(TagChoices), findsNothing);

      await pumpTagged(tester);
      expect(find.byType(TagChoices), findsOneWidget);
      expect(find.widgetWithText(ColorChip, 'homemade'), findsOneWidget);
    });

    testWidgets('picking a tag keeps the bottles wearing it', (tester) async {
      await pumpTagged(tester);
      await pickTag(tester, 'syrup');
      expect(isPicked(tester, 'syrup'), isTrue);
      expect(namesOn(tester), ['orgeat', 'sugar syrup']);
    });

    testWidgets('picking a second one keeps only what wears both', (
      tester,
    ) async {
      await pumpTagged(tester);
      await pickTag(tester, 'syrup');
      await pickTag(tester, 'homemade');
      expect(namesOn(tester), ['orgeat']);
    });

    testWidgets('picking a lit tag again lets the rest back in', (
      tester,
    ) async {
      await pumpTagged(tester);
      await pickTag(tester, 'citrus');
      expect(namesOn(tester), ['lemon juice']);
      await pickTag(tester, 'citrus');
      expect(isPicked(tester, 'citrus'), isFalse);
      expect(namesOn(tester), ['gin', 'lemon juice', 'orgeat', 'sugar syrup']);
    });

    testWidgets('the tags and the search narrow together', (tester) async {
      await pumpTagged(tester);
      await pickTag(tester, 'syrup');
      await search(tester, 'sugar');
      expect(namesOn(tester), ['sugar syrup']);
    });

    testWidgets('an empty list blames the tags when the tags emptied it', (
      tester,
    ) async {
      await pumpTagged(tester);
      await pickTag(tester, 'citrus');
      await pickTag(tester, 'syrup');
      expect(
        find.text('No ingredient here matches every tag you picked.'),
        findsOneWidget,
      );
      expect(find.textContaining('Add "'), findsNothing);
    });

    testWidgets('and blames both when both narrowed it', (tester) async {
      await pumpTagged(tester);
      await pickTag(tester, 'citrus');
      await search(tester, 'gin');
      expect(
        find.text(
          'No ingredient here is called "gin" and matches every tag you '
          'picked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tag renamed elsewhere stops filtering', (tester) async {
      await pumpTagged(tester);
      await pickTag(tester, 'syrup');
      expect(namesOn(tester), ['orgeat', 'sugar syrup']);

      await ProviderScope.containerOf(
        tester.element(find.byType(InventoryScreen)),
        listen: false,
      ).read(modelProvider.notifier).renameIngredientTag('syrup', 'sirop');
      await tester.pumpAndSettle();

      expect(isPicked(tester, 'sirop'), isFalse);
      expect(namesOn(tester), ['gin', 'lemon juice', 'orgeat', 'sugar syrup']);
    });

    testWidgets('an add clears the picked tags along with the search', (
      tester,
    ) async {
      await pumpTagged(tester);
      await pickTag(tester, 'citrus');
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));
      expect(namesOn(tester), [
        'absinthe',
        'gin',
        'lemon juice',
        'orgeat',
        'sugar syrup',
      ]);
    });

    testWidgets('a new bottle can be born tagged', (tester) async {
      final store = MemoryModelStore(taggedModel);
      await pumpTagged(tester, store);
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'lime juice');
      await chooseTag(tester, 'citrus');
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientNamed('lime juice')?.tags, ['citrus']);
      expect(dotsOn(tester, 'lime juice'), ['citrus']);
    });

    testWidgets('an edit settles the name and the tags at once', (
      tester,
    ) async {
      final store = MemoryModelStore(taggedModel);
      await pumpTagged(tester, store);
      await chooseOnRow(tester, 'sugar syrup', 'Edit');
      await type(tester, 'gomme syrup');
      await chooseTag(tester, 'homemade');
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientNamed('sugar syrup'), isNull);
      expect(store.saved?.ingredientNamed('gomme syrup')?.tags, [
        'homemade',
        'syrup',
      ]);
      expect(dotsOn(tester, 'gomme syrup'), ['homemade', 'syrup']);
    });
  });
}
