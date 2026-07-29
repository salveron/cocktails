import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:cocktails/ui/widgets/search_field.dart';
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

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Types [text] into the dialog's own field — never the search behind it.
Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(dialogField, text);
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
