import 'package:cocktails/ui/widgets/dialogs/confirm_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness.dart';

void main() {
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
