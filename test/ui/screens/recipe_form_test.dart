import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/screens/recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

Future<MemoryModelStore> pumpList(WidgetTester tester, [Model? model]) =>
    pumpOver(tester, const RecipesScreen(), model ?? recipeModel);

/// The error under the line field at [index], or null while it carries none.
String? lineError(WidgetTester tester, int index) =>
    tester.widget<TextField>(lineFields.at(index)).decoration?.errorText;

void main() {
  group('opening', () {
    testWidgets('the add button opens an empty form', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      expect(find.text('New recipe'), findsOneWidget);
      expect(lineFields, findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('the nothing-matches offer prefills the name', (tester) async {
      await pumpList(tester);
      await search(tester, 'Mai Tai');
      await tap(tester, find.text('Add "Mai Tai"'));
      expect(find.widgetWithText(TextField, 'Mai Tai'), findsOneWidget);
    });

    testWidgets('the notes field opens one line tall, free to grow', (
      tester,
    ) async {
      await pumpList(tester);
      await openAdd(tester);
      final notes = tester.widget<TextField>(notesField);
      expect(notes.minLines, isNull);
      expect(notes.maxLines, isNull);
    });

    testWidgets('a vocabulary with no tags offers no picker', (tester) async {
      await pumpList(tester, Model(ingredients: [Ingredient('gin')]));
      await openAdd(tester);
      expect(find.text('Tags'), findsNothing);
      expect(find.text('Notes'), findsOneWidget);
    });
  });

  group('creating', () {
    testWidgets('a full entry saves and lands on the list', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '2 part gin');
      await pickTag(tester, 'classic');
      await typeInto(tester, notesField, 'Stir.');
      await tap(tester, find.text('Save'));
      expect(find.text('New recipe'), findsNothing);
      expect(find.text('Martini'), findsOneWidget);
      expect(
        store.saved!.recipeNamed('Martini'),
        Recipe(
          'Martini',
          tags: const ['classic'],
          lines: const [
            RecipeLine(Amount(2), 'part', ['gin']),
          ],
          notes: 'Stir.',
        ),
      );
    });

    testWidgets('the lines grow under the typing', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      expect(lineFields, findsOneWidget);
      await typeInto(tester, lineFields.first, '1 part gin');
      expect(lineFields, findsNWidgets(2));
      await typeInto(tester, lineFields.at(1), '1 part campari');
      expect(lineFields, findsNWidgets(3));
    });

    testWidgets('erasing the line just typed takes the spare back', (
      tester,
    ) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, lineFields.first, '1 part gin');
      expect(lineFields, findsNWidgets(2));
      await typeInto(tester, lineFields.first, '');
      expect(lineFields, findsOneWidget);
    });

    testWidgets('a bottle typed in another case is that bottle', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '2 part GIN');
      await tap(tester, find.text('Save'));
      expect(find.text('Add missing ingredients?'), findsNothing);
      expect(
        store.saved!.recipeNamed('Martini')!.lines.single,
        const RecipeLine(Amount(2), 'part', ['gin']),
      );
    });

    testWidgets('a bottle named by an alias is that bottle (ADR 10)', (
      tester,
    ) async {
      final store = await pumpList(
        tester,
        recipeModel.withIngredient(
          Ingredient('gin', aliases: const ['jenever']),
        ),
      );
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '2 parts Jenever');
      await tap(tester, find.text('Save'));
      // The offer is not built for a name the vocabulary already answers to,
      // so an alias can no longer create a near-duplicate bottle.
      expect(find.text('Add missing ingredients?'), findsNothing);
      expect(
        store.saved!.recipeNamed('Martini')!.lines.single,
        const RecipeLine(Amount(2), 'part', ['gin']),
      );
    });

    testWidgets('a line with no unit is that many parts', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '2 gin');
      await tap(tester, find.text('Save'));
      expect(
        store.saved!.recipeNamed('Martini')!.lines.single,
        const RecipeLine(Amount(2), 'part', ['gin']),
      );
    });

    testWidgets('save waits for a name and clean lines', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      expect(saveEnabled(tester), isTrue);
      await typeInto(tester, lineFields.first, 'gibberish');
      expect(saveEnabled(tester), isFalse);
      expect(
        find.text('Expected "<amount> [unit] <ingredient>": "gibberish"'),
        findsOneWidget,
      );
      await typeInto(tester, lineFields.first, '1 part gin');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('a value rule lands under its own line', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.first, '0 part gin');
      await tap(tester, find.text('Save'));
      expect(find.text('New recipe'), findsOneWidget);
      expect(find.text('Amount must be positive: 0'), findsOneWidget);
      await typeInto(tester, lineFields.first, '1 part gin');
      expect(find.text('Amount must be positive: 0'), findsNothing);
    });

    testWidgets('a line issue skips the fields left empty above it', (
      tester,
    ) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await typeInto(tester, lineFields.at(0), '1 part gin');
      await typeInto(tester, lineFields.at(1), '0 part campari');
      // Emptying the first field makes the bad line recipe line 0 while it is
      // still field 1 — which is where its message has to land.
      await typeInto(tester, lineFields.at(0), '');
      await tap(tester, find.text('Save'));
      expect(lineError(tester, 0), isNull);
      expect(lineError(tester, 1), 'Amount must be positive: 0');
    });

    testWidgets('unknown ingredients are offered and added', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sazerac');
      await typeInto(tester, lineFields.first, '2 part rye (base)');
      await tap(tester, find.text('Save'));
      expect(find.text('Add missing ingredients?'), findsOneWidget);
      expect(find.text('• rye'), findsOneWidget);
      await tap(tester, find.text('Add and save'));
      expect(find.text('New recipe'), findsNothing);
      final saved = store.saved!;
      expect(saved.ingredientNamed('rye'), Ingredient('rye'));
      expect(
        saved.recipeNamed('Sazerac')!.lines.first,
        const RecipeLine(Amount(2), 'part', ['rye'], mark: LineMark.base),
      );
    });

    testWidgets('a group is typed as one line and saved whole (ADR 11)', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sidecar');
      await typeInto(tester, lineFields.first, '1 part gin/bourbon (base)');
      await tap(tester, find.text('Save'));
      expect(find.text('Add missing ingredients?'), findsNothing);
      expect(
        store.saved!.recipeNamed('Sidecar')!.lines.single,
        const RecipeLine(Amount(1), 'part', [
          'gin',
          'bourbon',
        ], mark: LineMark.base),
      );
    });

    testWidgets('only the alternatives no bottle answers to are offered', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sidecar');
      await typeInto(tester, lineFields.first, '1 part gin / cognac / rye');
      await tap(tester, find.text('Save'));
      expect(find.text('• cognac'), findsOneWidget);
      expect(find.text('• rye'), findsOneWidget);
      expect(find.text('• gin'), findsNothing);
      await tap(tester, find.text('Add and save'));
      expect(store.saved!.ingredientNamed('cognac'), Ingredient('cognac'));
      expect(store.saved!.recipeNamed('Sidecar')!.lines.single.ingredients, [
        'gin',
        'cognac',
        'rye',
      ]);
    });

    testWidgets('a group refuses the bottle it already names', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sidecar');
      await typeInto(tester, lineFields.first, '1 part gin / GIN');
      await tap(tester, find.text('Save'));
      expect(lineError(tester, 0), 'Duplicate alternative on the line: "GIN"');
      expect(store.saved, isNull);
    });

    testWidgets('a name wanted by two lines is offered once', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sazerac');
      await typeInto(tester, lineFields.at(0), '2 part rye (base)');
      await typeInto(tester, lineFields.at(1), '1 part rye');
      await tap(tester, find.text('Save'));
      expect(find.text('• rye'), findsOneWidget);
    });

    testWidgets('the whole entry reaches the store in one write', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sazerac');
      await typeInto(tester, lineFields.at(0), '2 part rye (base)');
      await typeInto(tester, lineFields.at(1), '1 part absinthe');
      await tap(tester, find.text('Save'));
      await tap(tester, find.text('Add and save'));
      expect(store.saveCount, 1);
      expect(store.saved!.ingredientNamed('absinthe'), Ingredient('absinthe'));
      expect(store.saved!.recipeNamed('Sazerac'), isNotNull);
    });

    testWidgets('declining the offer marks the lines', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Sazerac');
      await typeInto(tester, lineFields.first, '2 part rye');
      await tap(tester, find.text('Save'));
      await tap(tester, find.text('Cancel'));
      expect(find.text('New recipe'), findsOneWidget);
      expect(find.text('Unknown ingredient: "rye"'), findsOneWidget);
      expect(store.saved, isNull);
    });

    testWidgets("another recipe's name is refused live", (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Negroni');
      expect(find.text('Duplicate recipe name: "Negroni"'), findsOneWidget);
      expect(saveEnabled(tester), isFalse);
    });
  });

  group('editing', () {
    testWidgets('the form opens filled', (tester) async {
      await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      expect(find.text('Edit "Negroni"'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Negroni'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, '1 part gin (base)'),
        findsOneWidget,
      );
      expect(lineFields, findsNWidgets(4));
      expect(isPicked(tester, 'classic'), isTrue);
      expect(isPicked(tester, 'sour'), isFalse);
      expect(find.widgetWithText(TextField, 'Stir over ice.'), findsOneWidget);
    });

    testWidgets('a recipe keeping its own name is no duplicate', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      expect(saveEnabled(tester), isTrue);
      await typeInto(tester, notesField, 'Stir over plenty of ice.');
      await tap(tester, find.text('Save'));
      expect(find.text('Edit "Negroni"'), findsNothing);
      expect(
        store.saved!.recipeNamed('Negroni')!.notes,
        'Stir over plenty of ice.',
      );
    });

    testWidgets('a rename replaces the entry and keeps the history', (
      tester,
    ) async {
      final store = await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await typeInto(tester, nameField, 'Boulevardier');
      await tap(tester, find.text('Save'));
      final saved = store.saved!;
      expect(saved.recipeNamed('Negroni'), isNull);
      expect(
        saved.recipeNamed('Boulevardier')!.made,
        MadeHistory(DateTime(2026, 7, 12), 4),
      );
      expect(store.saveCount, 1);
    });

    testWidgets('emptying the last line leaves one empty field, not two', (
      tester,
    ) async {
      await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      expect(lineFields, findsNWidgets(4));
      await typeInto(tester, lineFields.at(2), '');
      expect(lineFields, findsNWidgets(3));
    });

    testWidgets('a line emptied out is dropped on save', (tester) async {
      final store = await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await typeInto(tester, lineFields.at(1), '');
      await tap(tester, find.text('Save'));
      expect(
        store.saved!
            .recipeNamed('Negroni')!
            .lines
            .map((l) => l.ingredients.single),
        ['gin', 'sweet vermouth'],
      );
    });
  });

  group('leaving', () {
    testWidgets('an untouched form pops silently', (tester) async {
      await pumpList(tester);
      await openAdd(tester);
      await back(tester);
      expect(find.text('New recipe'), findsNothing);
      expect(find.text('Discard this recipe?'), findsNothing);
    });

    testWidgets('an untouched edit pops silently too', (tester) async {
      await pumpList(tester);
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await back(tester);
      expect(find.text('Edit "Negroni"'), findsNothing);
      expect(find.text('Discard this recipe?'), findsNothing);
    });

    testWidgets('a dirty form asks first', (tester) async {
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      await back(tester);
      expect(find.text('Discard this recipe?'), findsOneWidget);
      await tap(tester, find.text('Keep editing'));
      expect(find.text('New recipe'), findsOneWidget);
      await back(tester);
      await tap(tester, find.text('Discard'));
      expect(find.text('New recipe'), findsNothing);
      expect(store.saved, isNull);
    });

    testWidgets('a line, a tag and a note each make it dirty', (tester) async {
      await pumpList(tester);
      Future<void> asksAfter(Future<void> Function() edit) async {
        await chooseOnRow(tester, 'Negroni', 'Edit');
        await edit();
        await back(tester);
        expect(find.text('Discard this recipe?'), findsOneWidget);
        await tap(tester, find.text('Discard'));
      }

      await asksAfter(
        () => typeInto(tester, lineFields.at(3), '1 dash bitters'),
      );
      await asksAfter(() => pickTag(tester, 'sour'));
      await asksAfter(() => typeInto(tester, notesField, 'Stir well.'));
    });
  });

  group('refusing what no field can carry', () {
    testWidgets('says so out loud instead of doing nothing', (tester) async {
      // A times below 1 is a rule only a recovered file can break, and its
      // issue path names no line — so no field can carry the message.
      final store = await pumpList(
        tester,
        Model(
          ingredients: [Ingredient('gin')],
          recipes: [
            Recipe(
              'Negroni',
              lines: const [
                RecipeLine(Amount(1), 'part', ['gin']),
              ],
              made: MadeHistory(DateTime(2026, 7, 12), 0),
            ),
          ],
        ),
      );
      await chooseOnRow(tester, 'Negroni', 'Edit');
      await typeInto(tester, nameField, 'Boulevardier');
      await tap(tester, find.text('Save'));
      expect(find.text('Edit "Negroni"'), findsOneWidget);
      expect(find.text('times must be at least 1: 0'), findsOneWidget);
      expect(store.saved, isNull);
    });

    testWidgets('a recipe with nothing to make it from (FR-REC-2)', (
      tester,
    ) async {
      const refusal =
          'Recipe needs at least one ingredient line that is not '
          'optional';
      final store = await pumpList(tester);
      await openAdd(tester);
      await typeInto(tester, nameField, 'Martini');
      // The name alone passes its own rules, so Save is reachable and the
      // refusal is what it answers with.
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(find.text(refusal), findsOneWidget);
      expect(store.saved, isNull);

      await typeInto(tester, lineFields.first, '1 part gin (optional)');
      await tap(tester, find.text('Save'));
      expect(find.text(refusal), findsWidgets);
      expect(store.saved, isNull);

      await typeInto(tester, lineFields.first, '1 part gin');
      await tap(tester, find.text('Save'));
      expect(find.text('New recipe'), findsNothing);
      expect(store.saved!.recipeNamed('Martini'), isNotNull);
    });
  });
}
