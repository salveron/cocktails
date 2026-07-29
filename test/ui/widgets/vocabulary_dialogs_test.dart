import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/widgets/vocabulary_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

bool saveEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
        .onPressed !=
    null;

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

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
      await tap(tester, 'Save');
      expect(answer.value, 'absinthe');
    });

    testWidgets('backing out answers with nothing', (tester) async {
      final answer = await openName(tester);
      await type(tester, 'absinthe');
      await tap(tester, 'Cancel');
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
      await tap(tester, 'Save');
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
  });

  group('delete dialog', () {
    Future<Answer<bool>> openDelete(
      WidgetTester tester,
      List<String> blockedBy,
    ) => openDialog(
      tester,
      (context) => confirmDelete(context, what: 'gin', blockedBy: blockedBy),
    );

    testWidgets('an unreferenced entry is deleted once confirmed', (
      tester,
    ) async {
      final answer = await openDelete(tester, const []);
      expect(find.text('Delete "gin"?'), findsOneWidget);
      await tap(tester, 'Delete');
      expect(answer.value, isTrue);
    });

    testWidgets('cancelling leaves it alone', (tester) async {
      final answer = await openDelete(tester, const []);
      await tap(tester, 'Cancel');
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
      expect(find.text('• Negroni'), findsOneWidget);
      expect(find.text('• Martini'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await tap(tester, 'Close');
      expect(answer.value, isFalse);
    });
  });
}
