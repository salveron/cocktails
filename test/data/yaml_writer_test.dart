/// The canonical emitter: what a bar's file looks like once written — every
/// section in its fixed order, every value in its fixed spelling
/// (docs/architecture.md#data-format).
library;

import 'package:cocktails/data/src/yaml_writer.dart'
    show Offering, encodeOfferings;
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  group('encode', () {
    test('writes the docs/architecture.md example canonically', () {
      expect(encoded(docCollection()), canonicalText);
    });

    test('writes an empty collection with every section present', () {
      expect(encoded(Collection()), '''
format: 2
name: Home bar

settings:
  part_ml: 30
  oz_ml: 29.5735
  display: part

units:
  - {name: part, plural: parts}
  - {name: ml}
  - {name: oz}
  - {name: dash, plural: dashes}
  - {name: barspoon, plural: barspoons}
  - {name: drop, plural: drops}
  - {name: piece, plural: pieces}

ingredients: []

ingredient_tags: []

recipe_tags: []

recipes: []
''');
    });

    test('omits entry defaults and empty recipe fields', () {
      final collection = Collection(
        ingredients: [Ingredient('gin')],
        recipes: [Recipe('Nothing Yet')],
      );
      final text = encoded(collection);
      expect(text, contains('\ningredients:\n  - {name: gin}\n'));
      expect(text, contains('\nrecipes:\n  - name: Nothing Yet\n'));
    });

    test('an entry writes the spellings it also answers to (ADR 10)', () {
      final collection = Collection(
        ingredients: [
          Ingredient(
            'bourbon',
            stock: StockLevel.in_,
            aliases: const ['bourbon whiskey', 'bourbon whisky'],
            tags: const ['oaked'],
          ),
        ],
        ingredientTags: const [Tag('oaked', color: TagColor.slate)],
      );
      expect(
        encoded(collection),
        contains(
          '\ningredients:\n'
          '  - {name: bourbon, stock: in, tags: [oaked], '
          'aliases: [bourbon whiskey, bourbon whisky]}\n',
        ),
      );
    });

    test('a tag colour is written even though nothing is default', () {
      final collection = Collection(
        ingredientTags: const [Tag('citrus', color: TagColor.sand)],
        recipeTags: const [Tag('sour', color: TagColor.rose)],
      );
      final text = encoded(collection);
      expect(
        text,
        contains('\ningredient_tags:\n  - {name: citrus, color: sand}\n'),
      );
      expect(text, contains('\nrecipe_tags:\n  - {name: sour, color: rose}\n'));
    });

    test('writes non-default settings', () {
      final collection = Collection(unitSizes: const UnitSizes(partMl: 22.5));
      expect(
        encoded(collection, display: FixedUnit.ml),
        contains(
          'settings:\n  part_ml: 22.5\n  oz_ml: 29.5735\n  display: ml\n',
        ),
      );
    });

    test('quotes scalars YAML would read as other types', () {
      final collection = Collection(
        ingredients: [Ingredient('1976'), Ingredient('true')],
        recipeTags: const [
          Tag('true', color: TagColor.teal),
          Tag('no', color: TagColor.teal),
        ],
      );
      final text = encoded(collection);
      expect(text, contains('- {name: "1976"}'));
      expect(text, contains('- {name: "true"}'));
      expect(
        text,
        contains(
          'recipe_tags:\n  - {name: "true", color: teal}\n'
          '  - {name: no, color: teal}\n',
        ),
      );
    });

    test('quotes structure-breaking text', () {
      final collection = Collection(
        ingredients: [Ingredient('lime, fresh'), Ingredient('rum # dark')],
        recipes: [
          Recipe(
            'gin: a study',
            lines: const [
              RecipeLine(Amount(1), 'oz', ['rum # dark']),
            ],
            notes: 'stir.\nstrain — serve "up"',
          ),
        ],
      );
      final text = encoded(collection);
      expect(text, contains('- {name: "lime, fresh"}'));
      expect(text, contains('- name: "gin: a study"'));
      expect(text, contains('- "1 oz rum # dark"'));
      expect(text, contains(r'notes: "stir.\nstrain — serve \"up\""'));
    });
  });

  /// The one document written to the wire rather than to disk, so it carries a
  /// version of its own (ADR 22).
  group('the offered list', () {
    test('a device offering nothing still says which format it speaks', () {
      expect(encodeOfferings([]), 'lan_format: 1\n\nbars: []\n');
    });

    test('writes an entry per offered bar, in the shape the index is in', () {
      expect(
        encodeOfferings([
          (id: 'a1b2c3', name: 'Home bar', path: 'deadbeef'),
          (id: 'd4e5f6', name: 'Beach bar', path: 'cafef00d'),
        ]),
        'lan_format: 1\n'
        '\n'
        'bars:\n'
        '  - {id: a1b2c3, name: Home bar, path: deadbeef}\n'
        '  - {id: d4e5f6, name: Beach bar, path: cafef00d}\n',
      );
    });

    /// A bar's name is the reader's and may hold anything; the entry is a flow
    /// map, where a comma or a colon would otherwise end the scalar.
    test('quotes a name that would not survive a flow entry', () {
      const Offering awkward = (
        id: 'a1',
        name: 'Ada, and: friends',
        path: 'deadbeef',
      );
      expect(encodeOfferings([awkward]), contains('name: "Ada, and: friends"'));
    });
  });
}
