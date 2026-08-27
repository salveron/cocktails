/// Support the data suites share: the docs/architecture.md#data-format example
/// text, a matching [Collection], the decode/encode/reject shorthands built
/// over [YamlCodec], and the contract every [BarStore] promises whatever it
/// stores into (docs/components.md#testing).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

const codec = YamlCodec();

/// The docs/architecture.md#data-format example, as the emitter writes it.
const canonicalText = '''
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

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: lime juice, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}
  - {name: egg white, stock: in}

ingredient_tags:
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice / lime juice
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
''';

/// The same example verbatim from the doc, comments included.
const commentedText = '''
format: 2
name: Home bar         # the bar's, a label rather than an identity (FR-BAR-1)

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  oz_ml: 29.5735       # and one ounce; ml is the anchor, so it needs none (ADR 17)
  display: part        # part | ml | oz — what the three read in

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: oz}                         # fixed, like the two above (ADR 17)
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}  # also answers to (ADR 10)
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: lime juice, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}   # stock omitted = out
  - {name: egg white, stock: in}                           # untagged

ingredient_tags:                       # what an ingredient can be labelled
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:                           # a separate vocabulary (ADR 07)
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice / lime juice   # either one makes it (ADR 11)
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
''';

Collection docCollection() => Collection(
  units: const [
    Unit(partUnit, plural: 'parts'),
    Unit(mlUnit),
    Unit(ozUnit),
    Unit('dash', plural: 'dashes'),
  ],
  ingredients: [
    Ingredient(
      'bourbon',
      stock: StockLevel.in_,
      aliases: const ['bourbon whiskey'],
    ),
    Ingredient('lemon juice', stock: StockLevel.low, tags: const ['citrus']),
    Ingredient('lime juice', tags: const ['citrus']),
    Ingredient('rich demerara syrup', tags: const ['syrup', 'homemade']),
    Ingredient('egg white', stock: StockLevel.in_),
  ],
  ingredientTags: const [
    Tag('citrus', color: TagColor.sand),
    Tag('homemade', color: TagColor.slate),
    Tag('syrup', color: TagColor.indigo),
  ],
  recipeTags: const [
    Tag('sour', color: TagColor.rose),
    Tag('classic', color: TagColor.teal),
  ],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(Amount.range(1.5, 2), 'part', [
          'bourbon',
        ], mark: LineMark.base),
        RecipeLine(Amount(0.75), 'part', ['lemon juice', 'lime juice']),
        RecipeLine(Amount(0.5), 'part', ['rich demerara syrup']),
        RecipeLine(Amount(0.5), 'part', ['egg white'], mark: LineMark.optional),
      ],
      notes: 'dry shake, then shake with ice',
    ),
  ],
);

BarContent payloadOf(String yaml) {
  final result = codec.decode(yaml);
  if (result is Rejected<BarContent>) {
    fail('expected Ok, got:\n${result.issues.join('\n')}');
  }
  return (result as Ok<BarContent>).value;
}

Collection decoded(String yaml) => payloadOf(yaml).collection;

/// A collection written as the bar's file — the doc example's name and unit
/// unless a test is about one of the two (ADR 21).
String encoded(
  Collection collection, {
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
}) => codec.encode((name: name, display: display, collection: collection));

List<SourcedIssue> rejected(String yaml) {
  final result = codec.decode(yaml);
  expect(result, isA<Rejected<BarContent>>(), reason: 'expected Rejected');
  return (result as Rejected<BarContent>).issues;
}

void expectIssue(
  SourcedIssue actual,
  ValidationIssueKind kind,
  String location,
  int? line, {
  String? messagePart,
}) {
  expect(actual.issue.kind, kind, reason: '$actual');
  expect(actual.issue.location, location, reason: '$actual');
  expect(actual.line, line, reason: '$actual');
  if (messagePart != null) {
    expect(actual.issue.message, contains(messagePart), reason: '$actual');
  }
}

/// What every [BarStore] promises, whatever it stores into — run by the file
/// and memory store suites alike (docs/components.md#data-contracts).
void barStoreContract(BarStore Function() storeOf) {
  final collection = Collection(
    ingredients: [Ingredient('gin', stock: StockLevel.in_)],
    recipeTags: const [Tag('classic', color: TagColor.rose)],
  );
  final home = Bar(id: 'a1b2c3', name: 'Home bar', mode: BarMode.owner);
  final beach = Bar(
    id: 'd4e5f6',
    name: 'Beach bar',
    mode: BarMode.owner,
    display: FixedUnit.oz,
  );

  test('an untouched store holds no index', () async {
    expect(await storeOf().loadShelf(), isA<Empty<ShelfIndex>>());
  });

  test('a bar the store never held is Empty, not a failure', () async {
    expect(await storeOf().loadBar('a1b2c3'), isA<Empty<BarContent>>());
  });

  test('loadShelf returns what saveShelf was given', () async {
    final store = storeOf();
    await store.saveShelf((bars: [home, beach], openId: beach.id));
    final outcome = await store.loadShelf();
    expect(outcome, isA<Ok<ShelfIndex>>());
    expect((outcome as Ok<ShelfIndex>).value.bars, [home, beach]);
    expect(outcome.value.openId, beach.id);
  });

  test('a shelf with no bar open round-trips as one', () async {
    final store = storeOf();
    await store.saveShelf((bars: [home], openId: null));
    expect(((await store.loadShelf()) as Ok<ShelfIndex>).value.openId, isNull);
  });

  test('loadBar returns the collection saveBar was given', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    final outcome = await store.loadBar(home.id);
    expect(outcome, isA<Ok<BarContent>>());
    expect((outcome as Ok<BarContent>).value.collection, collection);
  });

  test('a bar\'s file carries its name and reading unit (ADR 21)', () async {
    final store = storeOf();
    await store.saveBar(beach, collection);
    final payload = ((await store.loadBar(beach.id)) as Ok<BarContent>).value;
    expect(payload.name, 'Beach bar');
    expect(payload.display, FixedUnit.oz);
  });

  test('the last of several saves of one bar wins', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(home, Collection());
    final payload = ((await store.loadBar(home.id)) as Ok<BarContent>).value;
    expect(payload.collection.ingredients, isEmpty);
  });

  test('saving one bar leaves another\'s contents alone (FR-BAR-1)', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(beach, Collection());
    final payload = ((await store.loadBar(home.id)) as Ok<BarContent>).value;
    expect(payload.collection, collection);
  });

  test('removeBar takes that bar and leaves the rest (FR-BAR-2)', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.saveBar(beach, collection);
    await store.removeBar(home.id);
    expect(await store.loadBar(home.id), isA<Empty<BarContent>>());
    expect(await store.loadBar(beach.id), isA<Ok<BarContent>>());
  });

  test('removing a bar the store never held changes nothing', () async {
    final store = storeOf();
    await store.saveBar(home, collection);
    await store.removeBar('nothing');
    expect(await store.loadBar(home.id), isA<Ok<BarContent>>());
  });

  test('every export purpose answers with a location', () async {
    final store = storeOf();
    for (final purpose in ExportPurpose.values) {
      expect(
        await store.exportSnapshot(home, collection, purpose: purpose),
        isNotEmpty,
        reason: purpose.name,
      );
    }
  });
}
