import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every enum written into the data format promises: the [tokens] it
/// spells, in order, and a [fromToken] that reads back exactly those and
/// answers null for anything else. One body for all four, so a token added to
/// one enum is held to the same contract as the rest.
void tokenVocabulary<T extends Enum>(
  String name, {
  required List<T> values,
  required String Function(T value) token,
  required T? Function(String) fromToken,
  required List<String> tokens,
  required String unknown,
}) {
  group('$name tokens', () {
    test('match the data format', () {
      expect([for (final value in values) token(value)], tokens);
    });

    test('fromToken round-trips every member', () {
      for (final value in values) {
        expect(fromToken(token(value)), value);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(fromToken(unknown), isNull);
    });
  });
}

/// Value semantics, read the same way for every type carrying them: two builds
/// of the same values are equal and hash alike, while each of [differing] — the
/// same build with one field moved off its default — is not. Each field is
/// named, so a broken `==` reports which one it stopped reading.
void valueEquality<T>(T Function() build, Map<String, T> differing) {
  test('equality and hashCode isolate each field', () {
    expect(build(), build());
    expect(build().hashCode, build().hashCode);
    differing.forEach((field, moved) {
      expect(build(), isNot(moved), reason: field);
    });
  });
}

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

  tokenVocabulary(
    'FixedUnit',
    values: FixedUnit.values,
    token: (value) => value.token,
    fromToken: FixedUnit.fromToken,
    tokens: const ['part', 'ml', 'oz'],
    unknown: 'litre',
  );

  tokenVocabulary(
    'LineMark',
    values: LineMark.values,
    token: (value) => value.token,
    fromToken: LineMark.fromToken,
    tokens: const ['base', 'optional'],
    unknown: 'garnish',
  );

  tokenVocabulary(
    'TagColor',
    values: TagColor.values,
    token: (value) => value.token,
    fromToken: TagColor.fromToken,
    tokens: const ['teal', 'indigo', 'plum', 'rose', 'sand', 'slate'],
    unknown: 'puce',
  );

  test('the tag palette spends no colour stock or availability needs', () {
    expect([
      for (final color in TagColor.values) color.token,
    ], isNot(contains(anyOf('green', 'amber', 'red'))));
  });

  test(
    'FixedUnit.named finds the fixed unit a spelling stands for (ADR 08)',
    () {
      expect(FixedUnit.named('oz'), FixedUnit.oz);
      expect(FixedUnit.named('OZ'), FixedUnit.oz);
      expect(FixedUnit.named('dash'), isNull);
    },
  );

  group('StockLevel.next', () {
    test('follows an ingredient: in -> low -> out -> in', () {
      expect(StockLevel.in_.next, StockLevel.low);
      expect(StockLevel.low.next, StockLevel.out);
      expect(StockLevel.out.next, StockLevel.in_);
    });
  });

  group('Unit', () {
    test('the shipped vocabulary matches the data format', () {
      expect(
        [for (final unit in defaultUnits) unit.name],
        ['part', 'ml', 'oz', 'dash', 'barspoon', 'drop', 'piece'],
      );
      expect(
        FixedUnit.values.every(
          (fixed) => defaultUnits.spellings.contains(fixed.token),
        ),
        isTrue,
      );
    });

    test('an unwritten plural reads like the name', () {
      expect(const Unit('ml').pluralName, 'ml');
      expect(const Unit('dash', plural: 'dashes').pluralName, 'dashes');
    });

    test('only exactly one is spelled in the singular', () {
      const leaf = Unit('leaf', plural: 'leaves');
      expect(leaf.spelling(const Amount(1)), 'leaf');
      expect(leaf.spelling(const Amount.range(1, 1)), 'leaf');
      expect(leaf.spelling(const Amount(0.75)), 'leaves');
      expect(leaf.spelling(const Amount.range(1, 2)), 'leaves');
    });

    test('it answers to either spelling, in any case (ADR 08)', () {
      const dash = Unit('dash', plural: 'dashes');
      expect(dash.answersTo('DASH'), isTrue);
      expect(dash.answersTo('Dashes'), isTrue);
      expect(dash.answersTo('dashs'), isFalse);
    });

    valueEquality(() => const Unit('dash'), const {
      'name': Unit('drop'),
      'plural': Unit('dash', plural: 'dashes'),
    });
  });

  group('UnitLookup', () {
    test('finds a unit by either spelling, or by a plural never written', () {
      expect(defaultUnits.unitNamed('dash')?.name, 'dash');
      expect(defaultUnits.unitNamed('dashes')?.name, 'dash');
      expect(defaultUnits.unitNamed('Dashes')?.name, 'dash');
      expect(defaultUnits.unitNamed('ozs')?.name, 'oz');
      expect(defaultUnits.unitNamed('cup'), isNull);
    });

    test('a unit named outright beats another unit\'s stripped guess', () {
      const written = [Unit('dashe'), Unit('dash', plural: 'dashes')];
      expect(written.unitNamed('dashes')?.name, 'dash');
    });

    test('spellings count a plural reading like its name once', () {
      expect(const [Unit('ml')].spellings, ['ml']);
      expect(const [Unit('ml', plural: 'ml')].spellings, ['ml']);
      expect(const [Unit('dash', plural: 'dashes')].spellings, [
        'dash',
        'dashes',
      ]);
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

    valueEquality(() => const Amount.range(1.5, 2), const {
      'min': Amount.range(1, 2),
      'max': Amount.range(1.5, 3),
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

  group('Tag', () {
    Tag build({String name = 'sour', TagColor color = TagColor.teal}) =>
        Tag(name, color: color);

    valueEquality(build, {
      'name': build(name: 'classic'),
      'color': build(color: TagColor.rose),
    });

    test('copyWith replaces one field and carries the rest', () {
      const tag = Tag('sour', color: TagColor.rose);
      expect(tag.copyWith(), tag, reason: 'nothing named');
      expect(
        tag.copyWith(name: 'sours'),
        const Tag('sours', color: TagColor.rose),
        reason: 'name',
      );
      expect(
        tag.copyWith(color: TagColor.plum),
        const Tag('sour', color: TagColor.plum),
        reason: 'color',
      );
    });
  });

  group('RecipeLine', () {
    RecipeLine build({
      Amount amount = const Amount(0.5),
      String unit = 'part',
      List<String> ingredients = const ['egg white'],
      LineMark? mark,
    }) => RecipeLine(amount, unit, ingredients, mark: mark);

    test('defaults to unmarked: neither base nor optional', () {
      const line = RecipeLine(Amount(1.5), 'part', ['bourbon']);
      expect(line.mark, isNull);
      expect(line.isBase, isFalse);
      expect(line.isOptional, isFalse);
    });

    test('one mark answers both questions', () {
      const base = RecipeLine(Amount(1.5), 'part', [
        'bourbon',
      ], mark: LineMark.base);
      expect(base.isBase, isTrue);
      expect(base.isOptional, isFalse);
      const optional = RecipeLine(Amount(0.5), 'part', [
        'egg white',
      ], mark: LineMark.optional);
      expect(optional.isBase, isFalse);
      expect(optional.isOptional, isTrue);
    });

    valueEquality(build, {
      'amount': build(amount: const Amount(1)),
      'unit': build(unit: 'ml'),
      'ingredients': build(ingredients: const ['gin']),
      'one alternative more': build(ingredients: const ['egg white', 'gin']),
      'mark': build(mark: LineMark.optional),
    });

    test('one mark is not another', () {
      expect(build(mark: LineMark.base), isNot(build(mark: LineMark.optional)));
    });

    test('copyWith replaces one field and carries the rest', () {
      const line = RecipeLine(Amount(0.5), 'part', [
        'egg white',
      ], mark: LineMark.optional);
      expect(line.copyWith(), line, reason: 'nothing named');
      expect(
        line.copyWith(amount: const Amount(1)),
        const RecipeLine(Amount(1), 'part', [
          'egg white',
        ], mark: LineMark.optional),
        reason: 'amount',
      );
      expect(
        line.copyWith(unit: 'ml'),
        const RecipeLine(Amount(0.5), 'ml', [
          'egg white',
        ], mark: LineMark.optional),
        reason: 'unit',
      );
      expect(
        line.copyWith(ingredients: const ['gin']),
        const RecipeLine(Amount(0.5), 'part', ['gin'], mark: LineMark.optional),
        reason: 'ingredients',
      );
    });

    test('marked sets, replaces and clears the mark', () {
      const line = RecipeLine(Amount(1.5), 'part', ['bourbon']);
      expect(
        line.marked(LineMark.base),
        const RecipeLine(Amount(1.5), 'part', ['bourbon'], mark: LineMark.base),
      );
      expect(
        line.marked(LineMark.base).marked(LineMark.optional).mark,
        LineMark.optional,
      );
      expect(line.marked(LineMark.base).marked(null), line);
    });
  });

  group('Settings', () {
    test('defaults match the data-format example', () {
      const settings = Settings();
      expect(settings.partMl, 30);
      expect(settings.ozMl, 29.5735);
    });

    test('ml is the anchor the other two are sized against (ADR 17)', () {
      const settings = Settings(partMl: 25, ozMl: 30);
      expect(settings.mlPer(FixedUnit.part), 25);
      expect(settings.mlPer(FixedUnit.ml), 1);
      expect(settings.mlPer(FixedUnit.oz), 30);
    });

    test('ratio derives every pair from the two sizes', () {
      const settings = Settings(partMl: 30, ozMl: 15);
      expect(settings.ratio(FixedUnit.part, FixedUnit.ml), 30);
      expect(settings.ratio(FixedUnit.part, FixedUnit.oz), 2);
      expect(settings.ratio(FixedUnit.oz, FixedUnit.part), 0.5);
      expect(settings.ratio(FixedUnit.ml, FixedUnit.oz), 1 / 15);
      for (final unit in FixedUnit.values) {
        expect(settings.ratio(unit, unit), 1);
      }
    });

    test('withRatio moves the trailing unit, ml having no size', () {
      const settings = Settings(partMl: 30, ozMl: 15);
      // Trailing ml: the leading unit is the only one with a size to take it.
      expect(
        settings.withRatio(FixedUnit.part, FixedUnit.ml, 45),
        const Settings(partMl: 45, ozMl: 15),
      );
      expect(
        settings.withRatio(FixedUnit.oz, FixedUnit.ml, 29.5735),
        const Settings(partMl: 30, ozMl: 29.5735),
      );
      // Neither is ml, so the part stands and the ounce moves under it.
      expect(
        settings.withRatio(FixedUnit.part, FixedUnit.oz, 1),
        const Settings(partMl: 30, ozMl: 30),
      );
      expect(
        settings.withRatio(FixedUnit.oz, FixedUnit.part, 0.5),
        const Settings(partMl: 30, ozMl: 15),
      );
    });

    test('withRatio inverts its own ratio, whichever way round', () {
      const settings = Settings(partMl: 27, ozMl: 29.5735);
      for (final (from, to) in [
        (FixedUnit.part, FixedUnit.ml),
        (FixedUnit.oz, FixedUnit.ml),
        (FixedUnit.part, FixedUnit.oz),
        (FixedUnit.oz, FixedUnit.part),
      ]) {
        final same = settings.withRatio(from, to, settings.ratio(from, to));
        expect(same.partMl, closeTo(settings.partMl, 1e-12));
        expect(same.ozMl, closeTo(settings.ozMl, 1e-12));
      }
    });

    valueEquality(() => const Settings(), const {
      'partMl': Settings(partMl: 22.5),
      'ozMl': Settings(ozMl: 30),
    });

    test('copyWith replaces one field and carries the rest', () {
      const settings = Settings(partMl: 25, ozMl: 30);
      expect(settings.copyWith(), settings, reason: 'nothing named');
      expect(
        settings.copyWith(partMl: 30),
        const Settings(partMl: 30, ozMl: 30),
        reason: 'partMl',
      );
      expect(
        settings.copyWith(ozMl: 29.5735),
        const Settings(partMl: 25),
        reason: 'ozMl',
      );
    });

    // ADR 21: of the settings block the pick alone is the reader's, so it is
    // the one part of it a guest bar's refresh must not be able to replace.
    test('carries no reading unit, that being the bar\'s (ADR 21)', () {
      expect(
        Bar(id: 'a1', name: 'Home bar', mode: BarMode.owner).display,
        FixedUnit.part,
      );
      expect(const Settings().toString(), isNot(contains('display')));
    });
  });

  group('Recipe', () {
    Recipe build({
      String name = 'Whiskey Sour',
      List<String> tags = const ['sour'],
      List<RecipeLine> lines = const [
        RecipeLine(Amount.range(1.5, 2), 'part', ['bourbon']),
      ],
      String notes = 'dry shake, then shake with ice',
    }) => Recipe(name, tags: tags, lines: lines, notes: notes);

    test('defaults: no tags, no lines, empty notes', () {
      final recipe = Recipe('Whiskey Sour');
      expect(recipe.tags, isEmpty);
      expect(recipe.lines, isEmpty);
      expect(recipe.notes, isEmpty);
    });

    test('collections are unmodifiable', () {
      final recipe = Recipe('Whiskey Sour', tags: ['sour']);
      expect(() => recipe.tags.add('classic'), throwsUnsupportedError);
      expect(
        () => recipe.lines.add(const RecipeLine(Amount(1), 'part', ['gin'])),
        throwsUnsupportedError,
      );
    });

    test('detached from the lists it was built from', () {
      final tags = ['sour'];
      final recipe = Recipe('Whiskey Sour', tags: tags);
      tags.add('classic');
      expect(recipe.tags, ['sour']);
    });

    valueEquality(build, {
      'name': build(name: 'Sazerac'),
      'tags': build(tags: const ['sour', 'classic']),
      'lines': build(
        lines: const [
          RecipeLine(Amount(2), 'part', ['bourbon']),
        ],
      ),
      'notes': build(notes: 'stirred'),
    });

    test('copyWith replaces one field and carries the rest', () {
      final recipe = build();
      expect(recipe.copyWith(), recipe, reason: 'nothing named');
      expect(
        recipe.copyWith(name: 'Sazerac'),
        build(name: 'Sazerac'),
        reason: 'name',
      );
      expect(
        recipe.copyWith(tags: ['classic']),
        build(tags: const ['classic']),
        reason: 'tags',
      );
      expect(
        recipe.copyWith(
          lines: [
            const RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
        build(
          lines: const [
            RecipeLine(Amount(2), 'ml', ['rye']),
          ],
        ),
        reason: 'lines',
      );
      expect(
        recipe.copyWith(notes: 'stirred'),
        build(notes: 'stirred'),
        reason: 'notes',
      );
    });
  });

  group('Collection', () {
    Collection build({
      Settings settings = const Settings(partMl: 25),
      List<Ingredient>? ingredients,
      List<Tag> ingredientTags = const [Tag('oaked', color: TagColor.sand)],
      List<Tag> recipeTags = const [Tag('sour', color: TagColor.rose)],
      List<Recipe>? recipes,
    }) => Collection(
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

    test('starts empty with default settings and the shipped units', () {
      final collection = Collection();
      expect(collection.units, defaultUnits);
      expect(collection.unitSpellings, contains('dashes'));
      expect(collection.ingredients, isEmpty);
      expect(collection.ingredientTags, isEmpty);
      expect(collection.recipeTags, isEmpty);
      expect(collection.recipes, isEmpty);
      expect(collection.settings, const Settings());
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

    test('collections are unmodifiable', () {
      final collection = Collection();
      expect(
        () => collection.ingredients.add(Ingredient('gin')),
        throwsUnsupportedError,
      );
      for (final tags in [collection.ingredientTags, collection.recipeTags]) {
        expect(
          () => tags.add(const Tag('sour', color: TagColor.rose)),
          throwsUnsupportedError,
        );
      }
      expect(
        () => collection.recipes.add(Recipe('Negroni')),
        throwsUnsupportedError,
      );
    });

    const classic = [Tag('classic', color: TagColor.rose)];
    const peaty = [Tag('peaty', color: TagColor.sand)];

    valueEquality(build, {
      'settings': build(settings: const Settings()),
      'ingredients': build(ingredients: [Ingredient('gin')]),
      'ingredientTags': build(ingredientTags: peaty),
      'recipeTags': build(recipeTags: classic),
      'recipes': build(recipes: [Recipe('Negroni')]),
    });

    test('copyWith replaces one field and carries the rest', () {
      final collection = build();
      expect(collection.copyWith(), collection, reason: 'nothing named');
      expect(
        collection.copyWith(settings: const Settings()),
        build(settings: const Settings()),
        reason: 'settings',
      );
      expect(
        collection.copyWith(ingredients: [Ingredient('gin')]),
        build(ingredients: [Ingredient('gin')]),
        reason: 'ingredients',
      );
      expect(
        collection.copyWith(ingredientTags: peaty),
        build(ingredientTags: peaty),
        reason: 'ingredientTags',
      );
      expect(
        collection.copyWith(recipeTags: classic),
        build(recipeTags: classic),
        reason: 'recipeTags',
      );
      expect(
        collection.copyWith(recipes: [Recipe('Negroni')]),
        build(recipes: [Recipe('Negroni')]),
        reason: 'recipes',
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
        expect(
          () => collection.tagNames(TagKind.recipe).add('tiki'),
          throwsUnsupportedError,
        );
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

    test('a name worn in another case is the same tag (ADR 08)', () {
      expect(namesOf(wornInOrder(vocabulary, ['SOUR'])), ['sour']);
    });
  });

  group('holdingsOf', () {
    test('counts each kind, and the four in the order a reader meets '
        'them', () {
      final collection = Collection(
        units: const [Unit('part'), Unit('dash')],
        ingredients: [Ingredient('gin'), Ingredient('campari')],
        recipeTags: const [Tag('classic', color: TagColor.rose)],
        ingredientTags: const [
          Tag('italian', color: TagColor.teal),
          Tag('juniper', color: TagColor.sand),
        ],
        recipes: [Recipe('Negroni')],
      );
      expect(holdingsOf(collection).keys, Holding.values);
      // The tags of both vocabularies under one count, as the screen managing
      // them lists them (ADR 07).
      expect(holdingsOf(collection), {
        Holding.recipe: 1,
        Holding.ingredient: 2,
        Holding.tag: 3,
        Holding.unit: 2,
      });
    });

    test('an empty collection still carries the units it opens with', () {
      expect(holdingsOf(Collection()), {
        Holding.recipe: 0,
        Holding.ingredient: 0,
        Holding.tag: 0,
        Holding.unit: defaultUnits.length,
      });
    });

    test('every kind is named for the reader by its own noun', () {
      expect(
        [for (final holding in Holding.values) holding.noun],
        ['recipe', 'ingredient', 'tag', 'unit'],
      );
    });

    test('and written to the index under a token of its own (ADR 21)', () {
      // Declared rather than the identifier or the noun: a summary already in
      // an index must go on reading the same after either is renamed.
      expect(
        [for (final holding in Holding.values) holding.token],
        ['recipe', 'ingredient', 'tag', 'unit'],
      );
    });
  });
}
