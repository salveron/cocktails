import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:cocktails/ui/widgets/tag_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

const names = ['Daiquiri', 'Negroni', 'Whiskey Sour'];

/// The day the screen's clock is stopped on, so a stamp reads back exactly.
final today = DateTime(2026, 7, 30);

Future<MemoryModelStore> pumpRecipes(WidgetTester tester, [Model? model]) =>
    pumpOver(tester, const RecipesScreen(), model ?? recipeModel, today: today);

/// The recipe names on screen, in list order — [roster] naming which model's,
/// so a summary line is never mistaken for a row.
Iterable<String?> namesOn(WidgetTester tester, [List<String> roster = names]) =>
    rowTexts(tester).where(roster.contains);

/// The three verdicts at once (FR-DIS-1), and an optional line the verdict
/// passes over though the card still marks it. Its A→Z runs against its
/// availability, so the two orders can never be read for each other.
const stocked = ['Campari Shot', 'Gin Shot', 'Negroni'];

final stockedModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari', stock: StockLevel.low),
    Ingredient('sweet vermouth'),
  ],
  recipes: [
    Recipe(
      'Gin Shot',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
        RecipeLine(Amount(1), 'dash', [
          'sweet vermouth',
        ], mark: LineMark.optional),
      ],
    ),
    Recipe(
      'Campari Shot',
      lines: const [
        RecipeLine(Amount(1), 'part', ['campari']),
      ],
    ),
    Recipe(
      'Negroni',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
        RecipeLine(Amount(1), 'part', ['campari']),
        RecipeLine(Amount(1), 'part', ['sweet vermouth']),
      ],
    ),
  ],
);

/// A tag nothing wears, so the chips alone can empty the list.
final untriedModel = recipeModel.withTag(
  TagKind.recipe,
  const Tag('tiki', color: TagColor.teal),
);

/// A bottle answering to a second name, so a search can reach a recipe by a
/// spelling no line of it holds (FR-VOC-6).
final aliasedModel = recipeModel.withIngredient(
  Ingredient('gin', aliases: const ['juniper']),
  replacing: 'gin',
);

/// What the verdict chip on the row named [name] reads.
String verdictOn(WidgetTester tester, String name) => tester
    .widget<Text>(
      find.descendant(
        of: find.descendant(
          of: find.ancestor(
            of: find.text(name),
            matching: find.byType(ListTile),
          ),
          matching: find.byType(AvailabilityChip),
        ),
        matching: find.byType(Text),
      ),
    )
    .data!;

/// Two recipes of nothing but groups: one line for each way a group can read
/// — a bottle on hand, only a low one, nothing at all — and one carrying a
/// mark, so the mark is seen to govern the group rather than a bottle of it.
final substitutedModel = Model(
  ingredients: [
    Ingredient('campari', stock: StockLevel.low),
    Ingredient('cognac'),
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('sweet vermouth'),
    Ingredient('vodka', stock: StockLevel.in_),
  ],
  recipes: [
    Recipe(
      'Sidecar',
      lines: const [
        RecipeLine(Amount(1), 'part', ['cognac', 'vodka']),
        RecipeLine(Amount(1), 'part', ['cognac', 'campari']),
        RecipeLine(Amount(1), 'part', ['cognac', 'sweet vermouth']),
      ],
    ),
    Recipe(
      'Gimlet',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin', 'vodka'], mark: LineMark.base),
      ],
    ),
  ],
);

/// The runs the line reading [line] is drawn from — the one place a test
/// reaches into a line's spans, however it means to judge them.
List<TextSpan> runsOn(WidgetTester tester, String line) =>
    (tester.widget<Text>(find.text(line)).textSpan! as TextSpan).children!
        .cast<TextSpan>();

/// The bottles on the line reading [line] drawn in the dimmed ink — the ones a
/// group offers that the bar cannot supply. They are the only runs carrying a
/// colour of their own, so the colour is what tells them apart.
List<String> dimmedOn(WidgetTester tester, String line) => [
  for (final run in runsOn(tester, line))
    if (run.style?.color != null) run.text!,
];

/// The ink those bottles wear; fails the test where the line dims nothing.
Color dimInkOn(WidgetTester tester, String line) => runsOn(
  tester,
  line,
).firstWhere((run) => run.style?.color != null).style!.color!;

/// What the dot beside the line reading [line] reports, or null when that line
/// carries none — which is how an in-stock bottle reads.
StockLevel? dotOnLine(WidgetTester tester, String line) {
  final dots = tester
      .widgetList<StockDot>(
        find.descendant(
          of: find
              .ancestor(of: find.text(line), matching: find.byType(Row))
              .first,
          matching: find.byType(StockDot),
        ),
      )
      .toList();
  return dots.isEmpty ? null : dots.single.stock;
}

/// The runs of the line reading [line] drawn in italics, joined: the "or" of a
/// group, and the measure of a card not reading the amounts as written.
String italicOn(WidgetTester tester, String line) => [
  for (final run in runsOn(tester, line))
    if (run.style?.fontStyle == FontStyle.italic) run.text!,
].join();

/// Settles that card's own dialog on [factor] and [unit], leaving whatever it
/// does not name where the dialog opened it.
Future<void> scale(
  WidgetTester tester,
  String name, {
  int? factor,
  String? unit,
  String button = 'Apply',
}) async {
  await chooseOnRow(tester, name, 'Scale & convert');
  if (factor != null) await tap(tester, find.text('×$factor'));
  if (unit != null) await tap(tester, find.text(unit));
  await tap(tester, find.text(button));
}

final madeButton = find.widgetWithText(FilledButton, 'Made it');
final undoButton = find.widgetWithText(TextButton, 'Undo');

/// Whatever an open card reports about its history — never the button's own
/// words, which are there whether or not there is a history to report.
final historyLine = find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data != 'Made it' &&
      (widget.data?.startsWith('Made ') ?? false),
);

void main() {
  group('recipe list', () {
    testWidgets('says what will fill it while it is empty', (tester) async {
      await pumpScreen(tester, const RecipesScreen());
      expect(find.text('No recipes yet'), findsOneWidget);
    });

    testWidgets('reads A to Z where nothing tells them apart', (tester) async {
      // Every bottle is out, so every verdict is the same and the tie-break
      // is the whole order, whatever order the file keeps.
      await pumpRecipes(tester);
      expect(namesOn(tester), names);
    });

    testWidgets('the search narrows by name', (tester) async {
      await pumpRecipes(tester);
      await search(tester, 'daiq');
      expect(namesOn(tester), ['Daiquiri']);
    });

    testWidgets('offers add, edit and delete since the form landed', (
      tester,
    ) async {
      await pumpRecipes(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(rowMenu('Negroni'), findsOneWidget);
      await search(tester, 'Mai Tai');
      expect(find.text('No recipe here answers to "Mai Tai".'), findsOneWidget);
      expect(find.text('Add "Mai Tai"'), findsOneWidget);
    });

    testWidgets('delete asks once and is never blocked', (tester) async {
      final store = await pumpRecipes(tester);
      await chooseOnRow(tester, 'Negroni', 'Delete');
      expect(find.text('Delete "Negroni"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(find.text('Negroni'), findsNothing);
      expect(store.saved!.recipeNamed('Negroni'), isNull);
    });

    testWidgets('the menu is there on an expanded card too', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('Stir over ice.'), findsOneWidget);
      expect(rowMenu('Negroni'), findsOneWidget);
    });

    testWidgets('a renamed card stays open under its new name', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await typeInto(tester, nameField, 'Boulevardier');
      await tap(tester, find.text('Save'));
      expect(find.text('Boulevardier'), findsOneWidget);
      // The card it opened is still the card it opens: the notes are showing.
      expect(find.text('Stir over ice.'), findsOneWidget);
    });
  });

  group('recipe order', () {
    testWidgets('it opens on availability, what is ready first', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await openSort(tester);
      expect(sortedBy(tester), ('Availability', false));
      expect(namesOn(tester, stocked), ['Gin Shot', 'Campari Shot', 'Negroni']);
    });

    testWidgets('name puts them back A→Z', (tester) async {
      await pumpRecipes(tester, stockedModel);
      await sortBy(tester, 'Name');
      expect(namesOn(tester, stocked), stocked);
    });

    testWidgets('turned round, what is missing leads', (tester) async {
      await pumpRecipes(tester, stockedModel);
      await sortBy(tester, 'Availability');
      expect(namesOn(tester, stocked), ['Negroni', 'Campari Shot', 'Gin Shot']);
    });
  });

  group('recipe filters', () {
    testWidgets('the chips are the vocabulary, and absent without one', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      expect(find.byType(TagChoices), findsNothing);

      await pumpRecipes(tester);
      expect(find.byType(TagChoices), findsOneWidget);
      expect(find.widgetWithText(ColorChip, 'sour'), findsOneWidget);
    });

    testWidgets('picking a tag keeps the recipes wearing it', (tester) async {
      await pumpRecipes(tester);
      await pickTag(tester, 'classic');
      expect(isPicked(tester, 'classic'), isTrue);
      expect(namesOn(tester), ['Negroni', 'Whiskey Sour']);
    });

    testWidgets('picking a second one keeps only what wears both', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await pickTag(tester, 'classic');
      await pickTag(tester, 'sour');
      expect(namesOn(tester), ['Whiskey Sour']);
    });

    testWidgets('picking a lit tag again lets the rest back in', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await pickTag(tester, 'sour');
      expect(namesOn(tester), ['Whiskey Sour']);
      await pickTag(tester, 'sour');
      expect(isPicked(tester, 'sour'), isFalse);
      expect(namesOn(tester), names);
    });

    testWidgets('the tags and the search narrow together', (tester) async {
      await pumpRecipes(tester);
      await pickTag(tester, 'classic');
      await search(tester, 'negro');
      expect(namesOn(tester), ['Negroni']);
    });

    testWidgets('an empty list blames the tags when they emptied it', (
      tester,
    ) async {
      await pumpRecipes(tester, untriedModel);
      await pickTag(tester, 'tiki');
      expect(
        find.text('No recipe here matches every tag you picked.'),
        findsOneWidget,
      );
    });

    testWidgets('an add lets the picked tags go along with the search', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await pickTag(tester, 'sour');
      expect(namesOn(tester), ['Whiskey Sour']);

      await tap(tester, find.byTooltip('Add recipe'));
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '2 parts gin');
      await tap(tester, find.text('Save'));
      expect(namesOn(tester, [...names, 'Martini']), [
        'Daiquiri',
        'Martini',
        'Negroni',
        'Whiskey Sour',
      ]);
    });
  });

  group('recipe search', () {
    testWidgets('a bottle finds the recipes built on it (FR-DIS-2)', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await search(tester, 'rum');
      expect(namesOn(tester), ['Daiquiri']);
    });

    testWidgets('and finds every one of them at once', (tester) async {
      await pumpRecipes(tester);
      await search(tester, 'juice');
      expect(namesOn(tester), ['Daiquiri', 'Whiskey Sour']);
    });

    testWidgets('a bottle answers under its other names too', (tester) async {
      await pumpRecipes(tester, aliasedModel);
      await search(tester, 'juniper');
      expect(namesOn(tester), ['Negroni']);
    });
  });

  group('substitution groups (ADR 11)', () {
    testWidgets('a card reads the group as prose, not as the file', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(find.text('1 part cognac or vodka'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('the bottle the bar cannot supply dims, the other stands', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(dimmedOn(tester, '1 part cognac or vodka'), ['cognac']);
    });

    testWidgets('it dims as far as an unfilled field\'s hint does', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      final theme = Theme.of(tester.element(find.text('Sidecar')));
      expect(
        dimInkOn(tester, '1 part cognac or vodka'),
        theme.inputDecorationTheme.hintStyle!.color,
      );
    });

    testWidgets('the "or" carrying the group is italic, and it alone', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(italicOn(tester, '1 part cognac or vodka'), ' or ');
    });

    testWidgets('one bottle on hand leaves the line undotted', (tester) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(dotOnLine(tester, '1 part cognac or vodka'), isNull);
    });

    testWidgets('the dot reports the best the group can do', (tester) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(dotOnLine(tester, '1 part cognac or campari'), StockLevel.low);
      expect(dimmedOn(tester, '1 part cognac or campari'), ['cognac']);
    });

    testWidgets('a group short of everything dims nothing and says so', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Sidecar'));
      expect(dimmedOn(tester, '1 part cognac or sweet vermouth'), isEmpty);
      expect(
        dotOnLine(tester, '1 part cognac or sweet vermouth'),
        StockLevel.out,
      );
    });

    testWidgets('the mark governs the group, not a bottle of it', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Gimlet'));
      expect(find.text('1 part gin or vodka (base)'), findsOneWidget);
      expect(dimmedOn(tester, '1 part gin or vodka (base)'), isEmpty);
    });

    testWidgets('one bottle on hand makes the recipe (FR-DIS-1)', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      expect(verdictOn(tester, 'Gimlet'), 'Ready');
      expect(verdictOn(tester, 'Sidecar'), 'Missing');
    });

    testWidgets('the shut card sums the group as prose too', (tester) async {
      await pumpRecipes(tester, substitutedModel);
      expect(
        find.text(
          'cognac or vodka · cognac or campari · cognac or sweet vermouth',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a search reaches a recipe by any bottle of a group', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await search(tester, 'campari');
      expect(namesOn(tester, const ['Gimlet', 'Sidecar']), ['Sidecar']);
      await search(tester, 'vodka');
      expect(namesOn(tester, const ['Gimlet', 'Sidecar']), [
        'Gimlet',
        'Sidecar',
      ]);
    });
  });

  group('compact card', () {
    testWidgets('sums the build up without the amounts', (tester) async {
      await pumpRecipes(tester);
      expect(find.text('gin · campari · sweet vermouth'), findsOneWidget);
      expect(find.textContaining('1 part'), findsNothing);
    });

    testWidgets('the optional ingredient is listed undistinguished', (
      tester,
    ) async {
      await pumpRecipes(tester);
      expect(
        find.text('bourbon · lemon juice · sugar syrup · egg white'),
        findsOneWidget,
      );
    });

    testWidgets('wears its tags as dots in vocabulary order', (tester) async {
      await pumpRecipes(tester);
      expect(dotsOn(tester, 'Whiskey Sour'), ['classic', 'sour']);
      expect(dotsOn(tester, 'Daiquiri'), isEmpty);
    });

    testWidgets('wears the verdict of its own bottles (FR-DIS-1)', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      expect(verdictOn(tester, 'Gin Shot'), 'Ready');
      expect(verdictOn(tester, 'Campari Shot'), 'Low');
      expect(verdictOn(tester, 'Negroni'), 'Missing');
    });

    testWidgets('the verdict stays put while the card is open', (tester) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Negroni'));
      expect(verdictOn(tester, 'Negroni'), 'Missing');
    });
  });

  group('full card', () {
    testWidgets('a tap opens the lines as the file writes them', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part gin (base)'), findsOneWidget);
      expect(find.text('1 part campari'), findsOneWidget);
      expect(find.text('1 part sweet vermouth'), findsOneWidget);
    });

    testWidgets('marks and ranges keep their own words', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(find.text('2 parts bourbon (base)'), findsOneWidget);
      expect(find.text('1 piece egg white (optional)'), findsOneWidget);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('1.5-2 parts white rum (base)'), findsOneWidget);
    });

    testWidgets('the summaries give way to the real thing', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('gin · campari · sweet vermouth'), findsNothing);
      expect(dotsOn(tester, 'Negroni'), isEmpty);
      expect(onCard('classic'), findsOneWidget);
    });

    testWidgets('only the lines with something to report are dotted', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Negroni'));
      expect(dotOnLine(tester, '1 part gin'), isNull);
      expect(dotOnLine(tester, '1 part campari'), StockLevel.low);
      expect(dotOnLine(tester, '1 part sweet vermouth'), StockLevel.out);
    });

    testWidgets('an optional line is marked though it does not count', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Gin Shot'));
      expect(verdictOn(tester, 'Gin Shot'), 'Ready');
      expect(
        dotOnLine(tester, '1 dash sweet vermouth (optional)'),
        StockLevel.out,
      );
    });

    testWidgets('the chips wear the tags\' own colours', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(onCard('classic'), findsOneWidget);
      expect(onCard('sour'), findsOneWidget);
      expect(chipColor(tester, 'sour'), isNot(chipColor(tester, 'classic')));
    });

    testWidgets('notes and made-history close the card', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(find.text('Stir over ice.'), findsOneWidget);
      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
    });

    testWidgets('made once reads as once', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('Made once · 3 Jan 2026'), findsOneWidget);
    });

    testWidgets('a section with nothing to say is absent', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(historyLine, findsNothing);
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('Stir over ice.'), findsNothing);
    });

    testWidgets('the same tap closes it again', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part campari'), findsNothing);
      expect(find.text('gin · campari · sweet vermouth'), findsOneWidget);
    });

    testWidgets('cards open and close independently', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Daiquiri'));
      expect(find.text('1 part campari'), findsOneWidget);
      expect(find.text('1 part lime juice'), findsOneWidget);
      await tap(tester, find.text('Negroni'));
      expect(find.text('1 part campari'), findsNothing);
      expect(find.text('1 part lime juice'), findsOneWidget);
    });

    testWidgets('an open card stays open through a search', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await search(tester, 'daiq');
      await search(tester, '');
      expect(find.text('1 part campari'), findsOneWidget);
    });
  });

  group('scale & convert', () {
    testWidgets('a closed card has no amounts to read otherwise', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, rowMenu('Negroni'));
      expect(find.text('Scale & convert'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('the factor multiplies every line (FR-REC-7)', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 2);

      expect(find.text('2 parts gin (base)'), findsOneWidget);
      expect(find.text('2 parts campari'), findsOneWidget);
      expect(find.text('2 parts sweet vermouth'), findsOneWidget);
    });

    testWidgets('a range scales at both ends', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Daiquiri'));
      await scale(tester, 'Daiquiri', factor: 3);
      expect(find.text('4.5-6 parts white rum (base)'), findsOneWidget);
    });

    testWidgets('ml converts parts and leaves the rest as entered', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await scale(tester, 'Whiskey Sour', unit: 'ml');

      expect(find.text('60 ml bourbon (base)'), findsOneWidget);
      expect(find.text('22.5 ml sugar syrup'), findsOneWidget);
      expect(find.text('1 piece egg white (optional)'), findsOneWidget);
    });

    testWidgets('the name row says how the card is being read', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 2);
      expect(find.text('(×2)'), findsOneWidget);

      await scale(tester, 'Negroni', unit: 'ml');
      expect(find.text('(×2, ml)'), findsOneWidget);
      expect(find.text('60 ml campari'), findsOneWidget);
    });

    testWidgets('the measure turns italic when it is not the recipe\'s own', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(italicOn(tester, '1 part gin (base)'), isEmpty);

      await scale(tester, 'Negroni', factor: 2);
      expect(italicOn(tester, '2 parts gin (base)'), '2 parts');
    });

    testWidgets('a scaled group italicises both, each saying its own thing', (
      tester,
    ) async {
      await pumpRecipes(tester, substitutedModel);
      await tap(tester, find.text('Gimlet'));
      await scale(tester, 'Gimlet', factor: 2);
      expect(italicOn(tester, '2 parts gin or vodka (base)'), '2 parts or ');
    });

    testWidgets('a low bottle is still marked on a scaled line', (
      tester,
    ) async {
      await pumpRecipes(tester, stockedModel);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 2);
      expect(dotOnLine(tester, '2 parts campari'), StockLevel.low);
    });

    testWidgets('cancelled, the card stands as it was', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 4, button: 'Cancel');

      expect(find.text('1 part gin (base)'), findsOneWidget);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('as written is the way back', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 3, unit: 'ml');
      await scale(tester, 'Negroni', factor: 1, unit: 'part');

      expect(find.text('1 part gin (base)'), findsOneWidget);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('the dialog opens where the card stands', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 2);
      await chooseOnRow(tester, 'Negroni', 'Scale & convert');

      final chosen = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(chosen.selected, {2});
    });

    testWidgets('one card reading otherwise leaves the others alone', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Daiquiri'));
      await scale(tester, 'Negroni', factor: 2);

      expect(find.text('2 parts campari'), findsOneWidget);
      expect(find.text('1.5-2 parts white rum (base)'), findsOneWidget);
    });

    testWidgets('closing the card forgets how it was read', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 2);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Negroni'));

      expect(find.text('1 part gin (base)'), findsOneWidget);
      expect(find.textContaining('×'), findsNothing);
    });

    testWidgets('nothing about the recipe changes (display only)', (
      tester,
    ) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await scale(tester, 'Negroni', factor: 4, unit: 'ml');

      expect(find.text('120 ml gin (base)'), findsOneWidget);
      expect(store.saveCount, 0);
    });
  });

  group('made it', () {
    testWidgets('every open card offers it, history or not', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      expect(madeButton, findsOneWidget);
      expect(historyLine, findsNothing);
    });

    testWidgets('the first time stamps today and counts once', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await tap(tester, madeButton);

      expect(find.text('Made once · 30 Jul 2026'), findsOneWidget);
      expect(
        store.saved?.recipeNamed('Whiskey Sour')?.made,
        MadeHistory(today, 1),
      );
      expect(store.saveCount, 1);
    });

    testWidgets('every next time counts up and moves the date', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);

      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
      expect(store.saved?.recipeNamed('Negroni')?.made, MadeHistory(today, 5));
    });

    testWidgets('nothing to take back until something is stamped', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      expect(undoButton, findsNothing);
      await tap(tester, madeButton);
      expect(undoButton, findsOneWidget);
    });

    testWidgets('undo puts the date back, not only the count', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, undoButton);

      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
      expect(
        store.saved?.recipeNamed('Negroni')?.made,
        MadeHistory(DateTime(2026, 7, 12), 4),
      );
      expect(undoButton, findsNothing);
      expect(store.saveCount, 2, reason: 'the stamp, then the taking back');
    });

    testWidgets('undone, a first stamp leaves the recipe never made', (
      tester,
    ) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await tap(tester, madeButton);
      await tap(tester, undoButton);

      expect(historyLine, findsNothing);
      expect(store.saved?.recipeNamed('Whiskey Sour')?.made, isNull);
    });

    testWidgets('undo takes back one stamp, not the run of them', (
      tester,
    ) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, madeButton);
      expect(find.text('Made 6 times · last 30 Jul 2026'), findsOneWidget);

      await tap(tester, undoButton);
      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
    });

    testWidgets('closing the card takes the undo with it', (tester) async {
      await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await tap(tester, madeButton);
      await tap(tester, find.text('Negroni'));
      await tap(tester, find.text('Negroni'));

      expect(undoButton, findsNothing);
      expect(find.text('Made 5 times · last 30 Jul 2026'), findsOneWidget);
    });

    testWidgets('a long press asks before it resets', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await longPress(tester, madeButton);
      expect(find.text('Reset "Negroni"\'s history?'), findsOneWidget);

      await tap(tester, find.text('Cancel'));
      expect(find.text('Made 4 times · last 12 Jul 2026'), findsOneWidget);
      expect(store.saveCount, 0);
    });

    testWidgets('a reset confirmed takes the history and nothing else', (
      tester,
    ) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Negroni'));
      await longPress(tester, madeButton);
      await tap(tester, find.text('Reset'));

      expect(historyLine, findsNothing);
      final negroni = store.saved?.recipeNamed('Negroni');
      expect(negroni?.made, isNull);
      expect(negroni?.notes, 'Stir over ice.');
      expect(negroni?.lines, recipeModel.recipeNamed('Negroni')?.lines);
      expect(store.saveCount, 1);
    });

    testWidgets('a recipe never made has nothing to reset', (tester) async {
      final store = await pumpRecipes(tester);
      await tap(tester, find.text('Whiskey Sour'));
      await longPress(tester, madeButton);

      expect(find.text('Reset "Whiskey Sour"\'s history?'), findsNothing);
      // No reset to reach: the press lands as the tap it also is.
      expect(
        store.saved?.recipeNamed('Whiskey Sour')?.made,
        MadeHistory(today, 1),
      );
    });
  });
}
