/// What is offered nearby, put to the reader (FR-BAR-8,
/// docs/ui-design.md#new-bar): one browse, grouped under the device offering
/// it, and a pick agreed to before anything is fetched.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:cocktails/ui/widgets/dialogs/nearby_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_bar_store.dart';
import '../../../support/ui_finders.dart';
import '../../../support/ui_harness.dart';

void main() {
  Found offered(String bar, String device) => (
    source: BarSource(via: Transport.lan, at: '$bar/$device', from: device),
    name: bar,
  );

  final zen = offered('Home bar', "Nikita's phone");
  final beach = offered('Beach bar', "Nikita's phone");
  final ada = offered('Home bar', "Ada's laptop");

  late MemoryFinder finder;
  Found? chosen;

  /// The dialog over what [found] says is nearby, opened from a bare screen —
  /// what it answers with kept where the test can read it.
  Future<void> pumpNearby(WidgetTester tester, List<Found> found) async {
    finder = MemoryFinder(found);
    chosen = null;
    await pumpScreen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => chosen = await promptForNearby(context),
          child: const Text('open'),
        ),
      ),
      overrides: [
        findersProvider.overrideWithValue({Transport.lan: finder}),
      ],
    );
    await tap(tester, find.text('open'));
  }

  bool chooseIsOffered(WidgetTester tester) =>
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Choose'))
          .onPressed !=
      null;

  bool outlined(WidgetTester tester, String bar) {
    final card = tester.widget<EntryCard>(
      find.ancestor(of: find.text(bar), matching: find.byType(EntryCard)),
    );
    return card.selected ?? false;
  }

  testWidgets('every bar found stands under the device offering it', (
    tester,
  ) async {
    await pumpNearby(tester, [zen, beach, ada]);
    expect(find.text("Nikita's phone"), findsOneWidget);
    expect(find.text("Ada's laptop"), findsOneWidget);
    // Two bars of one name are told apart by whose device they sit under,
    // names being labels rather than identity (FR-BAR-1).
    expect(find.text('Home bar'), findsNWidgets(2));
    expect(find.text('Beach bar'), findsOneWidget);
  });

  testWidgets('nothing may be chosen until one is picked', (tester) async {
    await pumpNearby(tester, [zen, ada]);
    expect(chooseIsOffered(tester), isFalse);
    await tap(tester, find.text('Home bar').first);
    expect(chooseIsOffered(tester), isTrue);
  });

  /// The ring a picked tag chip wears, so one idiom says "picked" everywhere.
  testWidgets('the one picked wears a ring and the others do not', (
    tester,
  ) async {
    await pumpNearby(tester, [zen, beach]);
    await tap(tester, find.text('Beach bar'));
    expect(outlined(tester, 'Beach bar'), isTrue);
    expect(outlined(tester, 'Home bar'), isFalse);
    await tap(tester, find.text('Home bar'));
    expect(outlined(tester, 'Beach bar'), isFalse);
  });

  testWidgets('choosing answers with the bar that was picked', (tester) async {
    await pumpNearby(tester, [zen, beach]);
    await tap(tester, find.text('Beach bar'));
    await tap(tester, find.text('Choose'));
    expect(chosen, beach);
  });

  testWidgets('cancelling answers nothing at all', (tester) async {
    await pumpNearby(tester, [zen]);
    await tap(tester, find.text('Home bar'));
    await tap(tester, find.text('Cancel'));
    expect(chosen, isNull);
  });

  /// Both sides have to be there at once, which is the one thing a reader can
  /// act on — so the empty state says that and offers another look.
  testWidgets('nothing nearby says why, and looks again on asking', (
    tester,
  ) async {
    await pumpNearby(tester, const []);
    expect(find.textContaining('Nothing is being shared'), findsOneWidget);
    expect(finder.looks, 1);
    await tap(tester, find.text('Look again'));
    expect(finder.looks, 2);
  });

  /// A browse runs while the reader is looking and no longer (ADR 22).
  testWidgets('it browses once on opening, not once per frame', (tester) async {
    await pumpNearby(tester, [zen]);
    await tester.pump();
    expect(finder.looks, 1);
  });
}
