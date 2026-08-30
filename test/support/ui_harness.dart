/// The pump/scope machinery every UI suite starts from: the overrides that
/// put a widget test over the real state layer and an in-memory store, and
/// the app/screen pumped past its startup load — what changes when a test
/// needs a new way to stand a widget up (docs/components.md#testing).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:cocktails/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_bar_store.dart';
import 'ui_finders.dart';
import 'ui_fixtures.dart';

/// The overrides the composition root makes, so a widget test reaches the real
/// state layer over an in-memory store — and over the three seams data crosses
/// the edge by: [sharer] where a copy goes out to the system's sheet, [picker]
/// where a file comes back off it, [clock] where the reader's own moves
/// (ADR 18). [overrides] is the escape hatch for whatever else a test needs
/// wired in beyond those — a fake `channelsProvider`, say.
List<Override> _overrides(
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
  List<Override> overrides,
) => [
  barStoreProvider.overrideWithValue(store ?? MemoryBarStore.of(testBar())),
  clockProvider.overrideWithValue(clock ?? () => testNow),
  if (sharer != null) sharerProvider.overrideWithValue(sharer),
  if (picker != null) filePickerProvider.overrideWithValue(picker),
  ...overrides,
];

/// [widget] under those overrides, meeting the startup load itself — which is
/// what the app does and what only the app does.
Widget scoped(
  Widget widget, {
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: _overrides(store, sharer, picker, clock, overrides),
  child: widget,
);

/// The whole app, pumped past its startup load.
Future<void> pumpApp(
  WidgetTester tester, {
  BarStore? store,
  Future<String?> Function()? picker,
  DateTime Function()? clock,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    scoped(
      const CocktailsApp(),
      store: store,
      picker: picker,
      clock: clock,
      overrides: overrides,
    ),
  );
  await tester.pumpAndSettle();
}

/// One screen on its own, over a shelf that has already answered — under the
/// app's own theme, so a screen is judged in the ink it will actually be drawn
/// in. The load is awaited before the first frame rather than met in one: the
/// shell draws no screen until it has landed (docs/ui-design.md#app-shell), so
/// a screen pumped over an unanswered shelf is a state the app cannot reach.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  BarStore? store,
  Future<void> Function(String)? sharer,
  Future<String?> Function()? picker,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: _overrides(store, sharer, picker, null, overrides),
  );
  addTearDown(container.dispose);
  await container.read(shelfProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: cocktailsTheme(Brightness.light),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// [screen] over a store seeded with [collection], handing that store back so
/// the test can read what reached it. The one way a screen test starts.
Future<MemoryBarStore> pumpOver(
  WidgetTester tester,
  Widget screen,
  Collection collection, {
  FixedUnit display = FixedUnit.part,
  Bar? bar,
  List<Override> overrides = const [],
}) async {
  final store = MemoryBarStore.of(bar ?? testBar(display: display), collection);
  await pumpScreen(tester, screen, store: store, overrides: overrides);
  return store;
}

/// The whole shell over [bar], pumped past its startup load — [picker] being
/// what the system's file picker answers a refresh with (FR-BAR-7). The one way
/// a test reaches behaviour that only exists once the shell is standing.
Future<void> pumpShell(
  WidgetTester tester,
  Bar bar, {
  Collection? collection,
  Future<String?> Function()? picker,
}) => pumpApp(
  tester,
  store: MemoryBarStore.of(bar, collection ?? recipeCollection),
  picker: picker,
);

/// FR-BAR-4, shared by every list screen a guest can only read: no way to add
/// an entry, and no menu on [row], already there. What a guest bar restricts
/// beyond this stays in that screen's own test file.
void guestListOffersNoWrite(
  Widget Function() screenOf,
  Collection collection,
  String row,
) {
  testWidgets('offers no way to add, or to reach $row\'s menu', (tester) async {
    await pumpOver(tester, screenOf(), collection, bar: testGuestBar());
    expect(find.widgetWithIcon(FloatingActionButton, Icons.add), findsNothing);
    expect(rowMenu(row), findsNothing);
  });
}
