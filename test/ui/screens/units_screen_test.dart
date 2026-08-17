import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_bar_store.dart';
import '../harness.dart';

/// The screen as it is reached — through Settings, so leaving it has somewhere
/// to go and the menu entry is exercised with it.
Future<MemoryBarStore> pumpUnits(
  WidgetTester tester, [
  Collection? collection,
]) async {
  final store = await pumpOver(
    tester,
    const SettingsScreen(),
    collection ?? recipeCollection,
  );
  await tap(tester, find.text('Units'));
  return store;
}

/// Every row as it reads, name beside plural. The fields are drawn in pairs,
/// so the pairs are how they are read back. The bang holds because a field
/// this screen draws always carries a controller — a null is the defect.
List<(String, String)> unitRows(WidgetTester tester) {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  return [
    for (var i = 0; i + 1 < fields.length; i += 2)
      (fields[i].controller!.text, fields[i + 1].controller!.text),
  ];
}

Finder nameField(int row) => find.byType(TextField).at(row * 2);

Finder pluralField(int row) => find.byType(TextField).at(row * 2 + 1);

/// The delete on the row at [index] — the fixed rows carry none, so the
/// buttons are counted among the rows that have one.
Finder deleteOn(int index) => find.byTooltip('Delete').at(index);

/// The names the store was left holding.
List<String> savedUnits(MemoryBarStore store) => [
  for (final unit in store.saved!.units) unit.name,
];

void main() {
  testWidgets('Settings opens it, on the vocabulary as it stands', (
    tester,
  ) async {
    await pumpUnits(tester);
    expect(find.text('Units'), findsOneWidget);
    expect(unitRows(tester), [
      ('part', 'parts'),
      ('ml', ''),
      ('oz', ''),
      ('dash', 'dashes'),
      ('barspoon', 'barspoons'),
      ('drop', 'drops'),
      ('piece', 'pieces'),
      ('', ''),
    ]);
  });

  testWidgets('an unwritten plural offers the name it would read as', (
    tester,
  ) async {
    await pumpUnits(tester);
    final ml = tester.widget<TextField>(pluralField(1));
    expect(ml.decoration?.hintText, 'ml');
    final spare = tester.widget<TextField>(pluralField(7));
    expect(spare.decoration?.hintText, 'Plural');
  });

  group('the fixed three', () {
    testWidgets('cannot be renamed or deleted', (tester) async {
      await pumpUnits(tester);
      expect(tester.widget<TextField>(nameField(0)).enabled, isFalse);
      expect(tester.widget<TextField>(nameField(1)).enabled, isFalse);
      expect(tester.widget<TextField>(nameField(2)).enabled, isFalse);
      expect(tester.widget<TextField>(nameField(3)).enabled, isTrue);
      expect(find.byTooltip('Fixed unit'), findsNWidgets(3));
      // Four rows can go: everything but the three fixed and the empty spare.
      expect(find.byTooltip('Delete'), findsNWidgets(4));
    });

    testWidgets('keep their plurals editable', (tester) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, pluralField(1), 'millilitres');
      await tap(tester, find.text('Save'));
      expect(store.saved!.units[1], const Unit('ml', plural: 'millilitres'));
    });
  });

  group('editing', () {
    testWidgets('a rename rewrites every line measured in it', (tester) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, nameField(6), 'pcs');
      await tap(tester, find.text('Save'));
      expect(savedUnits(store), contains('pcs'));
      expect(savedUnits(store), isNot(contains('piece')));
      final sour = store.saved!.recipeNamed('Whiskey Sour')!;
      expect(sour.lines.last.unit, 'pcs');
    });

    testWidgets('a new row is a unit of its own', (tester) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, nameField(7), 'tsp');
      await typeInto(tester, pluralField(7), 'tsps');
      await tap(tester, find.text('Save'));
      expect(store.saved!.units.last, const Unit('tsp', plural: 'tsps'));
    });

    testWidgets('the spare row grows another, and is taken back', (
      tester,
    ) async {
      await pumpUnits(tester);
      expect(unitRows(tester), hasLength(8));
      await typeInto(tester, nameField(7), 'tsp');
      expect(unitRows(tester), hasLength(9));
      await typeInto(tester, nameField(7), '');
      expect(unitRows(tester), hasLength(8));
    });

    testWidgets('two units trade names in one save', (tester) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, nameField(3), 'barspoon');
      await typeInto(tester, nameField(4), 'dash');
      await tap(tester, find.text('Save'));
      expect(savedUnits(store).take(5), [
        'part',
        'ml',
        'oz',
        'barspoon',
        'dash',
      ]);
    });

    testWidgets('leaving it as it was writes nothing', (tester) async {
      final store = await pumpUnits(tester);
      await tap(tester, find.text('Save'));
      expect(store.saveCount, 0);
    });
  });

  group('a name the vocabulary already answers to', () {
    testWidgets('reports under the field and holds Save back', (tester) async {
      await pumpUnits(tester);
      await typeInto(tester, nameField(7), 'dashes');
      expect(saveEnabled(tester), isFalse);
      final field = tester.widget<TextField>(nameField(7));
      expect(field.decoration?.errorText, contains('Duplicate unit name'));
    });

    testWidgets('a plural repeating another unit reports on the plural', (
      tester,
    ) async {
      await pumpUnits(tester);
      // "drops" is the drop's, two rows above: the later spelling is the
      // duplicate, as it is anywhere else a name is repeated.
      await typeInto(tester, pluralField(6), 'drops');
      expect(saveEnabled(tester), isFalse);
      expect(
        tester.widget<TextField>(pluralField(6)).decoration?.errorText,
        contains('Duplicate unit name'),
      );
    });

    testWidgets('a plural reading like its own name is no collision', (
      tester,
    ) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, pluralField(2), 'oz');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(store.saved!.units[2], const Unit('oz', plural: 'oz'));
    });
  });

  group('deleting', () {
    testWidgets('a unit a recipe measures in names what stands in the way', (
      tester,
    ) async {
      final store = await pumpUnits(tester);
      // The fourth delete is the last row that has one: piece, worn by a line.
      await tap(tester, deleteOn(3));
      expect(find.text('Cannot delete "piece"'), findsOneWidget);
      expect(find.text('• Whiskey Sour'), findsOneWidget);
      await tap(tester, find.text('Close'));
      expect(unitRows(tester), hasLength(8));
      expect(store.saveCount, 0);
    });

    testWidgets('an unused one goes, and the save follows it', (tester) async {
      final store = await pumpUnits(tester);
      await tap(tester, deleteOn(0));
      expect(unitRows(tester), hasLength(7));
      await tap(tester, find.text('Save'));
      expect(savedUnits(store), isNot(contains('dash')));
      expect(store.saved!.recipes, recipeCollection.recipes);
    });
  });

  group('leaving', () {
    testWidgets('untouched, it pops silently', (tester) async {
      await pumpUnits(tester);
      await back(tester);
      expect(find.text('Discard these units?'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('with edits, it asks first', (tester) async {
      final store = await pumpUnits(tester);
      await typeInto(tester, pluralField(2), 'ounces');
      await back(tester);
      expect(find.text('Discard these units?'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(unitRows(tester)[2], ('oz', 'ounces'));
      await back(tester);
      await tap(tester, find.text('Discard'));
      expect(find.text('Settings'), findsOneWidget);
      expect(store.saveCount, 0);
    });
  });
}
