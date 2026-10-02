/// What is offered nearby, put to the reader (FR-BAR-8,
/// docs/ui-design.md#new-bar): one browse, grouped under the device offering
/// it, and a pick agreed to before anything is fetched.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:cocktails/ui/wording.dart';
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

  bool selectIsOffered(WidgetTester tester) =>
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Select'))
          .onPressed !=
      null;

  /// A card by what it reads: the bar's name and, after it, the device.
  Finder cardOf(Found bar) =>
      find.text('${bar.name}$beside${bar.source.from}', findRichText: true);

  bool outlined(WidgetTester tester, Found bar) {
    final card = tester.widget<EntryCard>(
      find.ancestor(of: cardOf(bar), matching: find.byType(EntryCard)),
    );
    return card.selected ?? false;
  }

  testWidgets('every bar found carries the device offering it', (tester) async {
    await pumpNearby(tester, [zen, beach, ada]);
    // Two bars of one name are told apart by the device beside them, names
    // being labels rather than identity (FR-BAR-1).
    expect(cardOf(zen), findsOneWidget);
    expect(cardOf(ada), findsOneWidget);
    expect(cardOf(beach), findsOneWidget);
  });

  /// One device's bars still stand together, without a heading over them.
  testWidgets('they run by device and then by bar', (tester) async {
    await pumpNearby(tester, [zen, beach, ada]);
    String reads(Found bar) => '${bar.name}$beside${bar.source.from}';
    final titles = find.descendant(
      of: find.byType(EntryCard),
      matching: find.byType(Text),
    );
    expect(
      tester
          .widgetList<Text>(titles)
          .map((title) => title.textSpan!.toPlainText())
          .toList(),
      [reads(ada), reads(beach), reads(zen)],
    );
  });

  testWidgets('nothing may be selected until one is picked', (tester) async {
    await pumpNearby(tester, [zen, ada]);
    expect(selectIsOffered(tester), isFalse);
    await tap(tester, cardOf(zen));
    expect(selectIsOffered(tester), isTrue);
  });

  /// The ring a picked tag chip wears, so one idiom says "picked" everywhere.
  testWidgets('the one picked wears a ring and the others do not', (
    tester,
  ) async {
    await pumpNearby(tester, [zen, beach]);
    await tap(tester, cardOf(beach));
    expect(outlined(tester, beach), isTrue);
    expect(outlined(tester, zen), isFalse);
    await tap(tester, cardOf(zen));
    expect(outlined(tester, beach), isFalse);
  });

  testWidgets('selecting answers with the bar that was picked', (tester) async {
    await pumpNearby(tester, [zen, beach]);
    await tap(tester, cardOf(beach));
    await tap(tester, find.text('Select'));
    expect(chosen, beach);
  });

  testWidgets('cancelling answers nothing at all', (tester) async {
    await pumpNearby(tester, [zen]);
    await tap(tester, cardOf(zen));
    await tap(tester, find.text('Cancel'));
    expect(chosen, isNull);
  });

  /// Both sides have to be there at once, which is the one thing a reader can
  /// act on — so the empty state says that and offers another look.
  /// Nothing to take, so nothing offers to take it: the ask to look again
  /// stands where Select would, rather than beside a dead button.
  testWidgets('nothing nearby says why, and tries again in Select\'s place', (
    tester,
  ) async {
    await pumpNearby(tester, const []);
    expect(find.textContaining('Nothing is shared'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
    expect(finder.looks, 1);
    await tap(tester, find.text('Try again'));
    expect(finder.looks, 2);
  });

  /// The platform's own order, which every other dialog in the app keeps: the
  /// way out first and the act last, nearest the thumb.
  testWidgets('the way out comes first and the act last', (tester) async {
    await pumpNearby(tester, [zen]);
    final actions = tester
        .widgetList<TextButton>(
          find.descendant(
            of: find.byType(OverflowBar),
            matching: find.byType(TextButton),
          ),
        )
        .map((button) => (button.child! as Text).data)
        .toList();
    expect(actions, ['Cancel', 'Select']);
  });

  /// A browse runs while the reader is looking and no longer (ADR 22).
  testWidgets('it browses once on opening, not once per frame', (tester) async {
    await pumpNearby(tester, [zen]);
    await tester.pump();
    expect(finder.looks, 1);
  });
}
