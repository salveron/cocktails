import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/shopping_screen.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:cocktails/ui/widgets/tag_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

RecipeLine _line(String ingredient) =>
    RecipeLine(const Amount(1), 'part', [ingredient]);

Recipe _recipe(String name, List<String> ingredients) =>
    Recipe(name, lines: [for (final one in ingredients) _line(one)]);

Recipe _tagged(String name, String ingredient, List<String> tags) =>
    Recipe(name, tags: tags, lines: [_line(ingredient)]);

/// A shelf short in both ways at once: three bottles there are none of, and one
/// running low. Every budget answers, and each answers differently — and the
/// switch moves the one-bottle answer off the missing bottle onto the low one,
/// rather than merely lengthening the list.
final shoppingCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('lime juice', stock: StockLevel.low),
    Ingredient('campari'),
    Ingredient('sweet vermouth'),
    Ingredient('white rum'),
  ],
  recipes: [
    _recipe('Negroni', ['gin', 'campari', 'sweet vermouth']),
    _recipe('Americano', ['campari', 'sweet vermouth']),
    _recipe('Gimlet', ['gin', 'lime juice']),
    _recipe('Daiquiri', ['white rum', 'lime juice']),
  ],
);

/// Two recipes short of the same pair, so no single bottle answers and the
/// two-bottle basket does.
final pairedCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
    Ingredient('sweet vermouth'),
  ],
  recipes: [
    _recipe('Negroni', ['gin', 'campari', 'sweet vermouth']),
    _recipe('Americano', ['campari', 'sweet vermouth']),
  ],
);

/// Three recipes short of a bottle each, so three baskets tie at one recipe
/// apiece and the list has ranks to read.
final spreadCollection = Collection(
  ingredients: [
    Ingredient('white rum'),
    Ingredient('vodka'),
    Ingredient('tequila'),
  ],
  recipes: [
    _recipe('Rum Neat', ['white rum']),
    _recipe('Vodka Neat', ['vodka']),
    _recipe('Tequila Neat', ['tequila']),
  ],
);

/// The spread shelf with categories over it: one basket per bottle at a budget
/// of one, every pair of them at two, so a pick can be read against the ranks
/// it did not touch. No recipe wears both `clean` and `tiki`, so only a basket
/// bringing two of them answers to the pair; `sour` is worn by nothing, so the
/// chips alone can empty every size; and `long` rides on a recipe beside `tiki`,
/// so a dot can be told from every tag a recipe happens to wear.
final taggedCollection = Collection(
  ingredients: [
    Ingredient('white rum'),
    Ingredient('vodka'),
    Ingredient('tequila'),
  ],
  recipeTags: const [
    Tag('clean', color: TagColor.sand),
    Tag('long', color: TagColor.indigo),
    Tag('sour', color: TagColor.rose),
    Tag('tiki', color: TagColor.teal),
  ],
  recipes: [
    _tagged('Rum Neat', 'white rum', const ['tiki', 'long']),
    _tagged('Vodka Neat', 'vodka', const ['clean']),
    _tagged('Tequila Neat', 'tequila', const ['clean']),
  ],
);

/// Every basket on show, by the rank it reads under.
Iterable<String> cartsOn(WidgetTester tester) => tester
    .widgetList<Text>(find.textContaining('Shopping Cart #'))
    .map((text) => text.data!);

/// The tags [name] is marked with on the open card, told apart from every other
/// bullet on it by the row that name is bulleted on.
Iterable<String> dotsBeside(WidgetTester tester, String name) => tester
    .widgetList<TagDot>(
      find.descendant(
        of: find
            .ancestor(of: find.text('• $name'), matching: find.byType(Row))
            .first,
        matching: find.byType(TagDot),
      ),
    )
    .map((dot) => dot.tag.name);

Future<MemoryModelStore> pumpShopping(
  WidgetTester tester, [
  Collection? collection,
]) => pumpOver(
  tester,
  const ShoppingScreen(showing: true),
  collection ?? shoppingCollection,
);

Future<void> pickBudget(WidgetTester tester, int budget) =>
    tap(tester, find.text('$budget'));

Future<void> toggleLow(WidgetTester tester) => tap(tester, find.byType(Switch));

Future<void> openCard(WidgetTester tester, [int rank = 1]) =>
    tap(tester, find.text('Shopping Cart #$rank'));

/// Every bottle named on the open card, told apart from the recipes beside them
/// by the dot each carries.
Iterable<String> bottlesOnCard(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.ancestor(
          of: find.byType(StockDot),
          matching: find.byType(Row),
        ),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data!);

void main() {
  group('shopping screen', () {
    testWidgets('opens on the single bottles worth buying', (tester) async {
      await pumpShopping(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'white rum', '1 recipe']);
    });

    testWidgets('a wider budget answers with a basket of exactly that many', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 2);
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth',
        '2 recipes',
      ]);
      await pickBudget(tester, 3);
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth + white rum',
        '3 recipes',
      ]);
    });

    testWidgets('the switch moves what counts as short (FR-DIS-7)', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'lime juice', '1 recipe']);
    });

    testWidgets('baskets are numbered by where they rank', (tester) async {
      await pumpShopping(tester, spreadCollection);
      expect(rowTexts(tester).where((text) => text!.startsWith('Shopping')), [
        'Shopping Cart #1',
        'Shopping Cart #2',
        'Shopping Cart #3',
      ]);
    });

    testWidgets('a card opens onto its bottles and every recipe', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 3);
      await openCard(tester);
      expect(bottlesOnCard(tester), [
        '• campari',
        '• sweet vermouth',
        '• white rum',
      ]);
      for (final recipe in ['• Americano', '• Daiquiri', '• Negroni']) {
        expect(find.text(recipe), findsOneWidget);
      }
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Unlocks'), findsOneWidget);
      expect(
        find.text('campari + sweet vermouth + white rum'),
        findsNothing,
        reason: 'the bottles read in the body rather than twice over',
      );
    });

    testWidgets('an open card is remembered by its bottles, not its rank', (
      tester,
    ) async {
      await pumpShopping(tester);
      await pickBudget(tester, 2);
      await openCard(tester);
      await pickBudget(tester, 3);
      expect(
        find.text('Ingredients'),
        findsNothing,
        reason: '#1 is another basket now, and it was never opened',
      );
      await pickBudget(tester, 2);
      expect(
        find.text('Ingredients'),
        findsOneWidget,
        reason: 'the basket that was opened is still open where it stands',
      );
    });

    testWidgets('an open card reads each bottle at the level it stands at', (
      tester,
    ) async {
      await pumpShopping(tester);
      await toggleLow(tester);
      await pickBudget(tester, 2);
      // By its bottles rather than its rank: this is the one basket of the
      // several at this size that holds both readings of short.
      await tap(tester, find.text('lime juice + white rum'));
      expect(
        tester.widgetList<StockDot>(find.byType(StockDot)).map((d) => d.stock),
        [StockLevel.low, StockLevel.out],
        reason:
            'restocking mixes a bottle running low with one there is none of',
      );
    });

    testWidgets('nothing at this size offers the size that answers', (
      tester,
    ) async {
      await pumpShopping(tester, pairedCollection);
      expect(find.text('Nothing worth buying in 1'), findsOneWidget);
      await tap(tester, find.text('Try 2 bottles'));
      expect(rowTexts(tester), [
        'Shopping Cart #1',
        'campari + sweet vermouth',
        '2 recipes',
      ]);
    });

    testWidgets('nothing short says which reading it is short by', (
      tester,
    ) async {
      await pumpShopping(
        tester,
        Collection(
          ingredients: [Ingredient('gin', stock: StockLevel.low)],
          recipes: [
            _recipe('Gin Shot', ['gin']),
          ],
        ),
      );
      expect(
        find.text(
          'Every recipe you have can be made from what is on the shelf.',
        ),
        findsOneWidget,
      );
      await toggleLow(tester);
      expect(rowTexts(tester), ['Shopping Cart #1', 'gin', '1 recipe']);
    });

    testWidgets('says what would put baskets there while it is empty', (
      tester,
    ) async {
      await pumpShopping(tester, Collection());
      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('searches only while it is the destination on show', (
      tester,
    ) async {
      await pumpApp(tester, store: MemoryModelStore(shoppingCollection));
      expect(find.text('Buy'), findsNothing);
      await tap(tester, find.text('Shopping'));
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('white rum'), findsOneWidget);
      await tap(tester, find.text('Recipes'));
      expect(
        find.text('Buy'),
        findsNothing,
        reason: 'the answer is let go along with the screen that asked for it',
      );
    });

    testWidgets('both controls stand on the one row on a phone', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShopping(tester);
      expect(
        tester.getCenter(find.text('Buy')).dy,
        tester.getCenter(find.text('Low too')).dy,
      );
    });

    testWidgets('and fall to two rows rather than off the edge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShopping(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.text('Buy')).dy,
        lessThan(tester.getCenter(find.text('Low too')).dy),
      );
    });
  });

  group('the tags narrow the baskets (FR-DIS-10)', () {
    testWidgets('a collection with no recipe tags draws no row', (
      tester,
    ) async {
      await pumpShopping(tester);
      expect(find.byType(TagChoices), findsNothing);
    });

    testWidgets('the chips stand between the controls and the list', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      final chips = tester.getCenter(find.byType(TagChoices)).dy;
      expect(chips, greaterThan(tester.getCenter(find.text('Buy')).dy));
      expect(
        chips,
        lessThan(tester.getCenter(find.text('Shopping Cart #1')).dy),
      );
    });

    testWidgets('a pick keeps the baskets bringing a recipe wearing it', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      expect(isPicked(tester, 'tiki'), isTrue);
      expect(rowTexts(tester), ['Shopping Cart #3', 'white rum', '1 recipe']);
    });

    testWidgets('the ranks are those the unnarrowed list gave', (tester) async {
      await pumpShopping(tester, taggedCollection);
      expect(cartsOn(tester), [
        'Shopping Cart #1',
        'Shopping Cart #2',
        'Shopping Cart #3',
      ]);
      await pickTag(tester, 'clean');
      expect(
        cartsOn(tester),
        ['Shopping Cart #1', 'Shopping Cart #2'],
        reason: 'the numbering is the ranking, so what is kept keeps its own',
      );
    });

    testWidgets('two picks reach a basket bringing one of each', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      await pickBudget(tester, 2);
      await pickTag(tester, 'tiki');
      await pickTag(tester, 'clean');
      expect(
        cartsOn(tester),
        ['Shopping Cart #2', 'Shopping Cart #3'],
        reason: 'no recipe here wears both, so the pair is answered across two',
      );
      expect(find.text('tequila + white rum'), findsOneWidget);
      expect(find.text('vodka + white rum'), findsOneWidget);
    });

    testWidgets('picking a lit tag again lets the rest back in', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      expect(cartsOn(tester), ['Shopping Cart #3']);
      await pickTag(tester, 'tiki');
      expect(isPicked(tester, 'tiki'), isFalse);
      expect(cartsOn(tester), hasLength(3));
    });

    testWidgets('an empty screen blames the picks and offers the size that '
        'answers under them', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      await pickTag(tester, 'clean');
      expect(
        find.text(
          'No single bottle here unlocks a recipe matching every tag you '
          'picked.',
        ),
        findsOneWidget,
        reason: 'the size is not what emptied it',
      );
      await tap(tester, find.text('Try 2 bottles'));
      expect(cartsOn(tester), ['Shopping Cart #2', 'Shopping Cart #3']);
    });

    testWidgets('a pick nothing answers offers nowhere to go', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'sour');
      expect(
        find.text(
          'No single bottle here unlocks a recipe matching every tag you '
          'picked.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Try '),
        findsNothing,
        reason: 'no size answers, so there is no size to offer',
      );
    });

    testWidgets('an unnarrowed screen still blames the size', (tester) async {
      await pumpShopping(tester, pairedCollection);
      expect(
        find.text('No single bottle unlocks a recipe on its own here.'),
        findsOneWidget,
      );
    });
  });

  group('an open basket marks the picks it answered (FR-DIS-10)', () {
    testWidgets('the recipe wearing the pick carries its dot', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      await openCard(tester, 3);
      expect(dotsBeside(tester, 'Rum Neat'), ['tiki']);
    });

    testWidgets('a tag the recipe wears but nobody picked draws none', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      await openCard(tester, 3);
      expect(
        dotsBeside(tester, 'Rum Neat'),
        isNot(contains('long')),
        reason: 'a dot answers which pick reached the basket, nothing else',
      );
    });

    testWidgets('two picks on one recipe read in vocabulary order', (
      tester,
    ) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      await pickTag(tester, 'long');
      await openCard(tester, 3);
      expect(dotsBeside(tester, 'Rum Neat'), ['long', 'tiki']);
    });

    testWidgets('a recipe that rode along wears nothing', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await pickBudget(tester, 2);
      await pickTag(tester, 'tiki');
      // The basket of tequila and white rum: Rum Neat is what the pick
      // reached, and Tequila Neat came with it.
      await openCard(tester, 2);
      expect(dotsBeside(tester, 'Rum Neat'), ['tiki']);
      expect(dotsBeside(tester, 'Tequila Neat'), isEmpty);
    });

    testWidgets('nothing picked leaves every recipe bare', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await openCard(tester, 3);
      expect(find.text('• Rum Neat'), findsOneWidget);
      expect(
        dotsBeside(tester, 'Rum Neat'),
        isEmpty,
        reason: 'there is no pick for a dot to stand for',
      );
    });

    testWidgets('the bottles beside them keep their own dots', (tester) async {
      await pumpShopping(tester, taggedCollection);
      await pickTag(tester, 'tiki');
      await openCard(tester, 3);
      expect(
        tester.widgetList<StockDot>(find.byType(StockDot)).map((d) => d.stock),
        [StockLevel.out],
        reason: 'the stock dot is a reading of its own, and is untouched',
      );
    });
  });
}
