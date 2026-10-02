/// The room a bar is shared from (FR-BAR-6, docs/ui-design.md#sharing): the
/// switch that offers and withdraws, and the name the device is announced
/// under (ADR 28) — the one control on the screen the reader may not always
/// move.
library;

import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/screens/share_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_bar_store.dart';
import '../../support/ui_finders.dart';
import '../../support/ui_fixtures.dart';
import '../../support/ui_harness.dart';

void main() {
  late MemoryOfferings offerings;

  final beach = Bar(id: 'test02', name: 'Beach bar', mode: BarMode.owner);

  /// The room over [bars], open on the first — the LAN answering through a
  /// double, since the state layer is what keeps a widget test off a socket
  /// (ADR 22). [phone] is what the device calls itself before the reader has.
  late ProviderContainer container;

  Future<MemoryBarStore> pumpRoom(
    WidgetTester tester, {
    List<Bar>? bars,
    String phone = 'Pixel 8',
  }) async {
    offerings = MemoryOfferings();
    final shelf = bars ?? [testBar()];
    final store = MemoryBarStore.over(shelf, {
      for (final bar in shelf) bar.id: smallCollection,
    });
    container = await pumpScreen(
      tester,
      ShareScreen(shelf.first.id),
      store: store,
      overrides: [
        platformNameProvider.overrideWithValue(phone),
        offeringsProvider.overrideWithValue({Transport.lan: offerings}),
      ],
    );
    return store;
  }

  final theSwitch = find.byType(SwitchListTile);

  /// Moves the switch and draws one frame — never settling, since a change out
  /// draws a progress mark that never stops turning.
  Future<void> flip(WidgetTester tester) async {
    await tester.tap(theSwitch);
    await tester.pump();
  }

  /// The reader leaving the field — the keyboard's own done, which is what
  /// takes the focus off it and so what the commit hangs on.
  Future<void> leaveTheField(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  /// The last change out answered, and the frames that follow it drawn.
  Future<void> answer(WidgetTester tester) async {
    offerings.out.last.complete();
    await tester.pumpAndSettle();
  }

  final deviceField = field('Device name');

  group('the way a bar travels', () {
    testWidgets('names the bar it is acting on, in its own title', (
      tester,
    ) async {
      await pumpRoom(tester);
      expect(find.widgetWithText(AppBar, 'Share "Home bar"'), findsOneWidget);
      expect(find.text('Enable LAN'), findsOneWidget);
    });

    testWidgets('the switch offers the bar and announces it', (tester) async {
      final store = await pumpRoom(tester);
      await flip(tester);
      await answer(tester);
      expect(offerings.offered, [(id: 'test01', name: 'Home bar')]);
      // The record moves first and the network second (ADR 22).
      expect(store.savedShelf?.bars.first.offeredBy(Transport.lan), isTrue);
      expect(tester.widget<SwitchListTile>(theSwitch).value, isTrue);
    });

    testWidgets('turning it off withdraws it and nothing else', (tester) async {
      await pumpRoom(tester, bars: [testBar()]);
      await flip(tester);
      await answer(tester);
      await flip(tester);
      await answer(tester);
      expect(offerings.withdrawn, ['test01']);
      expect(tester.widget<SwitchListTile>(theSwitch).value, isFalse);
    });

    /// The reader has moved it already, and a control that slid back under
    /// them would be a lie about what is happening.
    testWidgets('a change still out offers no switch to move', (tester) async {
      await pumpRoom(tester);
      await flip(tester);
      expect(theSwitch, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await answer(tester);
      expect(theSwitch, findsOneWidget);
    });
  });

  group('what this device is called', () {
    testWidgets('starts at what the phone calls itself', (tester) async {
      await pumpRoom(tester, phone: "Nikita's phone");
      expect(
        tester.widget<TextField>(deviceField).controller?.text,
        "Nikita's phone",
      );
    });

    testWidgets('leaving the field names the device', (tester) async {
      final store = await pumpRoom(tester);
      await typeInto(tester, deviceField, 'ZEN');
      await leaveTheField(tester);
      expect(store.savedShelf?.deviceName, 'ZEN');
    });

    /// A blank field is no name at all, so it gives back the one that stood
    /// rather than leaving the device nameless.
    testWidgets('a blank field gives back the name that stood', (tester) async {
      final store = await pumpRoom(tester, phone: 'Pixel 8');
      await typeInto(tester, deviceField, '');
      await leaveTheField(tester);
      expect(tester.widget<TextField>(deviceField).controller?.text, 'Pixel 8');
      expect(store.savedShelf?.deviceName, isNull);
    });

    testWidgets('is locked while this bar is announced', (tester) async {
      await pumpRoom(tester);
      expect(tester.widget<TextField>(deviceField).enabled, isTrue);
      expect(find.text('Turn sharing off to rename.'), findsNothing);
      await flip(tester);
      await answer(tester);
      expect(tester.widget<TextField>(deviceField).enabled, isFalse);
      expect(find.text('Turn sharing off to rename.'), findsOneWidget);
    });

    /// One announcement covers every bar the device offers, so the lock is
    /// device-wide even where the switch on show is off (ADR 28).
    testWidgets('is locked by another bar, and says which', (tester) async {
      await pumpRoom(tester, bars: [testBar(), beach]);
      // Shared from its own room, which is the only way a bar comes to be one:
      // nothing arrives already offered (FR-BAR-6). Not awaited, since the
      // offer stays out until the double is told to answer it — and time has
      // to move for the record to reach the screen, a provider's refresh
      // riding a timer that a frame alone does not deliver.
      unawaited(
        container
            .read(shelfProvider.notifier)
            .offerBar(beach.id, Transport.lan),
      );
      await tester.pump(Duration.zero);
      offerings.out.last.complete();
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      expect(tester.widget<SwitchListTile>(theSwitch).value, isFalse);
      expect(tester.widget<TextField>(deviceField).enabled, isFalse);
      expect(
        find.text('Another bar is shared. Turn sharing off to rename.'),
        findsOneWidget,
      );
    });
  });

  group('what a failure says', () {
    testWidgets('an announcement that failed leaves the offer standing', (
      tester,
    ) async {
      final store = await pumpRoom(tester);
      offerings.refusing = Exception('no network');
      await flip(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Shared, but this device could not announce it.'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(theSwitch).value, isTrue);
      expect(store.savedShelf?.bars.first.offeredBy(Transport.lan), isTrue);
    });

    testWidgets('a withdrawal that failed says the network was not told', (
      tester,
    ) async {
      await pumpRoom(tester);
      await flip(tester);
      await answer(tester);
      offerings.refusing = Exception('no network');
      await flip(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Withdrawn, but the network could not be told.'),
        findsOneWidget,
      );
      expect(tester.widget<SwitchListTile>(theSwitch).value, isFalse);
    });
  });
}
