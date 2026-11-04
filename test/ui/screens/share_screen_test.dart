/// The room a bar is shared from (FR-BAR-6, docs/ui-design.md#sharing): the
/// bar's name, the file it leaves as, and the switch that offers and withdraws
/// it over the LAN beside the name the device is announced under (ADR 28) — the
/// one control on the screen the reader may not always move.
library;

import 'dart:async';

import 'package:cocktails/data/data.dart';
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

  /// [of] is the bar the room opens on, the one on show where it is left out —
  /// a bar card's ⋮ opens the same room on one that is not.
  Future<MemoryBarStore> pumpRoom(
    WidgetTester tester, {
    List<Bar>? bars,
    String? of,
    String phone = 'Pixel 8',
    Future<void> Function(String)? sharer,
    bool lan = true,
  }) async {
    offerings = MemoryOfferings();
    final shelf = bars ?? [testBar()];
    final store = MemoryBarStore.over(shelf, {
      for (final bar in shelf) bar.id: smallCollection,
    });
    container = await pumpScreen(
      tester,
      ShareScreen(of ?? shelf.first.id),
      store: store,
      sharer: sharer,
      overrides: [
        platformNameProvider.overrideWithValue(phone),
        offeringsProvider.overrideWithValue({
          if (lan) Transport.lan: offerings,
        }),
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
  final nameOfBar = field('Bar name');

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

  group('what the bar is called', () {
    testWidgets('starts at the bar\'s own name', (tester) async {
      await pumpRoom(tester);
      expect(tester.widget<TextField>(nameOfBar).controller?.text, 'Home bar');
    });

    /// The bar's one name, so the title, the card and what a guest browses all
    /// follow it from the one record (FR-BAR-1/3).
    testWidgets('leaving the field renames the bar itself', (tester) async {
      final store = await pumpRoom(tester);
      await typeInto(tester, nameOfBar, 'Cellar');
      await leaveTheField(tester);
      expect(store.savedShelf?.bars.first.name, 'Cellar');
      expect(find.widgetWithText(AppBar, 'Share "Cellar"'), findsOneWidget);
    });

    testWidgets('a field only looked at renames nothing', (tester) async {
      final store = await pumpRoom(tester);
      await tester.tap(nameOfBar);
      await leaveTheField(tester);
      expect(store.savedShelf?.bars.first.name, 'Home bar');
    });

    testWidgets('a blank field gives back the name that stood', (tester) async {
      final store = await pumpRoom(tester);
      await typeInto(tester, nameOfBar, '');
      await leaveTheField(tester);
      expect(tester.widget<TextField>(nameOfBar).controller?.text, 'Home bar');
      expect(store.savedShelf?.bars.first.name, 'Home bar');
    });

    /// FR-BAR-1: the rule the rename dialog keeps, said under the field while
    /// the name is typed and kept when the reader leaves it.
    testWidgets('an owned bar\'s name that clashes is refused', (tester) async {
      final beach = Bar(id: 'test02', name: 'Beach bar', mode: BarMode.owner);
      final store = await pumpRoom(tester, bars: [testBar(), beach]);
      await typeInto(tester, nameOfBar, 'beach BAR');
      expect(find.text('Duplicate bar name: "beach BAR"'), findsOneWidget);
      await leaveTheField(tester);
      expect(tester.widget<TextField>(nameOfBar).controller?.text, 'Home bar');
      expect(store.savedShelf?.bars.first.name, 'Home bar');
    });

    /// A guest bar's name is a label on someone else's collection, and clashes
    /// with nothing (FR-BAR-1, FR-BAR-3).
    testWidgets('a guest bar takes any name, and clashes with none', (
      tester,
    ) async {
      final store = await pumpRoom(tester, bars: [testGuestBar(), testBar()]);
      await typeInto(tester, nameOfBar, 'Home bar');
      expect(find.textContaining('Duplicate'), findsNothing);
      await leaveTheField(tester);
      expect(store.savedShelf?.bars.first.name, 'Home bar');
    });

    /// The list a guest browses names the bar, so a rename mid-offer reaches it
    /// — and the device's name, which a guest's source keeps, stays locked.
    testWidgets('a bar on offer is listed under its new name', (tester) async {
      await pumpRoom(tester);
      await flip(tester);
      await answer(tester);
      await typeInto(tester, nameOfBar, 'Cellar');
      await leaveTheField(tester);
      offerings.out.last.complete();
      await tester.pumpAndSettle();
      expect(offerings.offered.last, (id: 'test01', name: 'Cellar'));
      expect(tester.widget<TextField>(nameOfBar).enabled, isTrue);
      expect(tester.widget<TextField>(deviceField).enabled, isFalse);
    });
  });

  group('the file the bar leaves as', () {
    Future<List<String>> exportOver(
      WidgetTester tester, {
      Future<void> Function(String)? sharer,
      List<Bar>? bars,
      String? of,
    }) async {
      final shared = <String>[];
      await pumpRoom(
        tester,
        bars: bars,
        of: of,
        sharer: sharer ?? (location) async => shared.add(location),
      );
      await tap(tester, find.text('Export as file'));
      return shared;
    }

    testWidgets('hands the copy to the system\'s sheet (FR-DAT-1)', (
      tester,
    ) async {
      expect(await exportOver(tester), ['memory:share']);
    });

    testWidgets('acts where it stands, saying nothing once the sheet opened', (
      tester,
    ) async {
      await exportOver(tester);
      expect(find.widgetWithText(AppBar, 'Share "Home bar"'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed export is the only thing that speaks', (
      tester,
    ) async {
      await exportOver(
        tester,
        sharer: (_) async => throw Exception('no room on disk'),
      );
      expect(find.textContaining('Could not export'), findsOneWidget);
      expect(find.textContaining('no room on disk'), findsOneWidget);
    });

    testWidgets('an Error is a failure too, not silence', (tester) async {
      await exportOver(tester, sharer: (_) async => throw StateError('adrift'));
      expect(find.textContaining('Could not export'), findsOneWidget);
    });

    /// A guest already holds what the file would carry (FR-DAT-1, FR-BAR-4).
    testWidgets('works on a guest bar', (tester) async {
      expect(await exportOver(tester, bars: [testGuestBar()]), [
        'memory:share',
      ]);
    });

    /// The room takes its bar by id, so the file is that bar's rather than the
    /// one on show.
    testWidgets('is the bar the room was opened on, not the one on show', (
      tester,
    ) async {
      final beach = Bar(id: 'test02', name: 'Beach bar', mode: BarMode.owner);
      final store = await pumpRoom(
        tester,
        bars: [testBar(), beach],
        of: beach.id,
        sharer: (_) async {},
      );
      await tap(tester, find.text('Export as file'));
      expect(store.snapshots[ExportPurpose.share]?.$1.id, beach.id);
    });
  });

  group('a guest bar in the room', () {
    /// FR-BAR-6: the same way the same switch, a guest already handing the
    /// collection over as a file.
    testWidgets('is offered over the LAN like an owned one', (tester) async {
      final store = await pumpRoom(tester, bars: [testGuestBar()]);
      expect(find.widgetWithText(AppBar, 'Share "Ada\'s bar"'), findsOneWidget);
      await flip(tester);
      await answer(tester);
      expect(offerings.offered, [(id: 'guest1', name: "Ada's bar")]);
      expect(store.savedShelf?.bars.first.offeredBy(Transport.lan), isTrue);
      expect(tester.widget<SwitchListTile>(theSwitch).value, isTrue);
    });
  });

  group('where this build has no LAN', () {
    /// A way with no adapter is absent rather than dimmed (ADR 22); the file
    /// and the name stand, so the room is never empty.
    testWidgets('only the LAN\'s own controls are absent', (tester) async {
      await pumpRoom(tester, lan: false);
      expect(find.text('Enable LAN'), findsNothing);
      expect(deviceField, findsNothing);
      expect(nameOfBar, findsOneWidget);
      expect(find.text('Export as file'), findsOneWidget);
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
      expect(find.byType(SnackBar), findsOneWidget);
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
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.widget<SwitchListTile>(theSwitch).value, isFalse);
    });
  });
}
