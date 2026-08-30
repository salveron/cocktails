import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('Collection', () {
    Collection build({
      UnitSizes unitSizes = const UnitSizes(partMl: 25),
      List<Ingredient>? ingredients,
      List<Tag> ingredientTags = const [Tag('oaked', color: TagColor.sand)],
      List<Tag> recipeTags = const [Tag('sour', color: TagColor.rose)],
      List<Recipe>? recipes,
    }) => Collection(
      unitSizes: unitSizes,
      ingredients:
          ingredients ??
          [
            Ingredient('bourbon', tags: const ['oaked']),
          ],
      ingredientTags: ingredientTags,
      recipeTags: recipeTags,
      recipes:
          recipes ??
          [
            Recipe('Whiskey Sour', tags: ['sour']),
          ],
    );

    test('starts empty with default sizes and the shipped units', () {
      final collection = Collection();
      expect(collection.units, defaultUnits);
      expect(collection.unitSpellings, contains('dashes'));
      expect(collection.ingredients, isEmpty);
      expect(collection.ingredientTags, isEmpty);
      expect(collection.recipeTags, isEmpty);
      expect(collection.recipes, isEmpty);
      expect(collection.unitSizes, const UnitSizes());
    });

    test('rejects duplicate names within each kind', () {
      expect(
        () => Collection(ingredients: [Ingredient('gin'), Ingredient('gin')]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ingredient'), contains('gin')),
          ),
        ),
      );
      expect(
        () => Collection(
          recipeTags: const [
            Tag('sour', color: TagColor.rose),
            Tag('sour', color: TagColor.teal),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('recipe tag'),
          ),
        ),
      );
      expect(
        () => Collection(
          ingredientTags: const [
            Tag('citrus', color: TagColor.sand),
            Tag('citrus', color: TagColor.teal),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('ingredient tag'),
          ),
        ),
      );
      expect(
        () => Collection(recipes: [Recipe('Negroni'), Recipe('Negroni')]),
        throwsArgumentError,
      );
    });

    test('rejects a unit spelling another unit already answers to', () {
      expect(
        () => Collection(units: const [Unit('dash'), Unit('dash')]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('unit'), contains('dash')),
          ),
        ),
      );
      expect(
        () => Collection(
          units: const [
            Unit('dash', plural: 'drop'),
            Unit('drop'),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a plural written out as its own name is no collision', () {
      expect(
        Collection(units: const [Unit('ml', plural: 'ml')]).units,
        hasLength(1),
      );
    });

    test('rejects names that differ only in case (ADR 08)', () {
      expect(
        () => Collection(ingredients: [Ingredient('Gin'), Ingredient('gin')]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Collection(recipes: [Recipe('Negroni'), Recipe('negroni')]),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Collection(
          ingredientTags: const [
            Tag('Citrus', color: TagColor.sand),
            Tag('citrus', color: TagColor.teal),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allows the same name across kinds, both vocabularies included', () {
      final collection = Collection(
        ingredients: [Ingredient('sour')],
        ingredientTags: const [Tag('sour', color: TagColor.sand)],
        recipeTags: const [Tag('sour', color: TagColor.rose)],
        recipes: [Recipe('sour')],
      );
      expect(collection.ingredients.single.name, 'sour');
      expect(collection.ingredientTags.single.color, TagColor.sand);
      expect(collection.recipeTags.single.color, TagColor.rose);
    });

    const classic = [Tag('classic', color: TagColor.rose)];
    const peaty = [Tag('peaty', color: TagColor.sand)];

    valueEquality(build, {
      'unitSizes': build(unitSizes: const UnitSizes()),
      'ingredients': build(ingredients: [Ingredient('gin')]),
      'ingredientTags': build(ingredientTags: peaty),
      'recipeTags': build(recipeTags: classic),
      'recipes': build(recipes: [Recipe('Negroni')]),
    });

    final collection = build();
    copyWithContract([
      (
        field: 'nothing named',
        apply: () => collection.copyWith(),
        expected: collection,
      ),
      (
        field: 'unitSizes',
        apply: () => collection.copyWith(unitSizes: const UnitSizes()),
        expected: build(unitSizes: const UnitSizes()),
      ),
      (
        field: 'ingredients',
        apply: () => collection.copyWith(ingredients: [Ingredient('gin')]),
        expected: build(ingredients: [Ingredient('gin')]),
      ),
      (
        field: 'ingredientTags',
        apply: () => collection.copyWith(ingredientTags: peaty),
        expected: build(ingredientTags: peaty),
      ),
      (
        field: 'recipeTags',
        apply: () => collection.copyWith(recipeTags: classic),
        expected: build(recipeTags: classic),
      ),
      (
        field: 'recipes',
        apply: () => collection.copyWith(recipes: [Recipe('Negroni')]),
        expected: build(recipes: [Recipe('Negroni')]),
      ),
    ]);

    test('copyWith still rejects a duplicate name', () {
      expect(
        () => build().copyWith(
          ingredients: [Ingredient('gin'), Ingredient('gin')],
        ),
        throwsArgumentError,
      );
    });

    group('name lookups', () {
      test('answer with the entry of that name', () {
        final collection = build();
        expect(
          collection.ingredientNamed('bourbon'),
          Ingredient('bourbon', tags: const ['oaked']),
        );
        expect(collection.recipeNamed('Whiskey Sour')?.tags, ['sour']);
        expect(collection.hasTag(TagKind.recipe, 'sour'), isTrue);
        expect(collection.hasTag(TagKind.ingredient, 'oaked'), isTrue);
      });

      test('answer for an unknown name without throwing', () {
        final collection = build();
        expect(collection.ingredientNamed('gin'), isNull);
        expect(collection.recipeNamed('Negroni'), isNull);
        expect(collection.hasTag(TagKind.recipe, 'classic'), isFalse);
        expect(collection.hasTag(TagKind.ingredient, 'peaty'), isFalse);
      });

      test('one vocabulary never answers for the other', () {
        final collection = build();
        expect(collection.hasTag(TagKind.recipe, 'oaked'), isFalse);
        expect(collection.hasTag(TagKind.ingredient, 'sour'), isFalse);
      });

      test('an empty collection answers nothing', () {
        final collection = Collection();
        expect(collection.ingredientNamed('bourbon'), isNull);
        expect(collection.recipeNamed('Whiskey Sour'), isNull);
        expect(collection.hasTag(TagKind.recipe, 'sour'), isFalse);
        expect(collection.hasTag(TagKind.ingredient, 'oaked'), isFalse);
      });

      test('repeated lookups keep answering, index and all', () {
        final collection = build();
        expect(collection.ingredientNamed('bourbon')?.name, 'bourbon');
        expect(collection.ingredientNamed('bourbon')?.name, 'bourbon');
        expect(collection.ingredientNamed('gin'), isNull);
      });

      test('answer however the name is capitalised (ADR 08)', () {
        final collection = build();
        expect(collection.ingredientNamed('BOURBON')?.name, 'bourbon');
        expect(collection.recipeNamed('whiskey sour')?.name, 'Whiskey Sour');
        expect(collection.hasTag(TagKind.recipe, 'Sour'), isTrue);
        expect(collection.hasTag(TagKind.ingredient, 'Oaked'), isTrue);
      });

      test('a vocabulary answers to its kind', () {
        final collection = build();
        expect(collection.tagsOf(TagKind.recipe), collection.recipeTags);
        expect(
          collection.tagsOf(TagKind.ingredient),
          collection.ingredientTags,
        );
      });

      test('the name sets are the lists, ready for validation', () {
        final collection = build();
        expect(collection.recipeNames, {'Whiskey Sour'});
        expect(collection.tagNames(TagKind.recipe), {'sour'});
        expect(collection.tagNames(TagKind.ingredient), {'oaked'});
      });

      test('an alias answers for the ingredient it belongs to (ADR 10)', () {
        final collection = Collection(
          ingredients: [
            Ingredient(
              'bourbon',
              stock: StockLevel.in_,
              aliases: const ['bourbon whiskey'],
            ),
          ],
        );
        expect(collection.ingredientNamed('bourbon whiskey')?.name, 'bourbon');
        expect(collection.ingredientNamed('BOURBON WHISKEY')?.name, 'bourbon');
        expect(collection.ingredientNamed('whiskey'), isNull);
      });
    });

    group('ingredientSpellings', () {
      final collection = Collection(
        ingredients: [
          Ingredient('bourbon', aliases: const ['bourbon whiskey']),
          Ingredient('gin'),
        ],
      );

      test('gathers names and aliases into one namespace', () {
        expect(collection.ingredientSpellings(), {
          'bourbon',
          'bourbon whiskey',
          'gin',
        });
        expect(Collection().ingredientSpellings(), isEmpty);
      });

      test('drops the whole entry it is told to leave out', () {
        expect(collection.ingredientSpellings(except: 'bourbon'), {'gin'});
        expect(collection.ingredientSpellings(except: 'BOURBON'), {'gin'});
        expect(collection.ingredientSpellings(except: 'bourbon whiskey'), {
          'bourbon',
          'bourbon whiskey',
          'gin',
        });
      });
    });

    group('one namespace for every spelling (ADR 10)', () {
      test('an alias may not repeat another ingredient name', () {
        expect(
          () => Collection(
            ingredients: [
              Ingredient('bourbon', aliases: const ['Rye']),
              Ingredient('rye'),
            ],
          ),
          throwsArgumentError,
        );
      });

      test('nor another ingredient alias', () {
        expect(
          () => Collection(
            ingredients: [
              Ingredient('bourbon', aliases: const ['whiskey']),
              Ingredient('rye', aliases: const ['whiskey']),
            ],
          ),
          throwsArgumentError,
        );
      });

      test('nor its own entry name', () {
        expect(
          () => Collection(
            ingredients: [
              Ingredient('bourbon', aliases: const ['Bourbon']),
            ],
          ),
          throwsArgumentError,
        );
      });

      test(
        'but two ingredients may alias the same name in other vocabularies',
        () {
          final collection = Collection(
            ingredients: [
              Ingredient('bourbon', aliases: const ['sour']),
            ],
            ingredientTags: const [Tag('sour', color: TagColor.sand)],
            recipes: [Recipe('sour')],
          );
          expect(collection.ingredientNamed('sour')?.name, 'bourbon');
        },
      );
    });
  });
}
