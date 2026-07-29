import 'package:cocktails/domain/domain.dart';
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

/// The real ingredient rules, with "gin" already taken.
List<ValidationIssue> rule(String name) => validateIngredient(
  Ingredient(name),
  knownIngredientTags: const {},
  otherIngredientNames: const {'gin'},
);

/// The real tag rules, with "classic" already taken.
List<ValidationIssue> tagRule(String name) => validateTag(
  Tag(name, color: TagColor.teal),
  otherTagNames: const {'classic'},
);

void main() {
  Future<Answer<String?>> openName(
    WidgetTester tester, {
    String title = 'New ingredient',
    String initial = '',
  }) => openDialog(
    tester,
    (context) => promptForName(
      context,
      title: title,
      hintText: 'Ingredient name',
      validate: rule,
      initial: initial,
    ),
  );

  group('name dialog', () {
    testWidgets('saving hands the typed name back', (tester) async {
      final answer = await openName(tester);
      await type(tester, 'absinthe');
      await tap(tester, find.text('Save'));
      expect(answer.value, 'absinthe');
    });

    testWidgets('backing out answers with nothing', (tester) async {
      final answer = await openName(tester);
      await type(tester, 'absinthe');
      await tap(tester, find.text('Cancel'));
      expect(answer.value, isNull);
    });

    testWidgets('a rename opens on its own name, ready to save', (
      tester,
    ) async {
      final answer = await openName(
        tester,
        title: 'Rename "campari"',
        initial: 'campari',
      );
      expect(find.text('Rename "campari"'), findsOneWidget);
      expect(saveEnabled(tester), isTrue);
      await tap(tester, find.text('Save'));
      expect(answer.value, 'campari');
    });

    testWidgets('refuses exactly what the vocabulary refuses', (tester) async {
      await openName(tester);
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
      await openName(tester);
      expect(find.textContaining('Empty'), findsNothing);
      expect(saveEnabled(tester), isFalse);
    });

    testWidgets('a vocabulary that wears no colour is offered none', (
      tester,
    ) async {
      await openName(tester);
      for (final color in TagColor.values) {
        expect(find.byTooltip(color.token), findsNothing, reason: color.token);
      }
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
