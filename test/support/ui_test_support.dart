/// Support the UI suites share: the `Bar`/`Collection` fixtures standing in for
/// a reader's own, the overrides that put a widget test over the real state
/// layer and an in-memory store, and the pump/tap/finder helpers every screen
/// test reads its widgets through (docs/components.md#testing).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:cocktails/ui/theme.dart';
import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:cocktails/ui/widgets/chips/color_marks.dart';
import 'package:cocktails/ui/widgets/chips/tag_choices.dart';
import 'package:cocktails/ui/widgets/lists/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

/// Two ingredients under one recipe — the least a screen needs to be drawn
/// with something on it, and what every "not empty" case is read over.
final smallCollection = Collection(
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
/// every form field: tags, marks, a range and notes — and each section's
/// absence too. Shared by the recipe list and the recipe form, so neither can
/// be exercised against a shape the other never sees.
final recipeCollection = Collection(
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
    ),
    Recipe(
      'Daiquiri',
      lines: const [
        RecipeLine(Amount.range(1.5, 2), 'part', [
          'white rum',
        ], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['lime juice']),
      ],
    ),
  ],
);

/// The one bar every widget test runs over: owned, so nothing is hidden for
/// being a guest's, and reading in parts.
Bar testBar({
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
  ShoppingSettings shopping = const ShoppingSettings(),
}) => Bar(
  id: 'test01',
  name: name,
  mode: BarMode.owner,
  display: display,
  shopping: shopping,
);

/// Another owner's, read as it stood at its last refresh (FR-BAR-3) — the
/// counterpart to [testBar], so one screen can be judged in both modes. The
/// source is what makes it a guest at all: a bar with none is refused.
///
/// Named apart from `domain/shelf_test.dart`'s own `guestBar`: that one builds
/// a bare model `Bar` with a summary set directly, for the merge rules a
/// `Collection` never enters; this one is read by widget tests, which reach
/// its counts by summarising a real [Collection] over it.
Bar testGuestBar({
  String name = "Ada's bar",
  FixedUnit display = FixedUnit.part,
}) => Bar(
  id: 'guest1',
  name: name,
  mode: BarMode.guest,
  display: display,
  source: const BarSource(via: Transport.file, at: 'ada.yaml', from: 'Ada'),
  refreshed: testNow.subtract(const Duration(days: 2)),
);

/// [collection] as a bar's file — the shape a picked document actually has
/// from format 2 on: the owner's name and the unit it reads in ride with the
/// contents (ADR 21).
String fileOf(
  Collection collection, {
  String name = "Ada's bar",
  FixedUnit display = FixedUnit.part,
}) => const YamlCodec().encode((
  name: name,
  display: display,
  collection: collection,
));

/// A file the codec reads and the rules refuse: nothing declares "rye". The
/// one damaged file every screen that meets one is judged against.
const damagedFile = '''
format: 1
recipes:
  - name: Sazerac
    lines: ["2 parts rye"]
''';

/// A store whose bar file did not decode, recovered onto [smallCollection].
MemoryBarStore corruptStore() {
  final bar = testBar();
  return MemoryBarStore((bars: [bar], openId: bar.id))
    ..barOutcomes[bar.id] = Rejected(
      [
        SourcedIssue(
          ValidationIssue(
            const [],
            ValidationIssueKind.unknownIngredient,
            'Unknown ingredient: "rye"',
          ),
          4,
        ),
      ],
      recovered: (
        name: bar.name,
        display: bar.display,
        collection: smallCollection,
      ),
    );
}

/// What the clock answers under test, so anything a screen dates reads the
/// same on every run.
final testNow = DateTime.utc(2026, 8, 14, 12);

/// The overrides the composition root makes, so a widget test reaches the real
/// state layer over an in-memory store — and over the three seams data crosses
/// the edge by: [sharer] where a copy goes out to the system's sheet, [picker]
/// where a file comes back off it, [clock] where the reader's own moves
/// (ADR 18).
List<Override> _overrides(
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
) => [
  barStoreProvider.overrideWithValue(store ?? MemoryBarStore.of(testBar())),
  clockProvider.overrideWithValue(clock ?? () => testNow),
  if (sharer != null) sharerProvider.overrideWithValue(sharer),
  if (picker != null) filePickerProvider.overrideWithValue(picker),
];

/// [widget] under those overrides, meeting the startup load itself — which is
/// what the app does and what only the app does.
Widget scoped(
  Widget widget, {
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
}) => ProviderScope(
  overrides: _overrides(store, sharer, picker, clock),
  child: widget,
);

/// The whole app, pumped past its startup load.
Future<void> pumpApp(
  WidgetTester tester, {
  BarStore? store,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(
    scoped(const CocktailsApp(), store: store, picker: picker, clock: clock),
  );
  await tester.pumpAndSettle();
}

/// One screen on its own, over a shelf that has already answered — under the
/// app's own theme, so a screen is judged in the ink it will actually be drawn
/// in. The load is awaited before the first frame rather than met in one: the
/// shell draws no screen until it has landed (docs/ui-design.md#app-shell), so
/// a screen pumped over an unanswered shelf is a state the app cannot reach.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
}) async {
  final container = ProviderContainer(
    overrides: _overrides(store, sharer, picker, null),
  );
  addTearDown(container.dispose);
  await container.read(shelfProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: cocktailsTheme(Brightness.light),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// [screen] over a store seeded with [collection], handing that store back so
/// the test can read what reached it. The one way a screen test starts.
Future<MemoryBarStore> pumpOver(
  WidgetTester tester,
  Widget screen,
  Collection collection, {
  FixedUnit display = FixedUnit.part,
  Bar? bar,
}) async {
  final store = MemoryBarStore.of(bar ?? testBar(display: display), collection);
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

/// What a dialog answered — filled in when it closes, so a test reads it after
/// tapping its way out.
final class Answer<T> {
  T? value;
}

/// Pumps a button that opens the dialog, taps it, and settles — leaving the
/// dialog on screen.
Future<Answer<T>> openDialog<T>(
  WidgetTester tester,
  Future<T> Function(BuildContext context) open,
) async {
  final answer = Answer<T>();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                open(context).then((value) => answer.value = value),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answer;
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

/// The bar form's one text field — the name, which leads it.
final barNameField = field('Bar name');

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

/// The one comma-separated field an ingredient's other spellings are typed
/// into.
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

/// Whether the card named [name] is reading open — a row carries a body only
/// while it is expanded, whichever screen drew it. A name no row is showing is
/// not open, so a narrowed list answers rather than throwing.
bool cardOpen(WidgetTester tester, String name) {
  final rows = find.ancestor(
    of: find.text(name),
    matching: find.byType(EntryCard),
  );
  return tester.any(rows) && tester.widget<EntryCard>(rows.first).body != null;
}

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

/// The system's own back, which the shell claims while a jump is left to undo
/// (ADR 19). Unclaimed, it pops the route the whole shell stands on.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Which destination the shell is showing, read off the title over it — the
/// bar's name leads that title (docs/ui-design.md#bars) and the destination
/// closes it, which is the part this answers.
String showing(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!
        .split("'s ")
        .last;

/// The whole title over [destination]: the bar's name, then the destination.
/// One home for the possessive, so a test naming the destination alone cannot
/// pass while the title says something else.
Finder shellTitle(String destination, {String bar = 'Home bar'}) =>
    find.widgetWithText(AppBar, "$bar's $destination");

/// Taps the bottom bar's [label] — a destination the reader chose, never a
/// jump.
Future<void> goTo(WidgetTester tester, String label) => tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

/// A bulleted name in a card's body — a basket's ingredients and its recipes
/// alike.
Finder bullet(String name) => find.text('• $name');

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

/// What that menu is offering, told apart from the list standing behind it — an
/// ingredient's name is on the card of every recipe built from it, so a reading
/// not held to the menu would find both.
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

/// Toggles the tag [name] in a chip row — the ingredients' filter or the
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

const names = ['Daiquiri', 'Negroni', 'Whiskey Sour'];

Future<MemoryBarStore> pumpRecipes(
  WidgetTester tester, [
  Collection? collection,
  FixedUnit display = FixedUnit.part,
]) => pumpOver(
  tester,
  const RecipesScreen(),
  collection ?? recipeCollection,
  display: display,
);

/// The recipe names on screen, in list order — [roster] naming which
/// collection's, so a summary line is never mistaken for a row.
Iterable<String?> namesOn(WidgetTester tester, [List<String> roster = names]) =>
    rowTexts(tester).where(roster.contains);

/// The three verdicts at once (FR-DIS-1), and an optional line the verdict
/// passes over though the card still marks it. Its A→Z runs against its
/// availability, so the two orders can never be read for each other.
const stocked = ['Campari Shot', 'Gin Shot', 'Negroni'];

final stockedCollection = Collection(
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

/// A collection long enough that a row can be drawn from beyond the fold: two
/// worth making at either end of the alphabet, nothing but missing ones between
/// (ADR 13). Read by name, so availability cannot bring the far one forward.
final longCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('vodka'),
  ],
  recipes: [
    Recipe(
      'Aviation',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
      ],
    ),
    for (var filler = 1; filler <= 38; filler++)
      Recipe(
        'Filler ${filler.toString().padLeft(2, '0')}',
        lines: const [
          RecipeLine(Amount(1), 'part', ['vodka']),
        ],
      ),
    Recipe(
      'Zombie',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
      ],
    ),
  ],
);

/// Two worth making side by side at the top, each carrying a body tall enough
/// to move whatever stands below it, and filler enough to leave the list
/// scrollable. A draw here always lands on a row the reader can already see —
/// which the package reaches by measuring pixels rather than by index, and so
/// the one case a stale measurement throws off (ADR 13).
const crowded = ['Aviation', 'Bramble'];

final crowdedCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('vodka'),
  ],
  recipes: [
    for (final name in crowded)
      Recipe(
        name,
        notes: 'Stir over ice.\nStrain.\nTwist of lemon.',
        lines: const [
          RecipeLine(Amount(1), 'part', ['gin']),
        ],
      ),
    for (var filler = 1; filler <= 20; filler++)
      Recipe(
        'Filler ${filler.toString().padLeft(2, '0')}',
        lines: const [
          RecipeLine(Amount(1), 'part', ['vodka']),
        ],
      ),
  ],
);

/// Two worth making on different bases, so a base pick is seen to govern what
/// a roll may land on — without it the draw would move between them.
final basedCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('white rum', stock: StockLevel.in_),
  ],
  recipes: [
    Recipe(
      'Gin Fizz',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.base),
      ],
    ),
    Recipe(
      'Rum Fizz',
      lines: const [
        RecipeLine(Amount(1), 'part', ['white rum'], mark: LineMark.base),
      ],
    ),
  ],
);

/// Two bases with rows enough behind each, and a tag on every second one, so
/// every way of narrowing leaves a list that still scrolls — where a reader is
/// put is a question with an answer only while there is somewhere else to be.
const spirits = {'gin': 'Gin', 'vodka': 'Vodka'};

final spiritedCollection = Collection(
  ingredients: [
    for (final spirit in spirits.keys)
      Ingredient(spirit, stock: StockLevel.in_),
  ],
  recipeTags: const [Tag('sour', color: TagColor.sand)],
  recipes: [
    for (final spirit in spirits.entries)
      for (var row = 1; row <= 20; row++)
        Recipe(
          '${spirit.value} ${row.toString().padLeft(2, '0')}',
          tags: row.isEven ? const ['sour'] : const [],
          lines: [
            RecipeLine(const Amount(1), 'part', [
              spirit.key,
            ], mark: LineMark.base),
          ],
        ),
  ],
);

/// A tag nothing wears, so the chips alone can empty the list.
final untriedCollection = recipeCollection.withTag(
  TagKind.recipe,
  const Tag('tiki', color: TagColor.teal),
);

/// A recipe naming its tag in a case the vocabulary does not use — what a hand
/// edit to an exported file leaves behind, and what `validateCollection`
/// accepts, tag references resolving by the fold (ADR 08).
final recasedTagCollection = recipeCollection.withRecipe(
  recipeCollection.recipes
      .firstWhere((recipe) => recipe.name == 'Whiskey Sour')
      .copyWith(tags: const ['Sour', 'classic']),
);

/// An ingredient answering to a second name, so a search can reach a recipe by
/// a spelling no line of it holds (FR-VOC-6).
final aliasedCollection = recipeCollection.withIngredient(
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

/// Two recipes of nothing but groups: one line for each way a group can read —
/// an ingredient on hand, only a low one, nothing at all — and one carrying a
/// mark, so the mark is seen to govern the group rather than an ingredient of
/// it.
final substitutedCollection = Collection(
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

/// The ingredients on the line reading [line] drawn in the dimmed ink — the
/// ones a group offers that the bar cannot supply. They are the only runs
/// carrying a colour of their own, so the colour is what tells them apart.
List<String> dimmedOn(WidgetTester tester, String line) => [
  for (final run in runsOn(tester, line))
    if (run.style?.color != null) run.text!,
];

/// The ink those ingredients wear; fails the test where the line dims nothing.
Color dimInkOn(WidgetTester tester, String line) => runsOn(
  tester,
  line,
).firstWhere((run) => run.style?.color != null).style!.color!;

/// What the dot beside the line reading [line] reports, or null when that line
/// carries none — which is how an in-stock ingredient reads.
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

/// The reader who pours in ml (FR-SET-1) — a part is 30 ml, so the Negroni's
/// three lines land on round numbers. A pick rather than a collection now: it
/// is the bar's, not the recipes' (ADR 21).
const inMillilitres = FixedUnit.ml;

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

ProviderContainer _containerOn(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(RecipesScreen)),
      listen: false,
    );

/// The reading unit settled elsewhere while this screen stands (FR-SET-1) —
/// the bar's, not the collection's (ADR 21), so nothing the list watches for
/// its rows changes with it.
Future<void> setDisplay(WidgetTester tester, FixedUnit display) async {
  await _containerOn(tester).read(shelfProvider.notifier).setDisplay(display);
  await tester.pumpAndSettle();
}

/// The collection rewritten under the reader, without their having touched
/// anything: [recipe]'s notes, so every row is built afresh while what is on
/// show, and the order it is in, both stand exactly as they did.
Future<void> rewriteUnder(WidgetTester tester, String recipe) async {
  final container = _containerOn(tester);
  final collection = container.read(collectionProvider);
  await container
      .read(barWriterProvider)!
      .upsertRecipe(
        collection.recipeNamed(recipe)!.copyWith(notes: 'Stirred.'),
      );
  await tester.pumpAndSettle();
}

/// The whole shell over [bar], pumped past its startup load — [picker] being
/// what the system's file picker answers a refresh with (FR-BAR-7). The one way
/// a test reaches behaviour that only exists once the shell is standing.
Future<void> pumpShell(
  WidgetTester tester,
  Bar bar, {
  Collection? collection,
  Future<String?> Function()? picker,
}) => pumpApp(
  tester,
  store: MemoryBarStore.of(bar, collection ?? recipeCollection),
  picker: picker,
);
