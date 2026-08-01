import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bar = Model(
    ingredients: [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari', stock: StockLevel.low),
      Ingredient('sweet vermouth'),
    ],
  );

  const gin = RecipeLine(Amount(1), 'part', 'gin');
  const campari = RecipeLine(Amount(1), 'part', 'campari');
  const vermouth = RecipeLine(Amount(1), 'part', 'sweet vermouth');

  Availability of(List<RecipeLine> lines) =>
      availabilityOf(bar, Recipe('Negroni', lines: lines));

  group('availabilityOf', () {
    test('everything required in stock is makeable', () {
      expect(of(const [gin]), Availability.makeable);
    });

    test('nothing out and something low is makeable-low', () {
      expect(of(const [gin, campari]), Availability.makeableLow);
    });

    test('one line out is missing, whatever else is in', () {
      expect(of(const [gin, campari, vermouth]), Availability.missing);
    });

    test('a base line counts like any other required one', () {
      expect(
        of(const [
          RecipeLine(Amount(1), 'part', 'sweet vermouth', mark: LineMark.base),
        ]),
        Availability.missing,
      );
    });

    test('an optional line counts for nothing, however it stands', () {
      expect(
        of(const [
          gin,
          RecipeLine(
            Amount(1),
            'part',
            'sweet vermouth',
            mark: LineMark.optional,
          ),
          RecipeLine(Amount(1), 'part', 'campari', mark: LineMark.optional),
        ]),
        Availability.makeable,
      );
    });

    test('a bottle the vocabulary does not hold reads as out', () {
      expect(
        of(const [RecipeLine(Amount(1), 'part', 'rye')]),
        Availability.missing,
      );
    });
  });

  group('stockOf', () {
    test('answers what the vocabulary holds', () {
      expect(stockOf(bar, 'campari'), StockLevel.low);
    });

    test('a name it does not hold reads as out', () {
      expect(stockOf(bar, 'rye'), StockLevel.out);
    });

    test('a name written in another case is that bottle (ADR 08)', () {
      expect(stockOf(bar, 'CAMPARI'), StockLevel.low);
    });
  });
}
