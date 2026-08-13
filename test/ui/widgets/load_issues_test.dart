import 'package:cocktails/ui/widgets/load_issues.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

void main() {
  group('startup issues', () {
    testWidgets('a healthy store leaves the banner out', (tester) async {
      await pumpScreen(tester, const LoadIssues());
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('a corrupt store names what could not be read', (tester) async {
      await pumpScreen(tester, const LoadIssues(), store: corruptStore());
      expect(
        find.textContaining('line 4: Unknown ingredient: "rye"'),
        findsOneWidget,
      );
    });

    testWidgets('the banner stays gone once dismissed', (tester) async {
      await pumpScreen(tester, const LoadIssues(), store: corruptStore());
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
    });
  });
}
