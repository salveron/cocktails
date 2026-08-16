import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/widgets/color_chip.dart';
import 'package:cocktails/ui/widgets/tag_choices.dart';
import 'package:cocktails/ui/widgets/vocabulary_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

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

/// The real ingredient rules, with "gin" and "genever" already taken — the
/// second an alias, so the dialog is judged against the whole namespace.
List<ValidationIssue> rule(VocabularyEntry entry) => validateIngredient(
  Ingredient(entry.name, aliases: entry.aliases, tags: entry.tags),
  knownIngredientTags: {for (final tag in ingredientTags) tag.name},
  otherIngredientNames: const {'gin', 'genever'},
);

/// The real tag rules, with "classic" already taken.
List<ValidationIssue> tagRule(VocabularyEntry entry) => validateTag(
  Tag(entry.name, color: TagColor.teal),
  otherTagNames: const {'classic'},
);

/// Two ingredient tags to pick from, in the order the screen sorts them.
const ingredientTags = [
  Tag('citrus', color: TagColor.sand),
  Tag('syrup', color: TagColor.teal),
];

void main() {
  Future<Answer<VocabularyEntry?>> openIngredient(
    WidgetTester tester, {
    String title = 'New ingredient',
    String initial = '',
    List<Tag> vocabulary = const [],
    List<String> aliases = const [],
    List<String> chosen = const [],
  }) => openDialog(
    tester,
    (context) => promptForIngredient(
      context,
      title: title,
      hintText: 'Ingredient name',
      validate: rule,
      vocabulary: vocabulary,
      aliases: aliases,
      chosen: chosen,
      initial: initial,
    ),
  );

  group('ingredient dialog', () {
    testWidgets('saving hands the typed name back', (tester) async {
      final answer = await openIngredient(tester);
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));
      expect(answer.value?.name, 'absinthe');
      expect(answer.value?.tags, isEmpty);
    });

    testWidgets('backing out answers with nothing', (tester) async {
      final answer = await openIngredient(tester);
      await type(tester, 'absinthe');
      await tap(tester, find.text('Cancel'));
      expect(answer.value, isNull);
    });

    testWidgets('an edit opens on its own name, ready to save', (tester) async {
      final answer = await openIngredient(
        tester,
        title: 'Edit "campari"',
        initial: 'campari',
      );
      expect(find.text('Edit "campari"'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(answer.value?.name, 'campari');
    });

    testWidgets('every tag is offered, the worn ones ringed', (tester) async {
      await openIngredient(
        tester,
        vocabulary: ingredientTags,
        chosen: const ['syrup'],
      );
      expect(isPicked(tester, 'syrup'), isTrue);
      expect(isPicked(tester, 'citrus'), isFalse);
    });

    testWidgets('name and tags come back together', (tester) async {
      final answer = await openIngredient(tester, vocabulary: ingredientTags);
      await type(tester, 'lime juice');
      await chooseTag(tester, 'citrus');
      await tap(tester, find.text('Save'));
      expect(answer.value?.name, 'lime juice');
      expect(answer.value?.tags, const ['citrus']);
    });

    testWidgets('tapping a tag it wears takes that one off', (tester) async {
      final answer = await openIngredient(
        tester,
        initial: 'orgeat',
        vocabulary: ingredientTags,
        chosen: const ['citrus', 'syrup'],
      );
      await chooseTag(tester, 'citrus');
      expect(isPicked(tester, 'citrus'), isFalse);
      await tap(tester, find.text('Save'));
      expect(answer.value?.tags, const ['syrup']);
    });

    testWidgets('tags answer in vocabulary order, not tapping order', (
      tester,
    ) async {
      final answer = await openIngredient(tester, vocabulary: ingredientTags);
      await type(tester, 'orgeat');
      await chooseTag(tester, 'syrup');
      await chooseTag(tester, 'citrus');
      await tap(tester, find.text('Save'));
      expect(answer.value?.tags, const ['citrus', 'syrup']);
    });

    testWidgets('a chip keeps its size whether or not it is picked', (
      tester,
    ) async {
      await openIngredient(tester, vocabulary: ingredientTags);
      final chip = find.widgetWithText(ColorChip, 'citrus');
      final before = tester.getSize(chip);
      await chooseTag(tester, 'citrus');
      expect(isPicked(tester, 'citrus'), isTrue);
      expect(tester.getSize(chip), before);
    });

    testWidgets('the tag row starts where the field starts', (tester) async {
      await openIngredient(tester, vocabulary: ingredientTags);
      expect(
        tester.getTopLeft(find.byType(TagChoices)).dx,
        tester.getTopLeft(dialogField).dx,
      );
    });

    testWidgets('a vocabulary with no tags offers none', (tester) async {
      await openIngredient(tester);
      expect(find.byType(TagChoices), findsNothing);
    });

    testWidgets('refuses exactly what the vocabulary refuses', (tester) async {
      await openIngredient(tester);
      const refused = {
        'gin': 'Duplicate ingredient name: "gin"',
        'sloe gin (base)': 'reserved',
        'sloe gin (optional)': 'reserved',
        ' gin ': 'Surrounding whitespace',
      };
      for (final entry in refused.entries) {
        await type(tester, entry.key);
        expect(
          find.textContaining(entry.value),
          findsOneWidget,
          reason: entry.key,
        );
        expect(saveEnabled(tester), isFalse, reason: entry.key);
      }
      await type(tester, 'sloe gin');
      expect(saveEnabled(tester), isTrue);
    });

    testWidgets('an untouched field is not a mistake yet', (tester) async {
      await openIngredient(tester);
      expect(find.textContaining('Empty'), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a vocabulary that wears no colour is offered none', (
      tester,
    ) async {
      await openIngredient(tester);
      for (final color in TagColor.values) {
        expect(find.byTooltip(color.token), findsNothing, reason: color.token);
      }
    });

    testWidgets('the one field splits on its commas', (tester) async {
      final answer = await openIngredient(tester);
      await type(tester, 'bourbon');
      await typeAliases(tester, 'bourbon whiskey, bourbon whisky');
      await tap(tester, find.text('Save'));
      expect(answer.value?.aliases, const [
        'bourbon whiskey',
        'bourbon whisky',
      ]);
    });

    testWidgets('a separator half typed leaves no blank behind', (
      tester,
    ) async {
      final answer = await openIngredient(tester);
      await type(tester, 'bourbon');
      await typeAliases(tester, ' bourbon whiskey , ');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(answer.value?.aliases, const ['bourbon whiskey']);
    });

    testWidgets('an edit opens on the spellings it already answers to', (
      tester,
    ) async {
      final answer = await openIngredient(
        tester,
        title: 'Edit "bourbon"',
        initial: 'bourbon',
        aliases: const ['bourbon whiskey', 'bourbon whisky'],
      );
      expect(find.text('bourbon whiskey, bourbon whisky'), findsOneWidget);
      await tap(tester, find.text('Save'));
      expect(answer.value?.aliases, const [
        'bourbon whiskey',
        'bourbon whisky',
      ]);
    });

    testWidgets('an alias is refused what a name is refused', (tester) async {
      final answer = await openIngredient(tester);
      await type(tester, 'sloe gin');
      const refused = {
        // Another ingredient's spelling, its own name, and itself twice — one
        // namespace, however the collision is reached.
        'genever': 'Duplicate ingredient name: "genever"',
        'sloe gin': 'Duplicate ingredient name: "sloe gin"',
        'juniper, juniper': 'Duplicate ingredient name: "juniper"',
        'gin (base)': 'reserved',
      };
      for (final entry in refused.entries) {
        await typeAliases(tester, entry.key);
        expect(
          find.textContaining(entry.value),
          findsOneWidget,
          reason: entry.key,
        );
        expect(saveEnabled(tester), isFalse, reason: entry.key);
      }
      await typeAliases(tester, 'juniper spirit');
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(answer.value?.aliases, const ['juniper spirit']);
    });

    testWidgets('each field carries its own refusal', (tester) async {
      await openIngredient(tester);
      await type(tester, 'gin');
      await typeAliases(tester, 'genever');
      expect(find.text('Duplicate ingredient name: "gin"'), findsOneWidget);
      expect(find.text('Duplicate ingredient name: "genever"'), findsOneWidget);
    });
  });

  group('tag dialog', () {
    Future<Answer<Tag?>> openTag(
      WidgetTester tester, {
      String title = 'New recipe tag',
      String initial = '',
      TagColor color = TagColor.teal,
    }) => openDialog(
      tester,
      (context) => promptForTag(
        context,
        title: title,
        hintText: 'Recipe tag name',
        validate: tagRule,
        color: color,
        initial: initial,
      ),
    );

    testWidgets('a tag wears no tags of its own', (tester) async {
      await openTag(tester);
      expect(find.byType(TagChoices), findsNothing);
    });

    testWidgets('nor answers to any other name', (tester) async {
      await openTag(tester);
      expect(aliasesField, findsNothing);
    });

    testWidgets('the palette starts where the field starts', (tester) async {
      await openTag(tester);
      expect(
        tester.getTopLeft(find.byTooltip(TagColor.teal.token)).dx,
        tester.getTopLeft(dialogField).dx,
      );
    });

    testWidgets('the whole palette is offered at once', (tester) async {
      await openTag(tester);
      for (final color in TagColor.values) {
        expect(
          find.byTooltip(color.token),
          findsOneWidget,
          reason: color.token,
        );
      }
    });

    testWidgets('it opens on the colour it was handed, and on no other', (
      tester,
    ) async {
      await openTag(tester, color: TagColor.plum);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(isChosen(tester, 'plum'), isTrue);
    });

    testWidgets('picking a colour moves the check to it', (tester) async {
      await openTag(tester, color: TagColor.plum);
      await pick(tester, TagColor.sand);
      expect(isChosen(tester, 'sand'), isTrue);
      expect(isChosen(tester, 'plum'), isFalse);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('name and colour come back together', (tester) async {
      final answer = await openTag(tester);
      await type(tester, 'sour');
      await pick(tester, TagColor.rose);
      await tap(tester, find.text('Save'));
      expect(answer.value, const Tag('sour', color: TagColor.rose));
    });

    testWidgets('an edit opens on the tag it is editing, ready to save', (
      tester,
    ) async {
      final answer = await openTag(
        tester,
        title: 'Edit "sour"',
        initial: 'sour',
        color: TagColor.sand,
      );
      expect(find.text('Edit "sour"'), findsOneWidget);
      expect(isChosen(tester, 'sand'), isTrue);
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(answer.value, const Tag('sour', color: TagColor.sand));
    });

    testWidgets('a colour changed on its own still answers with the name', (
      tester,
    ) async {
      final answer = await openTag(
        tester,
        title: 'Edit "sour"',
        initial: 'sour',
        color: TagColor.sand,
      );
      await pick(tester, TagColor.slate);
      await tap(tester, find.text('Save'));
      expect(answer.value, const Tag('sour', color: TagColor.slate));
    });

    testWidgets('backing out answers with nothing', (tester) async {
      final answer = await openTag(tester);
      await type(tester, 'sour');
      await pick(tester, TagColor.rose);
      await tap(tester, find.text('Cancel'));
      expect(answer.value, isNull);
    });

    testWidgets('refuses exactly what the vocabulary refuses', (tester) async {
      await openTag(tester);
      await type(tester, 'classic');
      expect(find.textContaining('Duplicate tag name: "classic"'), findsOne);
      expect(saveEnabled(tester), isFalse);
      await type(tester, 'sour');
      expect(saveEnabled(tester), isTrue);
    });
  });

  group('delete dialog', () {
    Future<Answer<bool>> openDelete(
      WidgetTester tester,
      List<String> blockedBy,
    ) => openDialog(
      tester,
      (context) => confirmDelete(
        context,
        what: 'gin',
        blockedBy: blockedBy,
        blockedByNoun: 'recipes',
      ),
    );

    testWidgets('an unreferenced entry is deleted once confirmed', (
      tester,
    ) async {
      final answer = await openDelete(tester, const []);
      expect(find.text('Delete "gin"?'), findsOneWidget);
      await tap(tester, find.text('Delete'));
      expect(answer.value, isTrue);
    });

    testWidgets('cancelling leaves it alone', (tester) async {
      final answer = await openDelete(tester, const []);
      await tap(tester, find.text('Cancel'));
      expect(answer.value, isFalse);
    });

    testWidgets('dismissed without an answer is no answer at all', (
      tester,
    ) async {
      final answer = await openDelete(tester, const []);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(answer.value, isFalse);
    });

    testWidgets('a referenced entry names what stands in the way', (
      tester,
    ) async {
      final answer = await openDelete(tester, const ['Negroni', 'Martini']);
      expect(find.text('Cannot delete "gin"'), findsOneWidget);
      expect(find.text('Remove it from these recipes first:'), findsOneWidget);
      expect(find.text('• Negroni'), findsOneWidget);
      expect(find.text('• Martini'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await tap(tester, find.text('Close'));
      expect(answer.value, isFalse);
    });
  });
}
