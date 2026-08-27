/// The row a list draws for one entry, and the overflow menu it carries —
/// which is drawn only when there is something in it to open.
library;

import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a menu with nothing in it', () {
    testWidgets('draws no ⋮ rather than one opening onto nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RowMenu({}))),
      );
      expect(find.byTooltip('More'), findsNothing);
    });
  });
}
