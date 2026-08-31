/// Support the data suites share: the docs/architecture.md#data-format example
/// text, a matching [Collection], the decode/encode/reject shorthands built
/// over [YamlCodec], and the contract every [BarStore] promises whatever it
/// stores into (docs/components.md#testing).
library;

import 'dart:convert';
import 'dart:io';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

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

/// The docs/architecture.md#data-format example, read out of the doc rather
/// than copied — a copy is what let it drift a comment out of step once.
final commentedText = _fencedExample('docs/architecture.md', '```yaml');

String _fencedExample(String docPath, String fence) {
  final lines = File(docPath).readAsStringSync().split('\n');
  final start = lines.indexOf(fence) + 1;
  final end = lines.indexOf('```', start);
  return '${lines.sublist(start, end).join('\n')}\n';
}

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
    await store.saveShelf((
      bars: [home, beach],
      openId: beach.id,
      deviceName: null,
    ));
    final outcome = await store.loadShelf();
    expect(outcome, isA<Ok<ShelfIndex>>());
    expect((outcome as Ok<ShelfIndex>).value.bars, [home, beach]);
    expect(outcome.value.openId, beach.id);
  });

  test('a shelf with no bar open round-trips as one', () async {
    final store = storeOf();
    await store.saveShelf((bars: [home], openId: null, deviceName: null));
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

/// What every [BarChannel] promises, whatever text its transport hands back —
/// run by the file channel today and by a second transport once one lands
/// (ADR 22, docs/components.md#testing). A channel-specific test file keeps
/// what only its own transport does: how it mints a source, whether that
/// source is read, and what an empty answer means there.
void barChannelContract(
  BarChannel Function(Future<String?> Function() answering) channelOf,
) {
  final collection = Collection(
    ingredients: [Ingredient('gin', stock: StockLevel.in_)],
    recipes: [
      Recipe(
        'Martini',
        lines: const [
          RecipeLine(Amount(2), 'part', ['gin']),
        ],
      ),
    ],
  );
  final payload = (
    name: "Ada's bar",
    display: FixedUnit.ml,
    collection: collection,
  );
  final document = codec.encode(payload);
  const source = BarSource(via: Transport.file, at: '', from: '');

  test(
    'a fetch that lands arrives whole — name, display and collection',
    () async {
      final outcome = await channelOf(() async => document).fetch(source);
      expect(outcome, isA<Ok<BarContent>>());
      expect((outcome! as Ok<BarContent>).value, payload);
    },
  );

  test('a fetch that cannot be read is refused, placed by line', () async {
    final outcome = await channelOf(
      () async =>
          'format: 2\nname: Ada\nrecipes:\n  - name: Martini\n    lines:\n'
          '      - 2 part rye\n',
    ).fetch(source);
    expect(outcome, isA<Rejected<BarContent>>());
    final issues = (outcome! as Rejected<BarContent>).issues;
    expect(issues, isNotEmpty);
    expect(issues.first.issue.kind, ValidationIssueKind.unknownIngredient);
    expect(issues.first.line, isNotNull);
  });

  /// Which answer it is belongs to the transport — a picker that would not
  /// open is a file that could not be read, where a source that failed over
  /// the wire is one that could not be reached (FR-BAR-5). What every channel
  /// promises is that it answers at all.
  test('a fetch whose source fails answers rather than throwing', () async {
    final outcome = await channelOf(
      () async => throw StateError('no activity'),
    ).fetch(source);
    expect(outcome, isNot(isA<Ok<BarContent>>()));
  });
}

/// A request to a LAN server over the loopback, standing in for the guest that
/// would otherwise be a second device (docs/components.md#testing).
Future<({int status, String body})> askServer(
  int port,
  String path, {
  String method = 'GET',
}) async {
  final client = HttpClient();
  try {
    final request = await client.open(method, '127.0.0.1', port, path);
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decodeStream(response),
    );
  } finally {
    client.close();
  }
}

/// What the server on [port] says it offers, read by id the way a guest reads
/// it (FR-BAR-1) — the document parsed rather than its text, so the emitter's
/// layout stays pinned in its own test alone.
Future<Map<String, ({String name, String path})>> offeredOn(int port) async {
  final listed = await askServer(port, '/bars');
  expect(listed.status, 200);
  final bars = (loadYaml(listed.body) as YamlMap)['bars'] as YamlList;
  return {
    for (final bar in bars)
      bar['id'] as String: (
        name: bar['name'] as String,
        path: bar['path'] as String,
      ),
  };
}
