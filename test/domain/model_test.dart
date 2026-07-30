import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StockLevel tokens', () {
    test('tokens match the data format, including in_ -> "in"', () {
      expect(StockLevel.in_.token, 'in');
      expect(StockLevel.low.token, 'low');
      expect(StockLevel.out.token, 'out');
    });

    test('fromToken round-trips every member', () {
      for (final level in StockLevel.values) {
        expect(StockLevel.fromToken(level.token), level);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(StockLevel.fromToken('missing'), isNull);
    });
  });

  group('StockLevel.next', () {
    test('follows a bottle: in -> low -> out -> in', () {
      expect(StockLevel.in_.next, StockLevel.low);
      expect(StockLevel.low.next, StockLevel.out);
      expect(StockLevel.out.next, StockLevel.in_);
    });
  });

  group('Unit tokens', () {
    test('tokens match the data format', () {
      expect(Unit.part.token, 'part');
      expect(Unit.ml.token, 'ml');
      expect(Unit.oz.token, 'oz');
      expect(Unit.dash.token, 'dash');
      expect(Unit.barspoon.token, 'barspoon');
      expect(Unit.drop.token, 'drop');
      expect(Unit.piece.token, 'piece');
    });

    test('fromToken round-trips every member', () {
      for (final unit in Unit.values) {
        expect(Unit.fromToken(unit.token), unit);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(Unit.fromToken('cup'), isNull);
    });
  });

  group('DisplayUnit tokens', () {
    test('tokens match the data format', () {
      expect(DisplayUnit.part.token, 'part');
      expect(DisplayUnit.ml.token, 'ml');
    });

    test('fromToken round-trips every member', () {
      for (final unit in DisplayUnit.values) {
        expect(DisplayUnit.fromToken(unit.token), unit);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(DisplayUnit.fromToken('litre'), isNull);
    });
  });

  group('LineMark tokens', () {
    test('tokens match the data format', () {
      expect(LineMark.base.token, 'base');
      expect(LineMark.optional.token, 'optional');
    });

    test('fromToken round-trips every member', () {
      for (final mark in LineMark.values) {
        expect(LineMark.fromToken(mark.token), mark);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(LineMark.fromToken('garnish'), isNull);
    });
  });

  group('TagColor tokens', () {
    test('tokens match the data format', () {
      expect(
        [for (final color in TagColor.values) color.token],
        ['teal', 'indigo', 'plum', 'rose', 'sand', 'slate'],
      );
    });

    test('the palette spends no colour stock or availability needs', () {
      expect([
        for (final color in TagColor.values) color.token,
      ], isNot(contains(anyOf('green', 'amber', 'red'))));
    });

    test('fromToken round-trips every member', () {
      for (final color in TagColor.values) {
        expect(TagColor.fromToken(color.token), color);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(TagColor.fromToken('puce'), isNull);
    });
  });

  group('Amount', () {
    test('single value is not a range', () {
      const amount = Amount(1.5);
      expect(amount.min, 1.5);
      expect(amount.max, 1.5);
      expect(amount.isRange, isFalse);
    });

    test('range exposes both ends', () {
      const amount = Amount.range(1.5, 2);
      expect(amount.min, 1.5);
      expect(amount.max, 2);
      expect(amount.isRange, isTrue);
    });

    test('range with equal ends equals the single value', () {
      expect(const Amount.range(2, 2), const Amount(2));
    });

    test('equality and hashCode isolate each field', () {
      const amount = Amount.range(1.5, 2);
      expect(amount, const Amount.range(1.5, 2));
      expect(amount.hashCode, const Amount.range(1.5, 2).hashCode);
      expect(amount, isNot(const Amount.range(1, 2)));
      expect(amount, isNot(const Amount.range(1.5, 3)));
    });
  });

  group('Ingredient', () {
    Ingredient build({
      String name = 'gin',
      StockLevel stock = StockLevel.out,
      List<String> tags = const [],
    }) => Ingredient(name, stock: stock, tags: tags);

    test('defaults to out of stock and untagged', () {
      final ingredient = Ingredient('bourbon');
      expect(ingredient.stock, StockLevel.out);
      expect(ingredient.tags, isEmpty);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(name: 'rum')));
      expect(build(), isNot(build(stock: StockLevel.low)));
      expect(build(), isNot(build(tags: const ['juniper'])));
    });

    test('copyWith replaces one field and carries the rest', () {
      final ingredient = Ingredient(
        'gin',
        stock: StockLevel.low,
        tags: const ['juniper'],
      );
      expect(ingredient.copyWith(), ingredient);
      expect(
        ingredient.copyWith(name: 'rum'),
        Ingredient('rum', stock: StockLevel.low, tags: const ['juniper']),
      );
      expect(
        ingredient.copyWith(stock: StockLevel.in_),
        Ingredient('gin', stock: StockLevel.in_, tags: const ['juniper']),
      );
      expect(
        ingredient.copyWith(tags: const []),
        Ingredient('gin', stock: StockLevel.low),
      );
    });

    test('the tag list cannot be changed from outside', () {
      final tags = ['juniper'];
      final ingredient = Ingredient('gin', tags: tags);
      tags.add('botanical');
      expect(ingredient.tags, ['juniper']);
      expect(() => ingredient.tags.add('botanical'), throwsUnsupportedError);
    });
  });

  group('Tag', () {
    Tag build({String name = 'sour', TagColor color = TagColor.teal}) =>
        Tag(name, color: color);

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(name: 'classic')));
      expect(build(), isNot(build(color: TagColor.rose)));
    });

    test('copyWith replaces one field and carries the rest', () {
      const tag = Tag('sour', color: TagColor.rose);
      expect(tag.copyWith(), tag);
      expect(
        tag.copyWith(name: 'sours'),
        const Tag('sours', color: TagColor.rose),
      );
      expect(
        tag.copyWith(color: TagColor.plum),
        const Tag('sour', color: TagColor.plum),
      );
    });
  });

  group('RecipeLine', () {
    RecipeLine build({
      Amount amount = const Amount(0.5),
      Unit unit = Unit.part,
      String ingredient = 'egg white',
      LineMark? mark,
    }) => RecipeLine(amount, unit, ingredient, mark: mark);

    test('defaults to unmarked: neither base nor optional', () {
      const line = RecipeLine(Amount(1.5), Unit.part, 'bourbon');
      expect(line.mark, isNull);
      expect(line.isBase, isFalse);
      expect(line.isOptional, isFalse);
    });

    test('one mark answers both questions', () {
      const base = RecipeLine(
        Amount(1.5),
        Unit.part,
        'bourbon',
        mark: LineMark.base,
      );
      expect(base.isBase, isTrue);
      expect(base.isOptional, isFalse);
      const optional = RecipeLine(
        Amount(0.5),
        Unit.part,
        'egg white',
        mark: LineMark.optional,
      );
      expect(optional.isBase, isFalse);
      expect(optional.isOptional, isTrue);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(amount: const Amount(1))));
      expect(build(), isNot(build(unit: Unit.ml)));
      expect(build(), isNot(build(ingredient: 'gin')));
      expect(build(), isNot(build(mark: LineMark.optional)));
      expect(build(mark: LineMark.base), isNot(build(mark: LineMark.optional)));
    });

    test('copyWith replaces one field and carries the rest', () {
      const line = RecipeLine(
        Amount(0.5),
        Unit.part,
        'egg white',
        mark: LineMark.optional,
      );
      expect(line.copyWith(), line);
      expect(
        line.copyWith(amount: const Amount(1)),
        const RecipeLine(
          Amount(1),
          Unit.part,
          'egg white',
          mark: LineMark.optional,
        ),
      );
      expect(
        line.copyWith(unit: Unit.ml),
        const RecipeLine(
          Amount(0.5),
          Unit.ml,
          'egg white',
          mark: LineMark.optional,
        ),
      );
      expect(
        line.copyWith(ingredient: 'gin'),
        const RecipeLine(
          Amount(0.5),
          Unit.part,
          'gin',
          mark: LineMark.optional,
        ),
      );
    });

    test('marked sets, replaces and clears the mark', () {
      const line = RecipeLine(Amount(1.5), Unit.part, 'bourbon');
      expect(
        line.marked(LineMark.base),
        const RecipeLine(
          Amount(1.5),
          Unit.part,
          'bourbon',
          mark: LineMark.base,
        ),
      );
      expect(
        line.marked(LineMark.base).marked(LineMark.optional).mark,
        LineMark.optional,
      );
      expect(line.marked(LineMark.base).marked(null), line);
    });
  });

  group('MadeHistory', () {
    test('keeps the date, drops the time of day', () {
      final history = MadeHistory(DateTime(2026, 7, 18, 23, 59), 12);
      expect(history.last, DateTime(2026, 7, 18));
      expect(history, MadeHistory(DateTime(2026, 7, 18), 12));
    });

    test('equality and hashCode isolate each field', () {
      MadeHistory build({int day = 18, int times = 12}) =>
          MadeHistory(DateTime(2026, 7, day), times);
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(day: 19)));
      expect(build(), isNot(build(times: 13)));
    });
  });

  group('Settings', () {
    test('defaults match the data-format example', () {
      const settings = Settings();
      expect(settings.partMl, 30);
      expect(settings.display, DisplayUnit.part);
    });

    test('equality and hashCode isolate each field', () {
      expect(const Settings(), const Settings());
      expect(const Settings().hashCode, const Settings().hashCode);
      expect(const Settings(), isNot(const Settings(partMl: 22.5)));
      expect(const Settings(), isNot(const Settings(display: DisplayUnit.ml)));
    });

    test('copyWith replaces one field and carries the rest', () {
      const settings = Settings(partMl: 25, display: DisplayUnit.ml);
      expect(settings.copyWith(), settings);
      expect(
        settings.copyWith(partMl: 30),
        const Settings(partMl: 30, display: DisplayUnit.ml),
      );
      expect(
        settings.copyWith(display: DisplayUnit.part),
        const Settings(partMl: 25),
      );
    });
  });

  group('Recipe', () {
    Recipe build({
      String name = 'Whiskey Sour',
      List<String> tags = const ['sour'],
      List<RecipeLine> lines = const [
        RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
      ],
      String notes = 'dry shake, then shake with ice',
      int? madeTimes = 12,
    }) => Recipe(
      name,
      tags: tags,
      lines: lines,
      notes: notes,
      made: madeTimes == null
          ? null
          : MadeHistory(DateTime(2026, 7, 18), madeTimes),
    );

    test('defaults: no tags, no lines, empty notes, never made', () {
      final recipe = Recipe('Whiskey Sour');
      expect(recipe.tags, isEmpty);
      expect(recipe.lines, isEmpty);
      expect(recipe.notes, isEmpty);
      expect(recipe.made, isNull);
    });

    test('collections are unmodifiable', () {
      final recipe = Recipe('Whiskey Sour', tags: ['sour']);
      expect(() => recipe.tags.add('classic'), throwsUnsupportedError);
      expect(
        () => recipe.lines.add(const RecipeLine(Amount(1), Unit.part, 'gin')),
        throwsUnsupportedError,
      );
    });

    test('detached from the lists it was built from', () {
      final tags = ['sour'];
      final recipe = Recipe('Whiskey Sour', tags: tags);
      tags.add('classic');
      expect(recipe.tags, ['sour']);
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(name: 'Sazerac')));
      expect(build(), isNot(build(tags: const ['sour', 'classic'])));
      expect(
        build(),
        isNot(
          build(lines: const [RecipeLine(Amount(2), Unit.part, 'bourbon')]),
        ),
      );
      expect(build(), isNot(build(notes: 'stirred')));
      expect(build(), isNot(build(madeTimes: 13)));
      expect(build(), isNot(build(madeTimes: null)));
    });

    test('copyWith replaces one field and carries the rest', () {
      final recipe = build();
      expect(recipe.copyWith(), recipe);
      expect(recipe.copyWith(name: 'Sazerac'), build(name: 'Sazerac'));
      expect(
        recipe.copyWith(tags: ['classic']),
        build(tags: const ['classic']),
      );
      expect(
        recipe.copyWith(lines: [const RecipeLine(Amount(2), Unit.ml, 'rye')]),
        build(lines: const [RecipeLine(Amount(2), Unit.ml, 'rye')]),
      );
      expect(recipe.copyWith(notes: 'stirred'), build(notes: 'stirred'));
      expect(
        recipe.copyWith(made: MadeHistory(DateTime(2026, 7, 18), 13)),
        build(madeTimes: 13),
      );
    });

    test('copyWith cannot unmake a recipe: null keeps the history', () {
      expect(build().copyWith(made: null).made?.times, 12);
    });
  });

  group('Model', () {
    Model build({
      Settings settings = const Settings(partMl: 25),
      List<Ingredient>? ingredients,
      List<Tag> ingredientTags = const [Tag('oaked', color: TagColor.sand)],
      List<Tag> recipeTags = const [Tag('sour', color: TagColor.rose)],
      List<Recipe>? recipes,
    }) => Model(
      settings: settings,
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

    test('starts empty with default settings', () {
      final model = Model();
      expect(model.ingredients, isEmpty);
      expect(model.ingredientTags, isEmpty);
      expect(model.recipeTags, isEmpty);
      expect(model.recipes, isEmpty);
      expect(model.settings, const Settings());
    });

    test('rejects duplicate names within each kind', () {
      expect(
        () => Model(ingredients: [Ingredient('gin'), Ingredient('gin')]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ingredient'), contains('gin')),
          ),
        ),
      );
      expect(
        () => Model(
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
        () => Model(
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
        () => Model(recipes: [Recipe('Negroni'), Recipe('Negroni')]),
        throwsArgumentError,
      );
    });

    test('allows the same name across kinds, both vocabularies included', () {
      final model = Model(
        ingredients: [Ingredient('sour')],
        ingredientTags: const [Tag('sour', color: TagColor.sand)],
        recipeTags: const [Tag('sour', color: TagColor.rose)],
        recipes: [Recipe('sour')],
      );
      expect(model.ingredients.single.name, 'sour');
      expect(model.ingredientTags.single.color, TagColor.sand);
      expect(model.recipeTags.single.color, TagColor.rose);
    });

    test('collections are unmodifiable', () {
      final model = Model();
      expect(
        () => model.ingredients.add(Ingredient('gin')),
        throwsUnsupportedError,
      );
      for (final tags in [model.ingredientTags, model.recipeTags]) {
        expect(
          () => tags.add(const Tag('sour', color: TagColor.rose)),
          throwsUnsupportedError,
        );
      }
      expect(
        () => model.recipes.add(Recipe('Negroni')),
        throwsUnsupportedError,
      );
    });

    test('equality and hashCode isolate each field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(settings: const Settings())));
      expect(build(), isNot(build(ingredients: [Ingredient('gin')])));
      expect(
        build(),
        isNot(
          build(ingredientTags: const [Tag('peaty', color: TagColor.sand)]),
        ),
      );
      expect(
        build(),
        isNot(build(recipeTags: const [Tag('classic', color: TagColor.rose)])),
      );
      expect(build(), isNot(build(recipes: [Recipe('Negroni')])));
    });

    test('copyWith replaces one field and carries the rest', () {
      final model = build();
      const classic = [Tag('classic', color: TagColor.rose)];
      const peaty = [Tag('peaty', color: TagColor.sand)];
      expect(model.copyWith(), model);
      expect(
        model.copyWith(settings: const Settings()),
        build(settings: const Settings()),
      );
      expect(
        model.copyWith(ingredients: [Ingredient('gin')]),
        build(ingredients: [Ingredient('gin')]),
      );
      expect(
        model.copyWith(ingredientTags: peaty),
        build(ingredientTags: peaty),
      );
      expect(model.copyWith(recipeTags: classic), build(recipeTags: classic));
      expect(
        model.copyWith(recipes: [Recipe('Negroni')]),
        build(recipes: [Recipe('Negroni')]),
      );
    });

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
        final model = build();
        expect(
          model.ingredientNamed('bourbon'),
          Ingredient('bourbon', tags: const ['oaked']),
        );
        expect(model.recipeNamed('Whiskey Sour')?.tags, ['sour']);
        expect(model.hasTag(TagKind.recipe, 'sour'), isTrue);
        expect(model.hasTag(TagKind.ingredient, 'oaked'), isTrue);
      });

      test('answer for an unknown name without throwing', () {
        final model = build();
        expect(model.ingredientNamed('gin'), isNull);
        expect(model.recipeNamed('Negroni'), isNull);
        expect(model.hasTag(TagKind.recipe, 'classic'), isFalse);
        expect(model.hasTag(TagKind.ingredient, 'peaty'), isFalse);
      });

      test('one vocabulary never answers for the other', () {
        final model = build();
        expect(model.hasTag(TagKind.recipe, 'oaked'), isFalse);
        expect(model.hasTag(TagKind.ingredient, 'sour'), isFalse);
      });

      test('an empty model answers nothing', () {
        final model = Model();
        expect(model.ingredientNamed('bourbon'), isNull);
        expect(model.recipeNamed('Whiskey Sour'), isNull);
        expect(model.hasTag(TagKind.recipe, 'sour'), isFalse);
        expect(model.hasTag(TagKind.ingredient, 'oaked'), isFalse);
      });

      test('repeated lookups keep answering, index and all', () {
        final model = build();
        expect(model.ingredientNamed('bourbon')?.name, 'bourbon');
        expect(model.ingredientNamed('bourbon')?.name, 'bourbon');
        expect(model.ingredientNamed('gin'), isNull);
      });

      test('a vocabulary answers to its kind', () {
        final model = build();
        expect(model.tagsOf(TagKind.recipe), model.recipeTags);
        expect(model.tagsOf(TagKind.ingredient), model.ingredientTags);
      });

      test('the name sets are the lists, ready for validation', () {
        final model = build();
        expect(model.ingredientNames, {'bourbon'});
        expect(model.recipeNames, {'Whiskey Sour'});
        expect(model.tagNames(TagKind.recipe), {'sour'});
        expect(model.tagNames(TagKind.ingredient), {'oaked'});
        expect(Model().ingredientNames, isEmpty);
        expect(() => model.ingredientNames.add('rye'), throwsUnsupportedError);
        expect(
          () => model.tagNames(TagKind.recipe).add('tiki'),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('wornInOrder', () {
    const vocabulary = [
      Tag('classic', color: TagColor.rose),
      Tag('sour', color: TagColor.sand),
      Tag('tiki', color: TagColor.teal),
    ];
    List<String> namesOf(List<Tag> tags) => [for (final tag in tags) tag.name];

    test('reads in vocabulary order, not the order they were worn', () {
      expect(namesOf(wornInOrder(vocabulary, ['tiki', 'classic'])), [
        'classic',
        'tiki',
      ]);
    });

    test('drops a name the vocabulary no longer holds', () {
      expect(namesOf(wornInOrder(vocabulary, ['vintage', 'sour'])), ['sour']);
    });

    test('answers with the tags themselves, colours included', () {
      expect(wornInOrder(vocabulary, ['sour']).single.color, TagColor.sand);
    });

    test('wearing none and a vocabulary of none both come out empty', () {
      expect(wornInOrder(vocabulary, const []), isEmpty);
      expect(wornInOrder(const [], const ['classic']), isEmpty);
    });

    test('a name wanted twice is answered once', () {
      expect(namesOf(wornInOrder(vocabulary, ['sour', 'sour'])), ['sour']);
    });
  });
}
