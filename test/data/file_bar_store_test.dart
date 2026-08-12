import 'dart:async';
import 'dart:io';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bar_store_contract.dart';

const codec = YamlCodec();

/// The on-disk names of docs/architecture.md#platform-facts, spelled out so a
/// rename in the adapter cannot pass unnoticed.
const indexName = 'shelf.yaml';
const legacyName = 'cocktails.yaml';
const beforeImportName = 'cocktails-before-import.yaml';
const beforeDeleteName = 'cocktails-before-delete.yaml';

String barName(String id) => 'bars/$id.yaml';

String backupName(String name, int index) =>
    '${name.substring(0, name.length - '.yaml'.length)}.backup-$index.yaml';

Collection collectionOf(String ingredient) =>
    Collection(ingredients: [Ingredient(ingredient, stock: StockLevel.in_)]);

final home = Bar(id: 'a1b2c3', name: 'Home bar', mode: BarMode.owner);
final beach = Bar(id: 'd4e5f6', name: 'Beach bar', mode: BarMode.owner);

BarPayload payloadOf(Bar bar, Collection collection) =>
    (name: bar.name, display: bar.display, collection: collection);

/// A format-1 file as this app wrote them before ADR 21 — the shape a device
/// upgrading into M31 is actually carrying. No `units:`, which is the shipped
/// vocabulary (ADR 09) and keeps the fixture to what the migration turns on.
String legacyText({String ingredient = 'gin', String display = 'oz'}) =>
    'format: 1\n\n'
    'settings:\n'
    '  part_ml: 30\n'
    '  oz_ml: 29.5735\n'
    '  display: $display\n\n'
    'ingredients:\n'
    '  - {name: $ingredient, stock: in}\n\n'
    'ingredient_tags: []\n\n'
    'recipe_tags: []\n\n'
    'recipes: []\n';

void main() {
  late Directory directory;
  late FileBarStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('cocktails_store');
    store = FileBarStore(directory);
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  File fileNamed(String name) => File('${directory.path}/$name');
  void writeFile(String name, String text) {
    final file = fileNamed(name);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(text);
  }

  String readFile(String name) => fileNamed(name).readAsStringSync();
  List<String> namesInDirectory([String sub = '']) => [
    for (final entity in Directory('${directory.path}/$sub').listSync())
      entity.path.split('/').last,
  ]..sort();

  group('BarStore contract', () => barStoreContract(() => store));

  group('loadShelf', () {
    test('a hand-written index decodes into its records', () async {
      writeFile(indexName, codec.encodeIndex((bars: [home], openId: home.id)));
      final outcome = await store.loadShelf() as Loaded<Records>;
      expect(outcome.value.bars, [home]);
      expect(outcome.value.openId, home.id);
    });

    test('a corrupt index with no backup reports the codec issues', () async {
      writeFile(indexName, 'format: 2\nbars: 5\n');
      final outcome = await store.loadShelf() as Corrupt<Records>;
      expect(outcome.recovered, isNull);
      expect(outcome.issues, isNotEmpty);
    });

    test('a corrupt index recovers the newest decodable backup', () async {
      writeFile(indexName, 'not: an index\n');
      writeFile(
        backupName(indexName, 1),
        codec.encodeIndex((bars: [home], openId: home.id)),
      );
      writeFile(
        backupName(indexName, 2),
        codec.encodeIndex((bars: [beach], openId: beach.id)),
      );
      final outcome = await store.loadShelf() as Corrupt<Records>;
      expect(outcome.issues, isNotEmpty);
      expect(outcome.recovered?.bars, [home]);
    });
  });

  group('loadBar', () {
    test('a hand-written bar file decodes into its payload', () async {
      writeFile(
        barName(home.id),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
      final outcome = await store.loadBar(home.id) as Loaded<BarPayload>;
      expect(outcome.value.collection, collectionOf('gin'));
      expect(outcome.value.name, 'Home bar');
    });

    test('a corrupt bar recovers its own newest decodable backup', () async {
      writeFile(barName(home.id), 'not: a bar\n');
      writeFile(
        backupName(barName(home.id), 1),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
      final outcome = await store.loadBar(home.id) as Corrupt<BarPayload>;
      expect(outcome.recovered?.collection, collectionOf('gin'));
    });

    test('an unreadable bar file is reported, not thrown', () async {
      writeFile(barName(home.id), '');
      fileNamed(barName(home.id)).writeAsBytesSync([0xC3, 0x28]);
      final outcome = await store.loadBar(home.id) as Corrupt<BarPayload>;
      expect(outcome.issues.single.issue.message, contains(home.id));
      expect(outcome.recovered, isNull);
    });

    test('an id that could name a path is refused, never resolved', () async {
      writeFile('secrets.yaml', codec.encode(payloadOf(home, Collection())));
      final outcome = await store.loadBar('../secrets') as Corrupt<BarPayload>;
      expect(outcome.issues.single.issue.message, contains('does not name'));
    });
  });

  group('saveBar', () {
    test('writes the canonical codec text under the bar\'s id', () async {
      await store.saveBar(home, collectionOf('gin'));
      expect(
        readFile(barName(home.id)),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
    });

    test('creates the bars directory when it is missing', () async {
      directory.deleteSync(recursive: true);
      await store.saveBar(home, collectionOf('gin'));
      expect(fileNamed(barName(home.id)).existsSync(), isTrue);
    });

    test('leaves no temp file behind', () async {
      await store.saveBar(home, collectionOf('gin'));
      await store.saveBar(home, collectionOf('rum'));
      expect(namesInDirectory('bars'), [
        backupName('${home.id}.yaml', 1),
        '${home.id}.yaml',
      ]);
    });

    test('each save backs up the file it replaces', () async {
      for (final name in ['gin', 'rum', 'vodka']) {
        await store.saveBar(home, collectionOf(name));
      }
      expect(
        readFile(backupName(barName(home.id), 1)),
        codec.encode(payloadOf(home, collectionOf('rum'))),
      );
      expect(
        readFile(backupName(barName(home.id), 2)),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
    });

    test('keeps three backups and drops the oldest', () async {
      for (final name in ['gin', 'rum', 'vodka', 'tequila', 'absinthe']) {
        await store.saveBar(home, collectionOf(name));
      }
      expect(fileNamed(backupName(barName(home.id), 4)).existsSync(), isFalse);
    });

    test('overlapping saves of one bar collapse to the latest', () async {
      await store.saveBar(home, collectionOf('gin'));
      await Future.wait([
        store.saveBar(home, collectionOf('rum')),
        store.saveBar(home, collectionOf('vodka')),
      ]);
      expect(
        readFile(barName(home.id)),
        codec.encode(payloadOf(home, collectionOf('vodka'))),
      );
      // One write, so one rotation: 'rum' never reached the disk.
      expect(fileNamed(backupName(barName(home.id), 2)).existsSync(), isFalse);
    });

    // The promise NFR-2 rests on, and the one this whole layout exists for.
    test('one bar\'s save leaves every other bar\'s bytes exactly', () async {
      await store.saveBar(home, collectionOf('gin'));
      final before = readFile(barName(home.id));
      final stat = fileNamed(barName(home.id)).statSync();
      for (final name in ['rum', 'vodka', 'tequila']) {
        await store.saveBar(beach, collectionOf(name));
      }
      expect(readFile(barName(home.id)), before);
      expect(fileNamed(barName(home.id)).statSync().modified, stat.modified);
      expect(namesInDirectory('bars'), contains('${home.id}.yaml'));
      expect(
        fileNamed(backupName(barName(home.id), 1)).existsSync(),
        isFalse,
        reason: 'nor did it rotate a backup it had no reason to',
      );
    });

    test('a failed write leaves that bar and its backups intact', () async {
      await store.saveBar(home, collectionOf('gin'));
      Directory('${directory.path}/${barName(home.id)}.tmp').createSync();
      await expectLater(
        store.saveBar(home, collectionOf('rum')),
        throwsA(isA<Exception>()),
      );
      expect(
        readFile(barName(home.id)),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
      expect(fileNamed(backupName(barName(home.id), 1)).existsSync(), isFalse);
    });
  });

  group('removeBar', () {
    test('takes the bar\'s file and every backup beside it', () async {
      for (final name in ['gin', 'rum', 'vodka']) {
        await store.saveBar(home, collectionOf(name));
      }
      await store.removeBar(home.id);
      expect(namesInDirectory('bars'), isEmpty);
    });

    test('an id that could name a path is refused', () async {
      writeFile('secrets.yaml', 'kept\n');
      await store.removeBar('../secrets');
      expect(fileNamed('secrets.yaml').existsSync(), isTrue);
    });
  });

  group('exportSnapshot', () {
    test('names the copy from the bar, and answers where', () async {
      await store.saveBar(home, collectionOf('gin'));
      final location = await store.exportSnapshot(home, collectionOf('gin'));
      expect(location, fileNamed('home-bar.yaml').path);
      // Byte-identical to the bar's own file: one canonical emitter (ADR 02).
      expect(readFile('home-bar.yaml'), readFile(barName(home.id)));
    });

    // A copy going out keeps no history: rotating one would leave three more
    // files in the backed-up directory for every share a reader made.
    test('a copy rotates no backups of its own', () async {
      for (var i = 0; i < 4; i++) {
        await store.exportSnapshot(home, collectionOf('gin'));
      }
      expect(namesInDirectory(), ['home-bar.yaml']);
    });

    test('two bars of different names get two files', () async {
      await store.exportSnapshot(home, Collection());
      await store.exportSnapshot(beach, Collection());
      expect(fileNamed('home-bar.yaml').existsSync(), isTrue);
      expect(fileNamed('beach-bar.yaml').existsSync(), isTrue);
    });

    test('a name with nothing to fold still makes a file', () async {
      final named = Bar(id: 'e7f8', name: '—', mode: BarMode.owner);
      expect(
        await store.exportSnapshot(named, Collection()),
        fileNamed('bar.yaml').path,
      );
    });

    test('exports what it is given, not what the file on disk holds', () async {
      // The recovered-from-corrupt session in miniature: the collection on
      // screen is not what the bar's file says, and the copy follows the
      // screen (ADR 18).
      await store.saveBar(home, collectionOf('gin'));
      await store.exportSnapshot(home, collectionOf('rum'));
      expect(
        readFile('home-bar.yaml'),
        codec.encode(payloadOf(home, collectionOf('rum'))),
      );
      expect(
        readFile(barName(home.id)),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
    });

    test('a save already under way is not disturbed', () async {
      unawaited(store.saveBar(home, collectionOf('gin')));
      await store.exportSnapshot(home, collectionOf('rum'));
      expect(
        readFile(barName(home.id)),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
    });

    test('the exported copy re-imports as the same collection', () async {
      final location = await store.exportSnapshot(home, collectionOf('gin'));
      final result = codec.decode(File(location).readAsStringSync());
      expect(
        (result as Decoded<BarPayload>).value.collection,
        collectionOf('gin'),
      );
    });

    test('each net has its own file (FR-DAT-3, FR-BAR-2)', () async {
      await store.exportSnapshot(home, collectionOf('gin'));
      await store.exportSnapshot(
        home,
        collectionOf('rum'),
        purpose: ExportPurpose.beforeImport,
      );
      await store.exportSnapshot(
        home,
        collectionOf('vodka'),
        purpose: ExportPurpose.beforeDelete,
      );
      // None writes over another: no one act can cost a reader the copy
      // another just staged.
      expect(
        readFile('home-bar.yaml'),
        codec.encode(payloadOf(home, collectionOf('gin'))),
      );
      expect(
        readFile(beforeImportName),
        codec.encode(payloadOf(home, collectionOf('rum'))),
      );
      expect(
        readFile(beforeDeleteName),
        codec.encode(payloadOf(home, collectionOf('vodka'))),
      );
    });
  });

  // docs/architecture.md#storage-isolation. The path a device that has been
  // running since format 1 actually takes on the upgrade.
  group('the format-1 migration', () {
    test('a legacy file with no index becomes the first owned bar', () async {
      writeFile(legacyName, legacyText());
      final records = ((await store.loadShelf()) as Loaded<Records>).value;
      expect(records.bars, hasLength(1));
      expect(records.openId, records.bars.single.id);
      expect(records.bars.single.mode, BarMode.owner);
      expect(records.bars.single.name, 'Home bar');
    });

    test('the collection comes across whole', () async {
      writeFile(legacyName, legacyText());
      final records = ((await store.loadShelf()) as Loaded<Records>).value;
      final payload =
          ((await store.loadBar(records.bars.single.id)) as Loaded<BarPayload>)
              .value;
      expect(payload.collection, collectionOf('gin'));
    });

    test('the reader\'s unit comes with it (ADR 21)', () async {
      writeFile(legacyName, legacyText(display: 'ml'));
      final records = ((await store.loadShelf()) as Loaded<Records>).value;
      expect(records.bars.single.display, FixedUnit.ml);
    });

    test('the bar is written as format 2', () async {
      writeFile(legacyName, legacyText());
      final records = ((await store.loadShelf()) as Loaded<Records>).value;
      expect(
        readFile(barName(records.bars.single.id)),
        startsWith('format: 2\nname: Home bar\n'),
      );
    });

    // The net. The old bytes are what a reader still has if anything here
    // went wrong, so nothing may touch them.
    test('the old file and its backups are left exactly alone', () async {
      writeFile(legacyName, legacyText());
      writeFile('cocktails.backup-1.yaml', legacyText(ingredient: 'rum'));
      await store.loadShelf();
      expect(readFile(legacyName), legacyText());
      expect(
        readFile('cocktails.backup-1.yaml'),
        legacyText(ingredient: 'rum'),
      );
    });

    test('a second run finds the index and migrates nothing', () async {
      writeFile(legacyName, legacyText());
      final first = ((await store.loadShelf()) as Loaded<Records>).value;
      final second =
          ((await FileBarStore(directory).loadShelf()) as Loaded<Records>)
              .value;
      expect(second.bars.single.id, first.bars.single.id);
    });

    test('an index already there wins over a legacy file beside it', () async {
      writeFile(
        indexName,
        codec.encodeIndex((bars: [beach], openId: beach.id)),
      );
      writeFile(legacyName, legacyText());
      final records = ((await store.loadShelf()) as Loaded<Records>).value;
      expect(records.bars, [beach]);
    });

    test(
      'a legacy file that will not decode is reported, not migrated',
      () async {
        writeFile(legacyName, 'format: 1\ningredients: 5\n');
        final outcome = await store.loadShelf() as Corrupt<Records>;
        expect(outcome.issues, isNotEmpty);
        expect(fileNamed(indexName).existsSync(), isFalse);
        expect(readFile(legacyName), 'format: 1\ningredients: 5\n');
      },
    );

    // The commit point. A crash between the two writes must leave no index,
    // so the next run migrates again rather than opening an absent bar.
    test('the bar\'s file lands before the index does', () async {
      writeFile(legacyName, legacyText());
      Directory('${directory.path}/$indexName.tmp').createSync();
      await expectLater(store.loadShelf(), throwsA(isA<Exception>()));
      expect(fileNamed(indexName).existsSync(), isFalse);
      expect(Directory('${directory.path}/bars').listSync(), hasLength(1));
    });

    test('a device with neither file is a first run', () async {
      expect(await store.loadShelf(), isA<Empty<Records>>());
    });
  });

  group('newBarId', () {
    test('is six hex characters a file can be named after', () {
      for (var i = 0; i < 50; i++) {
        final id = newBarId();
        expect(id, matches(RegExp(r'^[0-9a-f]{6}$')));
        expect(isStorableBarId(id), isTrue);
      }
    });

    test('refuses what could climb out of the bars directory', () {
      expect(isStorableBarId('../secrets'), isFalse);
      expect(isStorableBarId('a/b'), isFalse);
      expect(isStorableBarId(''), isFalse);
      expect(isStorableBarId('a1b2c3'), isTrue);
    });
  });
}
