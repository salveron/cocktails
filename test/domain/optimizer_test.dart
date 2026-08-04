import 'dart:math';

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecipeLine line(List<String> ingredients, {LineMark? mark}) =>
      RecipeLine(const Amount(1), 'part', ingredients, mark: mark);

  Model bar(
    Map<String, StockLevel> stock,
    Map<String, List<RecipeLine>> book,
  ) => Model(
    ingredients: [
      for (final entry in stock.entries)
        Ingredient(entry.key, stock: entry.value),
    ],
    recipes: [
      for (final entry in book.entries) Recipe(entry.key, lines: entry.value),
    ],
  );

  const inStock = StockLevel.in_;
  const low = StockLevel.low;
  const out = StockLevel.out;

  group('purchasesWithin', () {
    test('one bottle closing the only gap unlocks its recipe', () {
      final model = bar(
        {'gin': inStock, 'campari': out},
        {
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      expect(purchasesWithin(model, 1), [
        Purchase(['campari'], ['Negroni']),
      ]);
    });

    test('a recipe short of more bottles than the budget is out of reach', () {
      final model = bar(
        {'rum': out, 'lime juice': out},
        {
          'Daiquiri': [
            line(['rum']),
            line(['lime juice']),
          ],
        },
      );
      expect(purchasesWithin(model, 1), isEmpty);
      expect(purchasesWithin(model, 2), [
        Purchase(['lime juice', 'rum'], ['Daiquiri']),
      ]);
    });

    test('ranks by recipes unlocked, most first', () {
      final model = bar(
        {'gin': inStock, 'lime juice': out, 'campari': out},
        {
          'Gimlet': [
            line(['gin']),
            line(['lime juice']),
          ],
          'Southside': [
            line(['gin']),
            line(['lime juice']),
          ],
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      final ranked = purchasesWithin(model, 1);
      expect(ranked.first, Purchase(['lime juice'], ['Gimlet', 'Southside']));
      expect(ranked.last, Purchase(['campari'], ['Negroni']));
    });

    test('gathers gaps from different recipes into one basket', () {
      final model = bar(
        {'gin': inStock, 'lime juice': out, 'campari': out},
        {
          'Gimlet': [
            line(['gin']),
            line(['lime juice']),
          ],
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      expect(
        purchasesWithin(model, 2).first,
        Purchase(['campari', 'lime juice'], ['Gimlet', 'Negroni']),
      );
    });

    // The one bottle sorts *after* the two, so only the rule on size can put
    // it first — alphabetical order alone would not.
    test('a smaller basket wins a tie on recipes unlocked', () {
      final model = bar(
        {'gin': inStock, 'sugar': out, 'aperol': out, 'bitters': out},
        {
          'Old Fashioned': [
            line(['gin']),
            line(['sugar']),
          ],
          'Spritz': [
            line(['aperol']),
            line(['bitters']),
          ],
        },
      );
      final ranked = purchasesWithin(model, 3);
      expect(ranked.first.unlocks, ['Old Fashioned', 'Spritz']);
      final tied = ranked.where((p) => p.unlocks.length == 1).toList();
      expect(tied, [
        Purchase(['sugar'], ['Old Fashioned']),
        Purchase(['aperol', 'bitters'], ['Spritz']),
      ]);
    });

    test('a basket beaten by one of its own parts is dropped', () {
      final model = bar(
        {'gin': out, 'vodka': out, 'lime juice': inStock},
        {
          'Sour': [
            line(['gin', 'vodka']),
            line(['lime juice']),
          ],
        },
      );
      expect(purchasesWithin(model, 2), [
        Purchase(['gin'], ['Sour']),
        Purchase(['vodka'], ['Sour']),
      ]);
    });

    test('keeps only the best few of each size', () {
      final model = bar(
        {'gin': inStock, 'lime juice': out, 'campari': out, 'rum': out},
        {
          'Gimlet': [
            line(['gin']),
            line(['lime juice']),
          ],
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
          'Daiquiri': [
            line(['gin']),
            line(['rum']),
          ],
        },
      );
      expect(purchasesWithin(model, 1).length, 3);
      expect(purchasesWithin(model, 1, most: 1), [
        Purchase(['campari'], ['Negroni']),
      ]);
    });

    test('carries no bottle that closes nothing', () {
      final model = bar(
        {'gin': inStock, 'lime juice': out, 'campari': out},
        {
          'Gimlet': [
            line(['gin']),
            line(['lime juice']),
          ],
        },
      );
      expect(
        purchasesWithin(model, 3).every((p) => p.unlocks.isNotEmpty),
        true,
      );
      expect(
        purchasesWithin(model, 3).map((p) => p.bottles),
        everyElement(isNot(contains('campari'))),
      );
    });

    test('offers each alternative of a group its own basket (ADR 11)', () {
      final model = bar(
        {'lime juice': inStock, 'rum': out, 'vodka': out},
        {
          'Daiquiri': [
            line(['lime juice']),
            line(['rum', 'vodka']),
          ],
        },
      );
      expect(purchasesWithin(model, 1), [
        Purchase(['rum'], ['Daiquiri']),
        Purchase(['vodka'], ['Daiquiri']),
      ]);
    });

    test('a group already holding one bottle is short of nothing', () {
      final model = bar(
        {'lime juice': inStock, 'rum': out, 'vodka': inStock},
        {
          'Daiquiri': [
            line(['lime juice']),
            line(['rum', 'vodka']),
          ],
        },
      );
      expect(purchasesWithin(model, 3), isEmpty);
    });

    test('a low bottle counts as on hand and is not bought (ADR 16)', () {
      final model = bar(
        {'gin': low, 'campari': out},
        {
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      expect(purchasesWithin(model, 2), [
        Purchase(['campari'], ['Negroni']),
      ]);
    });

    test('an optional line is never bought for (FR-REC-3)', () {
      final model = bar(
        {'gin': inStock, 'absinthe': out},
        {
          'Martini': [
            line(['gin']),
            line(['absinthe'], mark: LineMark.optional),
          ],
        },
      );
      expect(purchasesWithin(model, 2), isEmpty);
    });

    test('a base line is bought for like any other (ADR 06)', () {
      final model = bar(
        {'gin': out, 'lime juice': inStock},
        {
          'Gimlet': [
            line(['gin'], mark: LineMark.base),
            line(['lime juice']),
          ],
        },
      );
      expect(purchasesWithin(model, 1), [
        Purchase(['gin'], ['Gimlet']),
      ]);
    });

    test('a recipe already makeable is never counted as unlocked', () {
      final model = bar(
        {'gin': inStock, 'campari': out},
        {
          'Martini': [
            line(['gin']),
          ],
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      expect(purchasesWithin(model, 3), [
        Purchase(['campari'], ['Negroni']),
      ]);
    });

    test('buys a bottle under its own name, whatever the line calls it', () {
      final model = Model(
        ingredients: [
          Ingredient('rum', aliases: ['white rum']),
        ],
        recipes: [
          Recipe(
            'Daiquiri',
            lines: [
              line(['WHITE RUM']),
            ],
          ),
        ],
      );
      expect(purchasesWithin(model, 1), [
        Purchase(['rum'], ['Daiquiri']),
      ]);
    });

    test('a budget below one buys nothing', () {
      final model = bar(
        {'campari': out},
        {
          'Negroni': [
            line(['campari']),
          ],
        },
      );
      expect(purchasesWithin(model, 0), isEmpty);
    });

    test('nothing missing is nothing to buy', () {
      final model = bar(
        {'gin': inStock},
        {
          'Martini': [
            line(['gin']),
          ],
        },
      );
      expect(purchasesWithin(model, 3), isEmpty);
    });
  });

  group('purchasesWithin, restocking (ADR 16)', () {
    test('reaches a recipe the bar can already make', () {
      final model = bar(
        {'gin': low, 'vermouth': inStock},
        {
          'Martini': [
            line(['gin']),
            line(['vermouth']),
          ],
        },
      );
      expect(purchasesWithin(model, 1), isEmpty);
      expect(purchasesWithin(model, 1, restocking: true), [
        Purchase(['gin'], ['Martini']),
      ]);
    });

    // The bottle that is merely low counts against the budget like any other,
    // so neither half of the pair answers on its own.
    test('spends the budget on the low bottle beside the missing one', () {
      final model = bar(
        {'gin': low, 'campari': out},
        {
          'Negroni': [
            line(['gin']),
            line(['campari']),
          ],
        },
      );
      expect(purchasesWithin(model, 2, restocking: true), [
        Purchase(['campari', 'gin'], ['Negroni']),
      ]);
    });

    test('takes any alternative of a group short of full stock (ADR 11)', () {
      final model = bar(
        {'lime juice': inStock, 'rum': low, 'vodka': out},
        {
          'Daiquiri': [
            line(['lime juice']),
            line(['rum', 'vodka']),
          ],
        },
      );
      expect(purchasesWithin(model, 1, restocking: true), [
        Purchase(['rum'], ['Daiquiri']),
        Purchase(['vodka'], ['Daiquiri']),
      ]);
    });

    test('leaves a fully stocked recipe alone', () {
      final model = bar(
        {'gin': inStock},
        {
          'Martini': [
            line(['gin']),
          ],
        },
      );
      expect(purchasesWithin(model, 3, restocking: true), isEmpty);
    });

    test('still never buys for an optional line (FR-REC-3)', () {
      final model = bar(
        {'gin': inStock, 'absinthe': low},
        {
          'Martini': [
            line(['gin']),
            line(['absinthe'], mark: LineMark.optional),
          ],
        },
      );
      expect(purchasesWithin(model, 2, restocking: true), isEmpty);
    });
  });

  group('at NFR-2 scale', () {
    // [withLow] turns a fifth of the shelf from out to low, one draw per bottle
    // either way — so what restocking adds to the pool is measured against the
    // very collection the plain reading leaves alone.
    Model collection({
      required int recipes,
      required int bottles,
      int seed = 7,
      bool withLow = false,
    }) {
      final random = Random(seed);
      final names = [for (var i = 0; i < bottles; i++) 'bottle $i'];
      return Model(
        ingredients: [
          for (final name in names)
            Ingredient(
              name,
              stock: switch (random.nextInt(5)) {
                0 || 1 => inStock,
                2 when withLow => low,
                _ => out,
              },
            ),
        ],
        recipes: [
          for (var i = 0; i < recipes; i++)
            Recipe(
              'recipe $i',
              lines: [
                for (var j = 0; j < 3 + random.nextInt(3); j++)
                  line(
                    {
                      names[random.nextInt(bottles)],
                      if (random.nextInt(4) == 0)
                        names[random.nextInt(bottles)],
                    }.toList(),
                  ),
              ],
            ),
        ],
      );
    }

    test('answers a three-bottle budget over hundreds of recipes', () {
      final model = collection(recipes: 400, bottles: 120);
      final watch = Stopwatch()..start();
      final ranked = purchasesWithin(model, 3);
      watch.stop();
      // ignore: avoid_print
      print(
        'purchasesWithin(400 recipes, 120 bottles, N=3): '
        '${ranked.length} baskets in ${watch.elapsedMilliseconds}ms',
      );
      expect(ranked, isNotEmpty);
      expect(ranked.length, lessThanOrEqualTo(75));
      // A guard against an algorithmic regression, not a stopwatch on the
      // machine: the search this replaced took 6.8s here (M21 notes).
      expect(watch.elapsedMilliseconds, lessThan(750));
    });

    // Restocking is the expensive reading: every bottle running low joins the
    // pool, and ADR 15's cost grows with the cube of it. Both readings are
    // timed over the one collection, so the print says what the switch costs.
    test('answers either reading of what is short (ADR 16)', () {
      final model = collection(recipes: 400, bottles: 120, withLow: true);
      for (final restocking in [false, true]) {
        final watch = Stopwatch()..start();
        final ranked = purchasesWithin(model, 3, restocking: restocking);
        watch.stop();
        // ignore: avoid_print
        print(
          'purchasesWithin(400 recipes, 120 bottles, N=3, '
          'restocking: $restocking): ${ranked.length} baskets in '
          '${watch.elapsedMilliseconds}ms',
        );
        expect(ranked, isNotEmpty);
        expect(ranked.length, lessThanOrEqualTo(75));
        expect(watch.elapsedMilliseconds, lessThan(750));
      }
    });

    test('the best answers survive the cap on how many are kept', () {
      final model = collection(recipes: 120, bottles: 40);
      final all = purchasesWithin(model, 3, most: 100000);
      final capped = purchasesWithin(model, 3, most: 5);
      expect(capped.length, lessThan(all.length));
      expect(capped.first, all.first);
      expect(
        capped.take(5).map((p) => p.unlocks.length),
        all.take(5).map((p) => p.unlocks.length),
      );
    });
  });
}
