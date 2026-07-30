import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:cocktails/ui/widgets/search_field.dart';
import 'package:cocktails/ui/widgets/tag_choices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two ingredients under one recipe — enough for every "not empty" screen.
final fixtureModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
  ],
  recipeTags: const [Tag('classic', color: TagColor.rose)],
  recipes: [
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin'),
        RecipeLine(Amount(1), Unit.part, 'campari'),
      ],
    ),
  ],
);

/// Three recipes off their reading order, covering every card section and
/// every form field: tags, marks, a range, notes and made-history — and each
/// section's absence too. Shared by the recipe list and the recipe form, so
/// neither can be exercised against a shape the other never sees.
final recipeModel = Model(
  ingredients: [
    Ingredient('bourbon'),
    Ingredient('campari'),
    Ingredient('egg white'),
    Ingredient('gin'),
    Ingredient('lemon juice'),
    Ingredient('lime juice'),
    Ingredient('sugar syrup'),
    Ingredient('sweet vermouth'),
    Ingredient('white rum'),
  ],
  recipeTags: const [
    Tag('classic', color: TagColor.rose),
    Tag('sour', color: TagColor.sand),
  ],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(Amount(2), Unit.part, 'bourbon', mark: LineMark.base),
        RecipeLine(Amount(1), Unit.part, 'lemon juice'),
        RecipeLine(Amount(0.75), Unit.part, 'sugar syrup'),
        RecipeLine(Amount(1), Unit.piece, 'egg white', mark: LineMark.optional),
      ],
    ),
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin', mark: LineMark.base),
        RecipeLine(Amount(1), Unit.part, 'campari'),
        RecipeLine(Amount(1), Unit.part, 'sweet vermouth'),
      ],
      notes: 'Stir over ice.',
      made: MadeHistory(DateTime(2026, 7, 12), 4),
    ),
    Recipe(
      'Daiquiri',
      lines: const [
        RecipeLine(
          Amount.range(1.5, 2),
          Unit.part,
          'white rum',
          mark: LineMark.base,
        ),
        RecipeLine(Amount(1), Unit.part, 'lime juice'),
      ],
      made: MadeHistory(DateTime(2026, 1, 3), 1),
    ),
  ],
);

/// A store whose file did not decode, recovered onto [fixtureModel].
MemoryModelStore corruptStore() => MemoryModelStore()
  ..outcome = Corrupt([
    SourcedIssue(
      ValidationIssue(
        const ['recipes', 0],
        ValidationIssueKind.unknownIngredient,
        'Unknown ingredient: "rye"',
      ),
      4,
    ),
  ], recoveredFromBackup: fixtureModel);

/// [widget] under the provider override the composition root makes, so a
/// widget test reaches the real state layer over an in-memory store.
Widget scoped(Widget widget, {ModelStore? store}) => ProviderScope(
  overrides: [
    modelStoreProvider.overrideWithValue(store ?? MemoryModelStore()),
  ],
  child: widget,
);

/// The whole app, pumped past its startup load.
Future<void> pumpApp(WidgetTester tester, {ModelStore? store}) async {
  await tester.pumpWidget(scoped(const CocktailsApp(), store: store));
  await tester.pumpAndSettle();
}

/// One screen on its own, pumped past its startup load.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  ModelStore? store,
}) async {
  await tester.pumpWidget(
    scoped(
      MaterialApp(home: Scaffold(body: screen)),
      store: store,
    ),
  );
  await tester.pumpAndSettle();
}

/// [screen] over a store seeded with [model], handing that store back so the
/// test can read what reached it. The one way a screen test starts.
Future<MemoryModelStore> pumpOver(
  WidgetTester tester,
  Widget screen,
  Model model,
) async {
  final store = MemoryModelStore(model);
  await pumpScreen(tester, screen, store: store);
  return store;
}

/// Every visible row's text in list order — each name and whatever its row
/// carries beside it. The one reading of a vocabulary list, whichever screen
/// is showing one.
Iterable<String?> rowTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
    )
    .map((text) => text.data);

/// The overflow menu of the row named [name].
Finder rowMenu(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: find.byTooltip('More'),
);

/// Picks [action] out of that row's menu.
Future<void> chooseOnRow(
  WidgetTester tester,
  String name,
  String action,
) async {
  await tester.tap(rowMenu(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

/// The colour behind the chip reading [label]. The bang holds because a chip
/// always paints a background — a null here is the defect, and it reports as one.
Color chipColor(WidgetTester tester, String label) {
  final chip = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (chip.decoration as BoxDecoration).color!;
}

/// The dialog's own field, told apart from the search field behind it.
final dialogField = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

/// A form field told apart by its hint — the one thing each field keeps
/// whatever is typed into it.
Finder field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

/// The recipe form's three kinds of field.
final nameField = field('Recipe name');
final lineFields = field('1.5 part gin (base)');
final notesField = field('Preparation, glassware, garnish…');

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Types [text] into [target] and lets the frame settle.
Future<void> typeInto(WidgetTester tester, Finder target, String text) async {
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

/// Types [text] into the dialog's own field — never the search behind it.
Future<void> type(WidgetTester tester, String text) =>
    typeInto(tester, dialogField, text);

/// Opens whatever the list's add button opens.
Future<void> openAdd(WidgetTester tester) =>
    tap(tester, find.byType(FloatingActionButton));

/// Leaves the pushed page the way the app bar's arrow does, so a [PopScope]
/// guarding it gets its say.
Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// Types [query] into the list's pinned search field.
Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchField),
      matching: find.byType(TextField),
    ),
    query,
  );
  await tester.pumpAndSettle();
}

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
        .onPressed !=
    null;

/// Whether the swatch for [token] is the one wearing the check.
bool isChosen(WidgetTester tester, String token) => tester.any(
  find.descendant(
    of: find.byTooltip(token),
    matching: find.byIcon(Icons.check),
  ),
);

Future<void> pick(WidgetTester tester, TagColor color) async {
  await tester.tap(find.byTooltip(color.token));
  await tester.pumpAndSettle();
}

/// Whether the chip reading [label] is wearing its ring. The outermost box in
/// a choosable chip is the ring, drawn transparent while it is not picked.
bool isPicked(WidgetTester tester, String label) {
  final ring = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.widgetWithText(ColorChip, label),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  final border = (ring.decoration as BoxDecoration).border;
  return border != null && border.top.color != Colors.transparent;
}

/// Toggles the tag [name] in the dialog — never in the filter row behind it.
Future<void> chooseTag(WidgetTester tester, String name) => tap(
  tester,
  find.descendant(of: find.byType(AlertDialog), matching: find.text(name)),
);

/// Toggles the tag [name] in a chip row — the inventory's filter or the
/// recipe form's picker, which are the same row twice.
Future<void> pickTag(WidgetTester tester, String name) => tap(
  tester,
  find.descendant(of: find.byType(TagChoices), matching: find.text(name)),
);

/// Every dot on the row named [name], in the order they are drawn.
Finder _dotsOn(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
  matching: find.byType(TagDot),
);

/// The tags those dots stand for.
Iterable<String> dotsOn(WidgetTester tester, String name) =>
    tester.widgetList<TagDot>(_dotsOn(name)).map((dot) => dot.tag.name);

/// The colour the first of them is drawn in, on [chipColor]'s terms.
Color dotColor(WidgetTester tester, String name) =>
    (tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: _dotsOn(name),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration)
        .color!;
