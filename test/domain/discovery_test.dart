import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const gin = RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.base);
  const rumOrVodka = RecipeLine(Amount(1), 'part', [
    'white rum',
    'vodka',
  ], mark: LineMark.base);
  const campari = RecipeLine(Amount(1), 'part', ['campari']);

  Recipe builtOn(List<RecipeLine> lines) => Recipe('Negroni', lines: lines);

  group('basesOf', () {
    test('takes the bottles off base lines and no others', () {
      expect(basesOf(builtOn(const [gin, campari])), {'gin'});
    });

    test('takes every alternative of a marked group (ADR 11)', () {
      expect(basesOf(builtOn(const [rumOrVodka])), {'white rum', 'vodka'});
    });

    test('takes every base line, a recipe being allowed more than one', () {
      expect(basesOf(builtOn(const [gin, rumOrVodka])), {
        'gin',
        'white rum',
        'vodka',
      });
    });

    test('is empty where nothing is marked', () {
      expect(basesOf(builtOn(const [campari])), isEmpty);
    });
  });

  group('baseSpirits', () {
    Model collection(List<Recipe> recipes, {List<Ingredient>? bottles}) =>
        Model(
          ingredients: bottles ?? [Ingredient('gin'), Ingredient('white rum')],
          recipes: recipes,
        );

    test('reads A→Z, ignoring case', () {
      expect(
        baseSpirits(
          collection([
            builtOn(const [rumOrVodka]),
            Recipe('Martini', lines: const [gin]),
          ]),
        ),
        ['gin', 'vodka', 'white rum'],
      );
    });

    test('names a bottle once however many recipes are built on it', () {
      expect(
        baseSpirits(
          collection([
            builtOn(const [gin]),
            Recipe('Martini', lines: const [gin]),
          ]),
        ),
        ['gin'],
      );
    });

    test('names a bottle once across its spellings (ADR 10)', () {
      expect(
        baseSpirits(
          collection(
            [
              builtOn(const [gin]),
              Recipe(
                'Martini',
                lines: const [
                  RecipeLine(Amount(1), 'part', [
                    'london dry',
                  ], mark: LineMark.base),
                ],
              ),
            ],
            bottles: [
              Ingredient('gin', aliases: const ['london dry']),
            ],
          ),
        ),
        ['gin'],
      );
    });

    test('answers in the vocabulary spelling, not the line one (ADR 08)', () {
      expect(
        baseSpirits(
          collection(
            [
              builtOn(const [
                RecipeLine(Amount(1), 'part', ['GIN'], mark: LineMark.base),
              ]),
            ],
            bottles: [Ingredient('Gin')],
          ),
        ),
        ['Gin'],
      );
    });

    test('is empty where no recipe marks a base', () {
      expect(
        baseSpirits(
          collection([
            builtOn(const [campari]),
          ]),
        ),
        isEmpty,
      );
    });
  });

  group('marksBase', () {
    test('matches a spirit whatever case it is asked in', () {
      expect(marksBase(builtOn(const [gin]), 'Gin'), isTrue);
    });

    test('matches on any alternative of a marked group', () {
      expect(marksBase(builtOn(const [rumOrVodka]), 'vodka'), isTrue);
    });

    test('does not match a bottle the recipe only uses', () {
      expect(marksBase(builtOn(const [gin, campari]), 'campari'), isFalse);
    });

    test('a null spirit asks for the recipes marking no base', () {
      expect(marksBase(builtOn(const [campari]), null), isTrue);
      expect(marksBase(builtOn(const [gin]), null), isFalse);
    });
  });
}
