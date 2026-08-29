import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  // "in" rather than the in_ the language forces, and the palette spending no
  // colour the stock and availability signals need.
  tokenVocabulary(
    'StockLevel',
    values: StockLevel.values,
    token: (value) => value.token,
    fromToken: StockLevel.fromToken,
    tokens: const ['in', 'low', 'out'],
    unknown: 'missing',
  );

  group('StockLevel.next', () {
    test('follows an ingredient: in -> low -> out -> in', () {
      expect(StockLevel.in_.next, StockLevel.low);
      expect(StockLevel.low.next, StockLevel.out);
      expect(StockLevel.out.next, StockLevel.in_);
    });
  });

  group('Ingredient', () {
    Ingredient build({
      String name = 'gin',
      StockLevel stock = StockLevel.out,
      List<String> aliases = const [],
      List<String> tags = const [],
    }) => Ingredient(name, stock: stock, aliases: aliases, tags: tags);

    test('defaults to out of stock, unaliased and untagged', () {
      final ingredient = Ingredient('bourbon');
      expect(ingredient.stock, StockLevel.out);
      expect(ingredient.aliases, isEmpty);
      expect(ingredient.tags, isEmpty);
    });

    test('answers to its own name first, then to every alias', () {
      expect(Ingredient('bourbon').spellings, ['bourbon']);
      expect(
        Ingredient('bourbon', aliases: const ['bourbon whiskey']).spellings,
        ['bourbon', 'bourbon whiskey'],
      );
    });

    valueEquality(build, {
      'name': build(name: 'rum'),
      'stock': build(stock: StockLevel.low),
      'aliases': build(aliases: const ['london dry']),
      'tags': build(tags: const ['juniper']),
    });

    final ingredient = Ingredient(
      'gin',
      stock: StockLevel.low,
      aliases: const ['london dry'],
      tags: const ['juniper'],
    );
    test('copyWith replaces one field and carries the rest', () {
      expect(ingredient.copyWith(), ingredient, reason: 'nothing named');
      expect(
        ingredient.copyWith(name: 'rum'),
        build(
          name: 'rum',
          stock: StockLevel.low,
          aliases: const ['london dry'],
          tags: const ['juniper'],
        ),
        reason: 'name',
      );
      expect(
        ingredient.copyWith(stock: StockLevel.in_),
        build(
          stock: StockLevel.in_,
          aliases: const ['london dry'],
          tags: const ['juniper'],
        ),
        reason: 'stock',
      );
      expect(
        ingredient.copyWith(aliases: const []),
        build(stock: StockLevel.low, tags: const ['juniper']),
        reason: 'aliases',
      );
      expect(
        ingredient.copyWith(tags: const []),
        build(stock: StockLevel.low, aliases: const ['london dry']),
        reason: 'tags',
      );
    });

    test('neither list can be changed from outside', () {
      final aliases = ['london dry'];
      final tags = ['juniper'];
      final ingredient = Ingredient('gin', aliases: aliases, tags: tags);
      aliases.add('dry gin');
      tags.add('botanical');
      expect(ingredient.aliases, ['london dry']);
      expect(ingredient.tags, ['juniper']);
      expect(() => ingredient.aliases.add('dry gin'), throwsUnsupportedError);
      expect(() => ingredient.tags.add('botanical'), throwsUnsupportedError);
    });
  });
}
