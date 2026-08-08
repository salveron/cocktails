import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:cocktails/ui/theme.dart';
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
        RecipeLine(Amount(1), 'part', ['gin']),
        RecipeLine(Amount(1), 'part', ['campari']),
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
        RecipeLine(Amount(2), 'part', ['bourbon'], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['lemon juice']),
        RecipeLine(Amount(0.75), 'part', ['sugar syrup']),
        RecipeLine(Amount(1), 'piece', ['egg white'], mark: LineMark.optional),
      ],
    ),
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['campari']),
        RecipeLine(Amount(1), 'part', ['sweet vermouth']),
      ],
      notes: 'Stir over ice.',
      made: MadeHistory(DateTime(2026, 7, 12), 4),
    ),
    Recipe(
      'Daiquiri',
      lines: const [
        RecipeLine(Amount.range(1.5, 2), 'part', [
          'white rum',
        ], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['lime juice']),
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

/// [widget] under the provider overrides the composition root makes, so a
/// widget test reaches the real state layer over an in-memory store — over a
/// clock stopped on [today] where the screen stamps a date, and over [sharer]
/// where it hands a copy to the system's sheet (ADR 18).
Widget scoped(
  Widget widget, {
  ModelStore? store,
  DateTime? today,
  Future<void> Function(String)? sharer,
}) => ProviderScope(
  overrides: [
    modelStoreProvider.overrideWithValue(store ?? MemoryModelStore()),
    if (today != null) clockProvider.overrideWithValue(() => today),
    if (sharer != null) sharerProvider.overrideWithValue(sharer),
  ],
  child: widget,
);

/// The whole app, pumped past its startup load.
Future<void> pumpApp(WidgetTester tester, {ModelStore? store}) async {
  await tester.pumpWidget(scoped(const CocktailsApp(), store: store));
  await tester.pumpAndSettle();
}

/// One screen on its own, pumped past its startup load — under the app's own
/// theme, so a screen is judged in the ink it will actually be drawn in.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  ModelStore? store,
  DateTime? today,
  Future<void> Function(String)? sharer,
}) async {
  await tester.pumpWidget(
    scoped(
      MaterialApp(
        theme: cocktailsTheme(Brightness.light),
        home: Scaffold(body: screen),
      ),
      store: store,
      today: today,
      sharer: sharer,
    ),
  );
  await tester.pumpAndSettle();
}

/// [screen] over a store seeded with [model], handing that store back so the
/// test can read what reached it. The one way a screen test starts.
Future<MemoryModelStore> pumpOver(
  WidgetTester tester,
  Widget screen,
  Model model, {
  DateTime? today,
}) async {
  final store = MemoryModelStore(model);
  await pumpScreen(tester, screen, store: store, today: today);
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

/// The dialog's name field, told apart from the search field behind it and
/// from whatever else the entry carries below it — the name always opens the
/// dialog, so it is the first field in it.
final dialogField = find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
    .first;

/// A form field told apart by its hint — the one thing each field keeps
/// whatever is typed into it.
Finder field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

/// The recipe form's three kinds of field.
final nameField = field('Recipe name');
final lineFields = field('1.5 parts gin (base)');
final notesField = field('Preparation, glassware, garnish…');

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> longPress(WidgetTester tester, Finder target) async {
  await tester.longPress(target);
  await tester.pumpAndSettle();
}

/// Types [text] into [target] and lets the frame settle.
Future<void> typeInto(WidgetTester tester, Finder target, String text) async {
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

/// Types [text] into the dialog's name field — never the search behind it.
Future<void> type(WidgetTester tester, String text) =>
    typeInto(tester, dialogField, text);

/// The one comma-separated field a bottle's other spellings are typed into.
final aliasesField = field('Also known as (comma-separated)');

/// Types [text] into it.
Future<void> typeAliases(WidgetTester tester, String text) =>
    typeInto(tester, aliasesField, text);

/// Opens whatever the list's add button opens — told apart by its icon, a list
/// being allowed a second button beside it (the recipes' dice, FR-DIS-5).
Future<void> openAdd(WidgetTester tester) =>
    tap(tester, find.widgetWithIcon(FloatingActionButton, Icons.add));

/// The dice over the recipe list, and the roll it makes (FR-DIS-5).
final dice = find.byTooltip('Random pick');

Future<void> roll(WidgetTester tester) => tap(tester, dice);

/// Rolls without waiting it out, leaving the caller to pump: what the wash does
/// between the roll and the rest is the whole of what some tests are watching.
Future<void> rollWithoutSettling(WidgetTester tester) async {
  await tester.tap(dice);
  await tester.pump();
}

/// The fill the card named [name] draws itself in — where the wash starts a
/// drawn card and where every other card rests (FR-DIS-5).
Color? cardFill(WidgetTester tester, String name) => tester
    .widget<Card>(
      find.ancestor(of: find.text(name), matching: find.byType(Card)).first,
    )
    .color;

/// Whether the card named [name] is reading open — only an open card carries
/// the button that stamps it (FR-REC-6).
bool cardOpen(WidgetTester tester, String name) => tester.any(
  find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(Card)),
    matching: find.widgetWithText(FilledButton, 'Made it'),
  ),
);

/// Which of [names] are reading open, in the order asked.
Iterable<String> openCards(WidgetTester tester, Iterable<String> names) =>
    names.where((name) => cardOpen(tester, name));

/// Whether the card named [name] starts somewhere a reader can see it, rather
/// than above the list or below it — what a reveal promises (ADR 13). Its top
/// is the whole of the reading: an open card may be taller than the list, and
/// one carried off the top reads as having gone nowhere.
///
/// The list is found as the card's own scroller, so nothing here has to know
/// which widget draws it.
bool cardInView(WidgetTester tester, String name) {
  final card = find
      .ancestor(of: find.text(name), matching: find.byType(Card))
      .first;
  final list = tester.getRect(
    find.ancestor(of: card, matching: find.byType(Scrollable)).first,
  );
  final top = tester.getRect(card).top;
  return top >= list.top && top < list.bottom;
}

/// Leaves the pushed page the way the app bar's arrow does, so a [PopScope]
/// guarding it gets its say.
Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// Opens the orders the list can be read in, or shuts them again.
Future<void> openSort(WidgetTester tester) =>
    tap(tester, find.byTooltip('Sort'));

/// Reads the list by [order] — picking the one already in force turns it round.
/// The row has to be open, so this opens it and leaves it that way.
Future<void> sortBy(WidgetTester tester, String order) async {
  if (!tester.any(find.byType(FilterChip))) await openSort(tester);
  await tap(tester, find.widgetWithText(FilterChip, order));
}

/// Which order the chips say is in force, and whether it is read backwards.
/// The bangs hold because a chosen chip always wears a label and an arrow —
/// a null here is the defect, and it reports as one.
(String, bool) sortedBy(WidgetTester tester) {
  final chosen = tester
      .widgetList<FilterChip>(find.byType(FilterChip))
      .firstWhere((chip) => chip.selected);
  return (
    (chosen.label as Text).data!,
    (chosen.avatar! as Icon).icon == Icons.arrow_upward,
  );
}

/// The list's own pinned field, told apart from any field a dialog opens.
final searchBox = find.descendant(
  of: find.byType(SearchField),
  matching: find.byType(TextField),
);

/// Types [query] into it.
Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(searchBox, query);
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

/// The base-spirit chip, and what it reads (FR-DIS-4). One chip on a screen
/// opens a menu rather than toggling, so that is the whole of the telling.
final baseChip = find.byWidgetPredicate(
  (widget) => widget is ColorChip && widget.opensMenu,
);

String basePick(WidgetTester tester) =>
    tester.widget<ColorChip>(baseChip).label;

/// Whether it wears the ring a picked tag wears — that is, whether it narrows.
bool baseRinged(WidgetTester tester) =>
    tester.widget<ColorChip>(baseChip).chosen!;

/// The chip reading [label], for the geometry a filter row is judged by.
Finder chipOf(WidgetTester tester, String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ColorChip));

/// What that menu is offering, told apart from the list standing behind it — a
/// bottle's name is on the card of every recipe built from it, so a reading not
/// held to the menu would find both.
final _baseMenu = find.byWidgetPredicate((widget) => widget is PopupMenuItem);

/// Picks [label] out of that chip's menu — a spirit, "No base" or "Any base".
Future<void> pickBase(WidgetTester tester, String label) async {
  await tap(tester, baseChip);
  await tap(tester, find.descendant(of: _baseMenu, matching: find.text(label)));
}

/// Every offering it makes, in order, leaving it open to be read.
Future<List<String>> baseChoices(WidgetTester tester) async {
  await tap(tester, baseChip);
  return [
    for (final text in tester.widgetList<Text>(
      find.descendant(of: _baseMenu, matching: find.byType(Text)),
    ))
      text.data!,
  ];
}

/// Toggles the tag [name] in a chip row — the inventory's filter or the
/// recipe form's picker, which are the same row twice.
Future<void> pickTag(WidgetTester tester, String name) => tap(
  tester,
  find.descendant(of: find.byType(TagChoices), matching: find.text(name)),
);

/// [text] on a list card, told apart from the filter row standing above the
/// list: one tag is a chip in both places, that row being the cards' legend.
Finder onCard(String text) =>
    find.descendant(of: find.byType(Card), matching: find.text(text));

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
