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
