import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bar = Collection(
    ingredients: [
      Ingredient('gin', stock: StockLevel.in_),
      Ingredient('campari', stock: StockLevel.low),
      Ingredient('sweet vermouth'),
    ],
  );

  const gin = RecipeLine(Amount(1), 'part', ['gin']);
  const campari = RecipeLine(Amount(1), 'part', ['campari']);
  const vermouth = RecipeLine(Amount(1), 'part', ['sweet vermouth']);

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
          RecipeLine(Amount(1), 'part', [
            'sweet vermouth',
          ], mark: LineMark.base),
        ]),
        Availability.missing,
      );
    });

    test('an optional line counts for nothing, however it stands', () {
      expect(
        of(const [
          gin,
          RecipeLine(Amount(1), 'part', [
            'sweet vermouth',
          ], mark: LineMark.optional),
          RecipeLine(Amount(1), 'part', ['campari'], mark: LineMark.optional),
        ]),
        Availability.makeable,
      );
    });

    test('an ingredient the vocabulary does not hold reads as out', () {
      expect(
        of(const [
          RecipeLine(Amount(1), 'part', ['rye']),
        ]),
        Availability.missing,
      );
    });
  });

  group('stockOfLine (ADR 11)', () {
    StockLevel stockOf3(List<String> ingredients) =>
        stockOfLine(bar, RecipeLine(const Amount(1), 'part', ingredients));

    test(
      'one ingredient on hand makes the line, whatever it stands beside',
      () {
        expect(stockOf3(['sweet vermouth', 'gin']), StockLevel.in_);
        expect(stockOf3(['gin', 'sweet vermouth']), StockLevel.in_);
      },
    );

    test('the best of what is left carries it', () {
      expect(stockOf3(['sweet vermouth', 'campari']), StockLevel.low);
    });

    test('a group with nothing on hand is out', () {
      expect(stockOf3(['sweet vermouth', 'rye']), StockLevel.out);
    });

    test('one ingredient answers as it always did', () {
      expect(stockOf3(['campari']), StockLevel.low);
    });
  });

  group('availabilityOf over groups (ADR 11)', () {
    test('a group with one ingredient on hand makes the recipe', () {
      expect(
        of(const [
          gin,
          RecipeLine(Amount(1), 'part', ['sweet vermouth', 'campari']),
        ]),
        Availability.makeableLow,
      );
    });

    test('what would have been missing is makeable through the choice', () {
      expect(
        of(const [
          RecipeLine(Amount(1), 'part', ['sweet vermouth', 'gin']),
        ]),
        Availability.makeable,
      );
    });

    test('a group short of every ingredient is still missing', () {
      expect(
        of(const [
          gin,
          RecipeLine(Amount(1), 'part', ['sweet vermouth', 'rye']),
        ]),
        Availability.missing,
      );
    });

    test('an optional group counts for nothing either', () {
      expect(
        of(const [
          gin,
          RecipeLine(Amount(1), 'part', [
            'sweet vermouth',
            'rye',
          ], mark: LineMark.optional),
        ]),
        Availability.makeable,
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

    test('a name written in another case is that ingredient (ADR 08)', () {
      expect(stockOf(bar, 'CAMPARI'), StockLevel.low);
    });
  });
}
