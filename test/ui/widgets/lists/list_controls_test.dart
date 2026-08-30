/// The chrome around a searchable list, in isolation from any screen that
/// wires it up: the field and the sort it opens, the buttons that stand over
/// the list, and what shows in place of a list a search or a filter emptied
/// (docs/ui-design.md#searchable-lists).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cocktails/ui/widgets/lists/list_controls.dart';
import 'package:cocktails/ui/widgets/lists/list_terms.dart';

Future<void> pumpControl(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  group('SearchField', () {
    testWidgets('shows the hint given it, and no clear button while empty', (
      tester,
    ) async {
      await pumpControl(
        tester,
        SearchField(controller: TextEditingController(), hintText: 'Search'),
      );
      expect(find.text('Search'), findsOneWidget);
      expect(find.byTooltip('Clear'), findsNothing);
    });

    testWidgets('a clear button appears once there is something to clear', (
      tester,
    ) async {
      final controller = TextEditingController();
      // SearchField reads controller.text once at build; a caller's own
      // rebuild is what a real screen supplies on every keystroke.
      await pumpControl(
        tester,
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) =>
              SearchField(controller: controller, hintText: 'Search'),
        ),
      );
      await tester.enterText(find.byType(TextField), 'gin');
      await tester.pump();
      expect(find.byTooltip('Clear'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();
      expect(controller.text, isEmpty);
    });

    testWidgets('the trailing widget rides beside the field', (tester) async {
      await pumpControl(
        tester,
        SearchField(
          controller: TextEditingController(),
          hintText: 'Search',
          trailing: const Icon(Icons.sort),
        ),
      );
      expect(find.byIcon(Icons.sort), findsOneWidget);
    });
  });

  group('SearchableList', () {
    SearchableList<String> control({
      bool picking = false,
      String order = 'Name',
      bool backwards = false,
      void Function(String label)? onPick,
      ListFilter<String>? filter,
    }) => SearchableList<String>(
      search: TextEditingController(),
      plural: 'things',
      picking: picking,
      onTogglePicking: () {},
      orders: const {'Name': alike, 'Size': alike},
      order: order,
      backwards: backwards,
      onPick: onPick ?? (_) {},
      filter: filter,
      list: const Text('the rows'),
    );

    testWidgets('the sort chips stay out of sight until picking opens them', (
      tester,
    ) async {
      await pumpControl(tester, control());
      expect(find.byType(FilterChip), findsNothing);
      await pumpControl(tester, control(picking: true));
      expect(find.byType(FilterChip), findsNWidgets(2));
    });

    testWidgets('only the order in force wears a direction arrow', (
      tester,
    ) async {
      await pumpControl(
        tester,
        control(picking: true, order: 'Name', backwards: false),
      );
      final name = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Name'),
      );
      final size = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Size'),
      );
      expect(name.selected, isTrue);
      expect((name.avatar! as Icon).icon, Icons.arrow_downward);
      expect(size.selected, isFalse);
      expect(size.avatar, isNull);
    });

    testWidgets('backwards reads as the upward arrow', (tester) async {
      await pumpControl(
        tester,
        control(picking: true, order: 'Name', backwards: true),
      );
      final name = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Name'),
      );
      expect((name.avatar! as Icon).icon, Icons.arrow_upward);
    });

    testWidgets('picking a chip names it, not what was already in force', (
      tester,
    ) async {
      String? picked;
      await pumpControl(
        tester,
        control(picking: true, onPick: (label) => picked = label),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Size'));
      expect(picked, 'Size');
    });

    testWidgets('a filter given rides its own row; none given leaves no row', (
      tester,
    ) async {
      await pumpControl(tester, control());
      expect(find.text('the filter row'), findsNothing);
      await pumpControl(
        tester,
        control(
          filter: (
            row: const Text('the filter row'),
            test: (_) => true,
            narrowing: null,
            picks: const [],
            tagPicks: const [],
          ),
        ),
      );
      expect(find.text('the filter row'), findsOneWidget);
    });
  });

  group('ListButtons', () {
    // Only [icon]/[tooltip] are ListButtons's own to read; [draw] itself is a
    // caller's affair once `onDraw` fires (recipes_screen.dart's own doing).
    String? noDraw(List<int> onShow) => null;
    final drawing = (
      icon: const Icon(Icons.casino),
      tooltip: 'Draw',
      draw: noDraw,
    );

    testWidgets('offers only add when there is nothing to draw from', (
      tester,
    ) async {
      await pumpControl(
        tester,
        ListButtons<int>(
          draw: drawing,
          canDraw: false,
          noun: 'thing',
          onDraw: () {},
          onAdd: () {},
        ),
      );
      expect(find.byTooltip('Draw'), findsNothing);
      expect(find.byTooltip('Add thing'), findsOneWidget);
    });

    testWidgets('offers both once there is something to draw from', (
      tester,
    ) async {
      await pumpControl(
        tester,
        ListButtons<int>(
          draw: drawing,
          canDraw: true,
          noun: 'thing',
          onDraw: () {},
          onAdd: () {},
        ),
      );
      expect(find.byTooltip('Draw'), findsOneWidget);
      expect(find.byTooltip('Add thing'), findsOneWidget);
    });

    testWidgets('a guest with no writer is offered no way to add', (
      tester,
    ) async {
      await pumpControl(
        tester,
        ListButtons<int>(
          draw: drawing,
          canDraw: true,
          noun: 'thing',
          onDraw: () {},
          onAdd: null,
        ),
      );
      expect(find.byTooltip('Draw'), findsOneWidget);
      expect(find.byTooltip('Add thing'), findsNothing);
    });

    testWidgets('each button reaches its own callback', (tester) async {
      var drawn = false;
      var added = false;
      await pumpControl(
        tester,
        ListButtons<int>(
          draw: drawing,
          canDraw: true,
          noun: 'thing',
          onDraw: () => drawn = true,
          onAdd: () => added = true,
        ),
      );
      await tester.tap(find.byTooltip('Draw'));
      await tester.tap(find.byTooltip('Add thing'));
      expect(drawn, isTrue);
      expect(added, isTrue);
    });
  });

  group('NoMatch', () {
    testWidgets('blames the search alone when only it narrowed', (
      tester,
    ) async {
      await pumpControl(
        tester,
        NoMatch(query: 'zzz', narrowing: null, noun: 'thing', onAdd: () {}),
      );
      expect(find.text('No thing here answers to "zzz".'), findsOneWidget);
    });

    testWidgets('blames the filter alone when only it narrowed', (
      tester,
    ) async {
      await pumpControl(
        tester,
        NoMatch(
          query: '',
          narrowing: 'every tag picked',
          noun: 'thing',
          onAdd: () {},
        ),
      );
      expect(
        find.text('No thing here matches every tag picked.'),
        findsOneWidget,
      );
    });

    testWidgets('blames both together when both narrowed', (tester) async {
      await pumpControl(
        tester,
        NoMatch(
          query: 'zzz',
          narrowing: 'every tag picked',
          noun: 'thing',
          onAdd: () {},
        ),
      );
      expect(
        find.text(
          'No thing here answers to "zzz" and matches every tag '
          'picked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an add is offered only for what the search typed', (
      tester,
    ) async {
      await pumpControl(
        tester,
        NoMatch(query: 'zzz', narrowing: null, noun: 'thing', onAdd: () {}),
      );
      expect(find.text('Add "zzz"'), findsOneWidget);
    });

    testWidgets('nothing to add where the query is empty', (tester) async {
      await pumpControl(
        tester,
        NoMatch(
          query: '',
          narrowing: 'every tag picked',
          noun: 'thing',
          onAdd: () {},
        ),
      );
      expect(find.textContaining('Add'), findsNothing);
    });

    testWidgets('nothing to add where a guest has no writer', (tester) async {
      await pumpControl(
        tester,
        NoMatch(query: 'zzz', narrowing: null, noun: 'thing', onAdd: null),
      );
      expect(find.textContaining('Add'), findsNothing);
    });

    testWidgets('tapping the offer reaches onAdd', (tester) async {
      var added = false;
      await pumpControl(
        tester,
        NoMatch(
          query: 'zzz',
          narrowing: null,
          noun: 'thing',
          onAdd: () => added = true,
        ),
      );
      await tester.tap(find.text('Add "zzz"'));
      expect(added, isTrue);
    });
  });
}
