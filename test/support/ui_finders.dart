/// The finders and interactions every UI suite reads its widgets through: a
/// row's text and menu, a dialog's fields, the chips a screen filters and
/// sorts by (docs/components.md#testing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:cocktails/ui/widgets/chips/color_marks.dart';
import 'package:cocktails/ui/widgets/chips/tag_choices.dart';
import 'package:cocktails/ui/widgets/lists/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_fixtures.dart';

/// Every visible row's text in list order, whichever screen is showing one.
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

/// What a dialog answered, filled in when it closes.
final class Answer<T> {
  T? value;
}

/// Pumps a button that opens the dialog, taps it, and settles.
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

/// The colour behind the chip reading [label]; a chip always paints one.
Color chipColor(WidgetTester tester, String label) {
  final chip = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(label), matching: find.byType(DecoratedBox))
        .first,
  );
  return (chip.decoration as BoxDecoration).color!;
}

/// The dialog's name field — always its first, told apart from the search
/// field behind it.
final dialogField = find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
    .first;

/// A form field told apart by its hint.
Finder field(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

/// The bar form's one text field — the name, which leads it.
final barNameField = field('Bar name');

/// The recipe form's three kinds of field.
final nameField = field('Recipe name');

final lineFields = field('1.5 parts gin (base)');

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Types [text] into [target] and lets the frame settle.
Future<void> typeInto(WidgetTester tester, Finder target, String text) async {
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

/// Types [text] into the dialog's name field.
Future<void> type(WidgetTester tester, String text) =>
    typeInto(tester, dialogField, text);

/// The one comma-separated field an ingredient's other spellings are typed
/// into.
final aliasesField = field('Also known as (comma-separated)');

/// Types [text] into it.
Future<void> typeAliases(WidgetTester tester, String text) =>
    typeInto(tester, aliasesField, text);

/// Leaves the pushed page the way the app bar's arrow does.
Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// The system's own back (ADR 19); unclaimed, it pops the shell itself.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Which destination the shell is showing, the bar's name split off the title.
String showing(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!
        .split("'s ")
        .last;

/// The whole title over [destination]: the bar's name, then the destination.
Finder shellTitle(String destination, {String bar = 'Home bar'}) =>
    find.widgetWithText(AppBar, "$bar's $destination");

/// Taps the bottom bar's [label].
Future<void> goTo(WidgetTester tester, String label) => tap(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

/// A bulleted name in a card's body.
Finder bullet(String name) => find.text('• $name');

/// Opens the orders the list can be read in, or shuts them again.
Future<void> openSort(WidgetTester tester) =>
    tap(tester, find.byTooltip('Sort'));

/// Reads the list by [order]; the row has to be open, so this opens it.
Future<void> sortBy(WidgetTester tester, String order) async {
  if (!tester.any(find.byType(FilterChip))) await openSort(tester);
  await tap(tester, find.widgetWithText(FilterChip, order));
}

/// Which order the chips say is in force, and whether it reads backwards.
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

/// Whether the chip reading [label] wears the ring a picked one wears.
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

/// Toggles the tag [name] in the dialog, never in the filter row behind it.
Future<void> chooseTag(WidgetTester tester, String name) => tap(
  tester,
  find.descendant(of: find.byType(AlertDialog), matching: find.text(name)),
);

/// The base-spirit chip (FR-DIS-4): opens a menu rather than toggling.
final baseChip = find.byWidgetPredicate(
  (widget) => widget is ColorChip && widget.opensMenu,
);

String basePick(WidgetTester tester) =>
    tester.widget<ColorChip>(baseChip).label;

/// That menu's own items, told apart from the recipe list standing behind it.
final _baseMenu = find.byWidgetPredicate((widget) => widget is PopupMenuItem);

/// Picks [label] out of that chip's menu — a spirit, "No base" or "Any base".
Future<void> pickBase(WidgetTester tester, String label) async {
  await tap(tester, baseChip);
  await tap(tester, find.descendant(of: _baseMenu, matching: find.text(label)));
}

/// Toggles the tag [name] in a chip row — the filter or the form's picker.
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

/// The recipe names on screen, in list order — [roster] naming which
/// collection's.
Iterable<String?> namesOn(WidgetTester tester, [List<String> roster = names]) =>
    rowTexts(tester).where(roster.contains);

/// Whether the card named [name] is reading open (a body only while it is).
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

/// Whether the card named [name] starts where a reader can see it (ADR 13),
/// its top being the whole of the reading.
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
