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
final taggedCollection = Collection(
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

/// Three bottles over two levels, so an order and its reverse read differently
/// and the tie between the two empty ones shows the A→Z under both.
final orderedCollection = fixtureCollection.withIngredient(
  Ingredient('absinthe'),
);

Future<MemoryBarStore> pumpInventory(
  WidgetTester tester, [
  Collection? collection,
]) => pumpOver(tester, const InventoryScreen(), collection ?? taggedCollection);

/// Every ingredient name on screen, the stock words dropped.
Iterable<String?> namesOn(WidgetTester tester) => rowTexts(
  tester,
).where((text) => !const {'In stock', 'Low', 'Out'}.contains(text));

void main() {
  group('inventory screen', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpInventory(tester, Collection());
      expect(find.text('No ingredients yet'), findsOneWidget);
      expect(find.byType(SearchField), findsNothing);
      expect(find.byTooltip('Add ingredient'), findsOneWidget);
    });

    testWidgets('opens on what is in stock, each bottle with its level', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      expect(rowTexts(tester), ['gin', 'In stock', 'campari', 'Out']);
    });

    testWidgets('each chip wears the traffic light its level means', (
      tester,
    ) async {
      await pumpInventory(
        tester,
        fixtureCollection.withIngredient(
          Ingredient('absinthe', stock: StockLevel.low),
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
      final store = await pumpInventory(tester, fixtureCollection);

      for (final expected in ['Low', 'Out', 'In stock']) {
        await tester.tap(find.text('gin'));
        await tester.pumpAndSettle();
        expect(rowTexts(tester), ['gin', expected, 'campari', 'Out']);
      }
      expect(store.saved?.ingredientNamed('gin')?.stock, StockLevel.in_);
      expect(store.saveCount, 3);
    });

    testWidgets('search narrows the list by name, ignoring case', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, 'CAMP');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('ignores space typed around the query', (tester) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, '  camp  ');
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('finds a capitalised name typed in lower case', (tester) async {
      await pumpInventory(
        tester,
        Collection(ingredients: [Ingredient('Green Chartreuse')]),
      );
      await search(tester, 'chartreuse');
      expect(rowTexts(tester), ['Green Chartreuse', 'Out']);
    });

    testWidgets('clearing the search brings the whole list back', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, 'camp');
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(rowTexts(tester), ['gin', 'In stock', 'campari', 'Out']);
    });

    testWidgets('names the query when nothing matches, keeping the field', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, 'absinthe');
      expect(find.text('No ingredient here answers to "absinthe".'), findsOne);
      expect(find.byType(SearchField), findsOneWidget);
    });

    testWidgets('the add button puts a new bottle in the list, out of stock', (
      tester,
    ) async {
      final store = await pumpInventory(tester, fixtureCollection);
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), [
        'gin',
        'In stock',
        'absinthe',
        'Out',
        'campari',
        'Out',
      ]);
      expect(store.saved?.ingredientNamed('absinthe')?.stock, StockLevel.out);
    });

    testWidgets('a search that found nothing is one tap from creating it', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, 'absinthe');
      await tap(tester, find.text('Add "absinthe"'));
      // Saving without typing is what proves the query came along.
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), [
        'gin',
        'In stock',
        'absinthe',
        'Out',
        'campari',
        'Out',
      ]);
    });

    testWidgets('an add backed out of leaves the search where it was', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      await search(tester, 'camp');
      await tap(tester, find.byTooltip('Add ingredient'));
      await tap(tester, find.text('Cancel'));
      expect(rowTexts(tester), ['campari', 'Out']);
    });

    testWidgets('renaming an ingredient follows it into the recipes', (
      tester,
    ) async {
      final store = await pumpInventory(tester, fixtureCollection);
      await chooseOnRow(tester, 'gin', 'Edit');
      // Its own name is not a duplicate of itself.
      expect(saveEnabled(tester), isTrue);
      await type(tester, 'sloe gin');
      await tap(tester, find.text('Save'));

      expect(rowTexts(tester), ['sloe gin', 'In stock', 'campari', 'Out']);
      expect(
        store.saved?.recipeNamed('Negroni')?.lines.first.ingredients.single,
        'sloe gin',
      );
      // One entry, one save: a rename must not spend two backup rotations.
      expect(store.saveCount, 1);
    });

    testWidgets('an ingredient a recipe uses will not go', (tester) async {
      final store = await pumpInventory(tester, fixtureCollection);
      await chooseOnRow(tester, 'gin', 'Delete');

      expect(find.text('Cannot delete "gin"'), findsOneWidget);
      expect(find.text('• Negroni'), findsOneWidget);
      await tap(tester, find.text('Close'));
      expect(rowTexts(tester), ['gin', 'In stock', 'campari', 'Out']);
      expect(store.saveCount, 0);
    });

    testWidgets('an ingredient no recipe uses goes once confirmed', (
      tester,
    ) async {
      final store = await pumpInventory(
        tester,
        fixtureCollection.withIngredient(Ingredient('absinthe')),
      );
      await chooseOnRow(tester, 'absinthe', 'Delete');

      expect(find.text('Delete "absinthe"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(rowTexts(tester), ['gin', 'In stock', 'campari', 'Out']);
      expect(store.saved?.ingredientNamed('absinthe'), isNull);
    });
  });

  group('aliases (ADR 10)', () {
    /// One bottle answering to two spellings besides its own.
    final aliasedCollection = fixtureCollection.withIngredient(
      Ingredient(
        'gin',
        stock: StockLevel.in_,
        aliases: const ['jenever', 'london dry'],
      ),
    );

    testWidgets('a search finds the bottle under any of its spellings', (
      tester,
    ) async {
      await pumpInventory(tester, aliasedCollection);
      for (final query in ['jenever', 'LONDON', 'gin']) {
        await search(tester, query);
        expect(rowTexts(tester), ['gin', 'In stock'], reason: query);
      }
    });

    testWidgets('and the row it finds still reads under its own name', (
      tester,
    ) async {
      await pumpInventory(tester, aliasedCollection);
      await search(tester, 'jenever');
      // Aliases are for finding, not for showing: only the search box holds
      // the word that found the row.
      expect(rowTexts(tester), ['gin', 'In stock']);
    });

    testWidgets('a new bottle can be born answering to more than one', (
      tester,
    ) async {
      final store = await pumpInventory(tester, fixtureCollection);
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'bourbon');
      await typeAliases(tester, 'bourbon whiskey, bourbon whisky');
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientNamed('bourbon whisky')?.name, 'bourbon');
      expect(store.saved?.ingredientNamed('bourbon')?.aliases, const [
        'bourbon whiskey',
        'bourbon whisky',
      ]);
    });

    testWidgets('an edit settles the name and the spellings at once', (
      tester,
    ) async {
      final store = await pumpInventory(tester, aliasedCollection);
      await chooseOnRow(tester, 'gin', 'Edit');
      expect(find.text('jenever, london dry'), findsOneWidget);
      await type(tester, 'sloe gin');
      await typeAliases(tester, 'jenever');
      await tap(tester, find.text('Save'));

      expect(store.saved?.ingredientNamed('gin'), isNull);
      expect(store.saved?.ingredientNamed('jenever')?.name, 'sloe gin');
      // One entry, one save: the rename carries the whole bottle with it.
      expect(store.saveCount, 1);
    });

    testWidgets('a bottle does not collide with its own spellings', (
      tester,
    ) async {
      await pumpInventory(tester, aliasedCollection);
      await chooseOnRow(tester, 'gin', 'Edit');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('but it does collide with another bottle spelling', (
      tester,
    ) async {
      await pumpInventory(tester, aliasedCollection);
      await chooseOnRow(tester, 'campari', 'Edit');
      await typeAliases(tester, 'london dry');
      expect(
        find.text('Duplicate ingredient name: "london dry"'),
        findsOneWidget,
      );
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a recipe naming one blocks the delete it names', (
      tester,
    ) async {
      await pumpInventory(
        tester,
        aliasedCollection.copyWith(
          recipes: [
            Recipe(
              'Gin Fizz',
              lines: const [
                RecipeLine(Amount(2), 'part', ['jenever']),
              ],
            ),
          ],
        ),
      );
      await chooseOnRow(tester, 'gin', 'Delete');
      expect(find.text('Cannot delete "gin"'), findsOneWidget);
      expect(find.text('• Gin Fizz'), findsOneWidget);
    });
  });

  group('inventory order', () {
    testWidgets('the orders keep out of sight until they are asked for', (
      tester,
    ) async {
      await pumpInventory(tester, fixtureCollection);
      expect(find.byType(FilterChip), findsNothing);

      await openSort(tester);
      expect(find.widgetWithText(FilterChip, 'Stock'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Name'), findsOneWidget);

      // Put away, the order they settled still stands.
      await openSort(tester);
      expect(find.byType(FilterChip), findsNothing);
      expect(namesOn(tester), ['gin', 'campari']);
    });

    testWidgets('it opens on stock, the full bottles first', (tester) async {
      await pumpInventory(tester, orderedCollection);
      await openSort(tester);
      expect(sortedBy(tester), ('Stock', false));
      expect(namesOn(tester), ['gin', 'absinthe', 'campari']);
    });

    testWidgets('name reads them A→Z whatever is left in them', (tester) async {
      await pumpInventory(tester, orderedCollection);
      await sortBy(tester, 'Name');
      expect(namesOn(tester), ['absinthe', 'campari', 'gin']);
    });

    testWidgets('picking the order in force turns the whole list round', (
      tester,
    ) async {
      await pumpInventory(tester, orderedCollection);
      await sortBy(tester, 'Stock');
      expect(sortedBy(tester), ('Stock', true));
      // The A→Z between the two empty ones turns round with everything else.
      expect(namesOn(tester), ['campari', 'absinthe', 'gin']);
    });

    testWidgets('another order starts the way round it is written', (
      tester,
    ) async {
      await pumpInventory(tester, orderedCollection);
      await sortBy(tester, 'Stock');
      await sortBy(tester, 'Name');
      expect(sortedBy(tester), ('Name', false));
      expect(namesOn(tester), ['absinthe', 'campari', 'gin']);
    });

    testWidgets('a bottle stays put while the taps empty it', (tester) async {
      await pumpInventory(tester, orderedCollection);
      // gin leads on stock; emptying it would send it past both were the list
      // to re-place itself under the finger doing it (FR-INV-2).
      await tap(tester, find.text('gin'));
      await tap(tester, find.text('gin'));
      expect(namesOn(tester), ['gin', 'absinthe', 'campari']);
    });

    testWidgets('the rows fall back into order once the list changes', (
      tester,
    ) async {
      await pumpInventory(tester, orderedCollection);
      await tap(tester, find.text('gin'));
      await tap(tester, find.text('gin'));

      // Narrowing changes the rows on show, so the search re-places them —
      // and clearing it places gin where it now belongs, among the empties.
      await search(tester, 'a');
      expect(namesOn(tester), ['absinthe', 'campari']);
      await search(tester, '');
      expect(namesOn(tester), ['absinthe', 'campari', 'gin']);
    });

    testWidgets('the orders open under the search, above the legend', (
      tester,
    ) async {
      await pumpInventory(tester);
      await openSort(tester);
      final orders = tester.getTopLeft(find.byType(FilterChip).first).dy;
      expect(orders, greaterThan(tester.getBottomLeft(searchBox).dy));
      expect(orders, lessThan(tester.getTopLeft(find.byType(TagChoices)).dy));
    });

    testWidgets('reading a list another way writes nothing', (tester) async {
      final store = await pumpInventory(tester, orderedCollection);
      await sortBy(tester, 'Name');
      await sortBy(tester, 'Name');
      expect(store.saveCount, 0);
    });
  });

  group('inventory tags', () {
    testWidgets('a bottle wears a dot per tag, in vocabulary order', (
      tester,
    ) async {
      await pumpInventory(tester);
      expect(dotsOn(tester, 'gin'), isEmpty);
      expect(dotsOn(tester, 'lemon juice'), ['citrus']);
      expect(dotsOn(tester, 'orgeat'), ['homemade', 'syrup']);
    });

    testWidgets('a dot wears the colour its chip wears in the legend', (
      tester,
    ) async {
      await pumpInventory(tester);
      final sand = tagColors(TagColor.sand, Brightness.light);
      expect(dotColor(tester, 'lemon juice'), sand.fill);
      expect(chipColor(tester, 'citrus'), sand.fill);
    });

    testWidgets('the legend scrolls sideways instead of growing downward', (
      tester,
    ) async {
      await pumpInventory(tester);
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
      await pumpInventory(tester, fixtureCollection);
      expect(find.byType(TagChoices), findsNothing);

      await pumpInventory(tester);
      expect(find.byType(TagChoices), findsOneWidget);
      expect(find.widgetWithText(ColorChip, 'homemade'), findsOneWidget);
    });

    testWidgets('picking a tag keeps the bottles wearing it', (tester) async {
      await pumpInventory(tester);
      await pickTag(tester, 'syrup');
      expect(isPicked(tester, 'syrup'), isTrue);
      expect(namesOn(tester), ['orgeat', 'sugar syrup']);
    });

    testWidgets('picking a second one keeps only what wears both', (
      tester,
    ) async {
      await pumpInventory(tester);
      await pickTag(tester, 'syrup');
      await pickTag(tester, 'homemade');
      expect(namesOn(tester), ['orgeat']);
    });

    testWidgets('picking a lit tag again lets the rest back in', (
      tester,
    ) async {
      await pumpInventory(tester);
      await pickTag(tester, 'citrus');
      expect(namesOn(tester), ['lemon juice']);
      await pickTag(tester, 'citrus');
      expect(isPicked(tester, 'citrus'), isFalse);
      expect(namesOn(tester), ['gin', 'lemon juice', 'orgeat', 'sugar syrup']);
    });

    testWidgets('the tags and the search narrow together', (tester) async {
      await pumpInventory(tester);
      await pickTag(tester, 'syrup');
      await search(tester, 'sugar');
      expect(namesOn(tester), ['sugar syrup']);
    });

    testWidgets('an empty list blames the tags when the tags emptied it', (
      tester,
    ) async {
      await pumpInventory(tester);
      await pickTag(tester, 'citrus');
      await pickTag(tester, 'syrup');
      expect(
        find.text('No ingredient here matches every tag you picked.'),
        findsOneWidget,
      );
      expect(find.textContaining('Add "'), findsNothing);
    });

    testWidgets('and blames both when both narrowed it', (tester) async {
      await pumpInventory(tester);
      await pickTag(tester, 'citrus');
      await search(tester, 'gin');
      expect(
        find.text(
          'No ingredient here answers to "gin" and matches every tag you '
          'picked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a tag renamed elsewhere stops filtering', (tester) async {
      await pumpInventory(tester);
      await pickTag(tester, 'syrup');
      expect(namesOn(tester), ['orgeat', 'sugar syrup']);

      await ProviderScope.containerOf(
            tester.element(find.byType(InventoryScreen)),
            listen: false,
          )
          .read(barWriterProvider)!
          .upsertTag(
            TagKind.ingredient,
            const Tag('sirop', color: TagColor.teal),
            replacing: 'syrup',
          );
      await tester.pumpAndSettle();

      expect(isPicked(tester, 'sirop'), isFalse);
      expect(namesOn(tester), ['gin', 'lemon juice', 'orgeat', 'sugar syrup']);
    });

    testWidgets('an add clears the picked tags along with the search', (
      tester,
    ) async {
      await pumpInventory(tester);
      await pickTag(tester, 'citrus');
      await tap(tester, find.byTooltip('Add ingredient'));
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));
      expect(namesOn(tester), [
        'gin',
        'absinthe',
        'lemon juice',
        'orgeat',
        'sugar syrup',
      ]);
    });

    testWidgets('a new bottle can be born tagged', (tester) async {
      final store = await pumpInventory(tester);
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
      final store = await pumpInventory(tester);
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
