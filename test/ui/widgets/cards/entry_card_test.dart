/// The row a list draws for one entry, and the overflow menu it carries —
/// which is drawn only when there is something in it to open.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/widgets/cards/entry_card.dart';
import 'package:cocktails/ui/widgets/chips/color_marks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A card with the chip a guest's ingredient row wears, over [menu].
  Future<void> pumpCard(WidgetTester tester, {RowMenu? menu}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EntryCard(
              title: const Text('Home bar'),
              trailing: const StockChip(StockLevel.in_),
              menu: menu,
            ),
          ),
        ),
      );

  /// How far the text stands from the card's edge, and [what] from the other.
  double textInset(WidgetTester tester) =>
      tester.getRect(find.text('Home bar')).left -
      tester.getRect(find.byType(Card)).left;

  double fromRightEdge(WidgetTester tester, Finder what) =>
      tester.getRect(find.byType(Card)).right - tester.getRect(what).right;

  group('a menu beside the text', () {
    final menu = RowMenu({'Rename': () {}});

    testWidgets('its glyph box stands as far from the card as the text does', (
      tester,
    ) async {
      await pumpCard(tester, menu: menu);
      expect(
        fromRightEdge(tester, find.byIcon(Icons.more_vert)),
        textInset(tester),
      );
    });

    testWidgets('the dots are centred in the button', (tester) async {
      await pumpCard(tester, menu: menu);
      expect(
        tester.getCenter(find.byIcon(Icons.more_vert)),
        tester.getCenter(find.byType(IconButton)),
      );
    });

    testWidgets('the chip stands a card padding clear of the glyph box', (
      tester,
    ) async {
      await pumpCard(tester, menu: menu);
      const cardPadding = 16.0;
      expect(
        tester.getRect(find.byIcon(Icons.more_vert)).left -
            tester.getRect(find.byType(StockChip)).right,
        cardPadding,
      );
    });

    testWidgets('the button is still a fingertip across', (tester) async {
      await pumpCard(tester, menu: menu);
      expect(
        tester.getSize(find.byType(IconButton)),
        const Size.square(kMinInteractiveDimension),
      );
    });
  });

  group('a chip with no menu beside it', () {
    for (final (what, menu) in [
      ('none at all', null),
      ('one with nothing in it', const RowMenu({})),
    ]) {
      testWidgets('stands as far from the card as the text does: $what', (
        tester,
      ) async {
        await pumpCard(tester, menu: menu);
        expect(
          fromRightEdge(tester, find.byType(StockChip)),
          textInset(tester),
        );
      });
    }
  });

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
