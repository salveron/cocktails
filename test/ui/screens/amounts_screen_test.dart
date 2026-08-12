import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// The screen as it is reached — through Settings, so leaving it has somewhere
/// to go and the menu entry is exercised with it.
Future<MemoryBarStore> pumpAmounts(
  WidgetTester tester, [
  Collection? collection,
]) async {
  final store = await pumpOver(
    tester,
    const SettingsScreen(),
    collection ?? recipeCollection,
  );
  await tap(tester, find.text('Amounts'));
  return store;
}

/// The global unit's segment, told apart from the same token trailing a row.
Finder pick(String unit) => find.descendant(
  of: find.byType(SegmentedButton<FixedUnit>),
  matching: find.text(unit),
);

Finder ratioField(int row) => find.byType(TextField).at(row);

/// What each row is spelled with, in row order — the table's own cells, so the
/// picker's unit labels above are out of it and so is a field's error text
/// below. The bang holds because a cell this screen draws always says
/// something: a null is the defect, and it reports as one.
List<String> ratioCells(WidgetTester tester) {
  final inField = find
      .descendant(of: find.byType(TextField), matching: find.byType(Text))
      .evaluate()
      .toSet();
  return [
    for (final cell
        in find
            .descendant(of: find.byType(Table), matching: find.byType(Text))
            .evaluate())
      if (!inField.contains(cell)) (cell.widget as Text).data!,
  ];
}

/// The row as it reads — "1 part = 30 ml".
String ratioRow(WidgetTester tester, int row) {
  final cells = ratioCells(tester);
  final typed = tester.widget<TextField>(ratioField(row)).controller!.text;
  return '${cells[row * 2]} $typed ${cells[row * 2 + 1]}';
}

List<String> ratioRows(WidgetTester tester) => [
  for (var row = 0; row < 2; row++) ratioRow(tester, row),
];

/// That [text] stands on one line — what it took against what it would take
/// with all the room in the world. A column too narrow wraps it rather than
/// throwing, so this is what tells a cut-off unit name from a fitting one.
void expectOneLine(WidgetTester tester, String text) {
  final cell = tester.renderObject<RenderBox>(find.text(text).first);
  expect(
    cell.size.height,
    cell.getMaxIntrinsicHeight(double.infinity),
    reason: '"$text" wrapped rather than taking the room it needs',
  );
}

void main() {
  testWidgets('Settings opens it, on the settings as they stand', (
    tester,
  ) async {
    await pumpAmounts(tester);
    expect(find.text('Amounts'), findsOneWidget);
    expect(ratioRows(tester), ['1 part = 30 ml', '1 part = 1.0144 oz']);
  });

  group('the global unit', () {
    testWidgets('picking ml leaves both rows reading in it', (tester) async {
      await pumpAmounts(tester);
      await tap(tester, pick('ml'));
      // Under ml neither row leads with it, so the two are the file's own
      // numbers — a part's size and an ounce's (ADR 17).
      expect(ratioRows(tester), ['1 part = 30 ml', '1 oz = 29.5735 ml']);
    });

    testWidgets('picking oz turns both rows to run from the ounce', (
      tester,
    ) async {
      await pumpAmounts(tester);
      await tap(tester, pick('oz'));
      expect(ratioRows(tester), ['1 oz = 0.9858 part', '1 oz = 29.5735 ml']);
    });

    testWidgets('a pick alone is worth saving, and moves nothing else', (
      tester,
    ) async {
      final store = await pumpAmounts(tester);
      await tap(tester, pick('ml'));
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      // The pick lands on the bar's record, never in the collection (ADR 21).
      expect(store.savedShelf?.bars.single.display, FixedUnit.ml);
      expect(store.saved, isNull, reason: 'no collection was touched');
    });

    testWidgets('picking round the three drifts no number', (tester) async {
      final store = await pumpAmounts(tester);
      for (final unit in ['ml', 'oz', 'part']) {
        await tap(tester, pick(unit));
      }
      expect(ratioRows(tester), ['1 part = 30 ml', '1 part = 1.0144 oz']);
      // Save is offered on the rows being readable, not on their having moved
      // — and back where it started there is nothing for it to write.
      await tap(tester, find.text('Save'));
      expect(store.saveCount, 0);
    });
  });

  group('the rows', () {
    testWidgets('the first sets what a part is worth, the ounce standing', (
      tester,
    ) async {
      final store = await pumpAmounts(tester);
      await typeInto(tester, ratioField(0), '45');
      // The ounce did not move under it — the second row's reading did.
      expect(ratioRows(tester), ['1 part = 45 ml', '1 part = 1.5216 oz']);
      await tap(tester, find.text('Save'));
      expect(store.saved!.settings, const Settings(partMl: 45));
    });

    testWidgets('the second sets what an ounce is worth, the part standing', (
      tester,
    ) async {
      final store = await pumpAmounts(tester);
      await typeInto(tester, ratioField(1), '1');
      expect(ratioRows(tester), ['1 part = 30 ml', '1 part = 1 oz']);
      await tap(tester, find.text('Save'));
      expect(store.saved!.settings, const Settings(ozMl: 30));
    });

    testWidgets('a row reading across both follows the one that moved', (
      tester,
    ) async {
      await pumpAmounts(tester);
      await tap(tester, pick('oz'));
      await typeInto(tester, ratioField(1), '30');
      // The ounce is now a part, so the row above says so.
      expect(ratioRows(tester), ['1 oz = 1 part', '1 oz = 30 ml']);
    });

    testWidgets('under ml the two rows do not move each other', (tester) async {
      final store = await pumpAmounts(tester);
      await tap(tester, pick('ml'));
      await typeInto(tester, ratioField(0), '25');
      expect(ratioRows(tester), ['1 part = 25 ml', '1 oz = 29.5735 ml']);
      await typeInto(tester, ratioField(1), '30');
      expect(ratioRows(tester), ['1 part = 25 ml', '1 oz = 30 ml']);
      await tap(tester, find.text('Save'));
      expect(store.saved!.settings, const Settings(partMl: 25, ozMl: 30));
      expect(store.savedShelf?.bars.single.display, FixedUnit.ml);
    });

    testWidgets('leaving them as they were writes nothing', (tester) async {
      final store = await pumpAmounts(tester);
      await tap(tester, find.text('Save'));
      expect(store.saveCount, 0);
    });
  });

  group('on a phone', () {
    testWidgets('the fields stand in line under differently spelled units', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAmounts(tester);
      // Under ml the two rows lead with different units — the one pick where
      // the sentences are not the same length.
      await tap(tester, pick('ml'));
      expect(
        tester.getTopLeft(ratioField(0)).dx,
        tester.getTopLeft(ratioField(1)).dx,
      );
    });

    testWidgets('a larger text takes the room it needs, cutting nothing', (
      tester,
    ) async {
      // Tall, so the Settings menu it is reached through is not the thing
      // running out of room: the width and the text size are the point.
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAmounts(tester);
      expect(tester.takeException(), isNull);
      expect(ratioRows(tester), ['1 part = 30 ml', '1 part = 1.0144 oz']);
      for (final cell in ratioCells(tester)) {
        expectOneLine(tester, cell);
      }
    });
  });

  group('a ratio the settings would refuse', () {
    testWidgets('reports under the field and holds Save back', (tester) async {
      await pumpAmounts(tester);
      await typeInto(tester, ratioField(0), 'thirty');
      expect(saveEnabled(tester), isFalse);
      expect(
        tester.widget<TextField>(ratioField(0)).decoration?.errorText,
        'Must be a number above zero',
      );
    });

    testWidgets('zero has no inverse, so it is refused like a word', (
      tester,
    ) async {
      await pumpAmounts(tester);
      await typeInto(tester, ratioField(1), '0');
      expect(saveEnabled(tester), isFalse);
      expect(
        tester.widget<TextField>(ratioField(1)).decoration?.errorText,
        'Must be a number above zero',
      );
    });

    testWidgets('a negative one too, and Save comes back when it is fixed', (
      tester,
    ) async {
      final store = await pumpAmounts(tester);
      await typeInto(tester, ratioField(0), '-5');
      expect(saveEnabled(tester), isFalse);
      await typeInto(tester, ratioField(0), '20');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(store.saved!.settings, const Settings(partMl: 20));
    });
  });

  group('leaving', () {
    testWidgets('untouched, it pops silently', (tester) async {
      await pumpAmounts(tester);
      await back(tester);
      expect(find.text('Discard these amounts?'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('with edits, it asks first', (tester) async {
      final store = await pumpAmounts(tester);
      await typeInto(tester, ratioField(0), '45');
      await back(tester);
      expect(find.text('Discard these amounts?'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(ratioRow(tester, 0), '1 part = 45 ml');
      await back(tester);
      await tap(tester, find.text('Discard'));
      expect(find.text('Settings'), findsOneWidget);
      expect(store.saveCount, 0);
    });
  });
}
