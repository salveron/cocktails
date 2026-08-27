/// The searchable list every vocabulary screen is drawn as, and the pull a
/// reader makes down it to ask a guest bar's source again (FR-BAR-5) — the
/// gesture being the list's own, offered only where there is a source to ask.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/ui_test_support.dart';

void main() {
  group('asking the source again (FR-BAR-5)', () {
    /// The pull a reader makes down the list, let run to its answer.
    Future<void> pull(WidgetTester tester) async {
      await tester.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a guest bar\'s lists answer a pull and an owned one\'s do '
        'not', (tester) async {
      await pumpShell(tester, testGuestBar());
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // Both of a guest's destinations, not just the one it opens on.
      await goTo(tester, 'Ingredients');
      expect(find.byType(RefreshIndicator), findsOneWidget);
      // An owned bar has no source to ask, so the gesture is not offered — and
      // the shell needs no refresh control of its own either.
      await pumpShell(tester, testBar());
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('what arrives replaces what stood, wholesale', (tester) async {
      await pumpShell(
        tester,
        testGuestBar(),
        picker: () async => fileOf(smallCollection),
      );
      expect(find.text('Whiskey Sour'), findsOneWidget);
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsNothing);
      expect(find.text('Negroni'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    /// Where the gesture is the only way in: there are no rows to pull on, so a
    /// body with nothing to scroll has to answer one anyway.
    testWidgets('a guest bar holding nothing can still be pulled', (
      tester,
    ) async {
      await pumpShell(
        tester,
        testGuestBar(),
        collection: Collection(),
        picker: () async => fileOf(recipeCollection),
      );
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsOneWidget);
    });

    testWidgets('what will not read leaves the bar as it stood, and says why', (
      tester,
    ) async {
      await pumpShell(tester, testGuestBar(), picker: () async => damagedFile);
      await pull(tester);
      expect(find.text('Whiskey Sour'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.textContaining('rye'), findsOneWidget);
      expect(find.textContaining('line '), findsOneWidget);
    });

    /// A source naming a transport this build has no adapter for — an index
    /// carrying `cloud` before its channel lands (ADR 22).
    testWidgets('a source that could not be reached says which way', (
      tester,
    ) async {
      await pumpShell(
        tester,
        Bar(
          id: 'cld1',
          name: "Ada's bar",
          mode: BarMode.guest,
          source: const BarSource(
            via: Transport.cloud,
            at: 'somewhere',
            from: 'Ada',
          ),
        ),
      );
      await pull(tester);
      expect(
        find.textContaining('its source could not be found'),
        findsOneWidget,
      );
      await tap(tester, find.text('Dismiss'));
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('a reader who picks nothing has failed at nothing', (
      tester,
    ) async {
      await pumpShell(tester, testGuestBar(), picker: () async => null);
      await pull(tester);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.text('Whiskey Sour'), findsOneWidget);
    });

    /// The same ask from the gear, where the row an owned bar imports through
    /// stands: a reader who went looking for it finds it in the menu, and there
    /// is no list under them to pull on.
  });
}
