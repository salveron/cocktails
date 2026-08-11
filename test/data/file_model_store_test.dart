import 'dart:async';
import 'dart:io';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'model_store_contract.dart';

const codec = YamlCodec();

/// The on-disk names of docs/architecture.md#platform-facts, spelled out so a
/// rename in the adapter cannot pass unnoticed.
const storeName = 'cocktails.yaml';
const exportName = 'cocktails-export.yaml';
const beforeImportName = 'cocktails-before-import.yaml';

String backupName(int index) => 'cocktails.backup-$index.yaml';

Collection collectionOf(String ingredient) =>
    Collection(ingredients: [Ingredient(ingredient, stock: StockLevel.in_)]);

void main() {
  late Directory directory;
  late FileModelStore store;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('cocktails_store');
    store = FileModelStore(directory);
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  File fileNamed(String name) => File('${directory.path}/$name');
  void writeFile(String name, String text) =>
      fileNamed(name).writeAsStringSync(text);
  String readFile(String name) => fileNamed(name).readAsStringSync();
  List<String> namesInDirectory() =>
      [for (final entity in directory.listSync()) entity.path.split('/').last]
        ..sort();

  group('ModelStore contract', () => modelStoreContract(() => store));

  group('load', () {
    test('a hand-written file decodes into the collection', () async {
      writeFile(storeName, codec.encode(collectionOf('gin')));
      expect(((await store.load()) as Loaded).collection, collectionOf('gin'));
    });

    test('a corrupt store with no backup reports the codec issues', () async {
      writeFile(storeName, 'format: 1\ningredients: 5\n');
      final outcome = await store.load() as Corrupt;
      expect(outcome.recoveredFromBackup, isNull);
      expect(outcome.issues, hasLength(1));
      expect(outcome.issues.single.line, 2);
    });

    test('a corrupt store recovers the newest decodable backup', () async {
      writeFile(storeName, 'not: a store\n');
      writeFile(backupName(1), codec.encode(collectionOf('gin')));
      writeFile(backupName(2), codec.encode(collectionOf('rum')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.issues, isNotEmpty);
      expect(outcome.recoveredFromBackup, collectionOf('gin'));
    });

    test('a corrupt backup is skipped for an older one that decodes', () async {
      writeFile(storeName, 'not: a store\n');
      writeFile(backupName(1), 'nor: this one\n');
      writeFile(backupName(3), codec.encode(collectionOf('rum')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.recoveredFromBackup, collectionOf('rum'));
    });

    test('an unreadable store file is reported, not thrown', () async {
      fileNamed(storeName).writeAsBytesSync([0xC3, 0x28]);
      writeFile(backupName(1), codec.encode(collectionOf('gin')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.issues.single.issue.message, contains(storeName));
      expect(outcome.issues.single.line, isNull);
      expect(outcome.recoveredFromBackup, collectionOf('gin'));
    });
  });

  group('save', () {
    test('writes the canonical codec text', () async {
      await store.save(collectionOf('gin'));
      expect(readFile(storeName), codec.encode(collectionOf('gin')));
    });

    test('creates the directory when it is missing', () async {
      directory.deleteSync(recursive: true);
      await store.save(collectionOf('gin'));
      expect(readFile(storeName), codec.encode(collectionOf('gin')));
    });

    test('leaves no temp file behind', () async {
      await store.save(collectionOf('gin'));
      await store.save(collectionOf('rum'));
      expect(namesInDirectory(), [backupName(1), storeName]);
    });

    test('the first save backs up nothing', () async {
      await store.save(collectionOf('gin'));
      expect(namesInDirectory(), [storeName]);
    });

    test('each save backs up the file it replaces', () async {
      for (final name in ['gin', 'rum', 'vodka']) {
        await store.save(collectionOf(name));
      }
      expect(readFile(storeName), codec.encode(collectionOf('vodka')));
      expect(readFile(backupName(1)), codec.encode(collectionOf('rum')));
      expect(readFile(backupName(2)), codec.encode(collectionOf('gin')));
    });

    test('keeps three backups and drops the oldest', () async {
      for (final name in ['gin', 'rum', 'vodka', 'tequila', 'absinthe']) {
        await store.save(collectionOf(name));
      }
      expect(readFile(backupName(1)), codec.encode(collectionOf('tequila')));
      expect(readFile(backupName(2)), codec.encode(collectionOf('vodka')));
      expect(readFile(backupName(3)), codec.encode(collectionOf('rum')));
      expect(fileNamed(backupName(4)).existsSync(), isFalse);
    });

    test('overlapping saves collapse to the latest collection', () async {
      await store.save(collectionOf('gin'));
      await Future.wait([
        store.save(collectionOf('rum')),
        store.save(collectionOf('vodka')),
      ]);
      expect(readFile(storeName), codec.encode(collectionOf('vodka')));
      // One write, so one rotation: 'rum' never reached the disk.
      expect(readFile(backupName(1)), codec.encode(collectionOf('gin')));
      expect(fileNamed(backupName(2)).existsSync(), isFalse);
    });

    test('a failed write leaves the store and its backups intact', () async {
      await store.save(collectionOf('gin'));
      // A directory where the temp file goes: the write fails, nothing else.
      Directory('${directory.path}/$storeName.tmp').createSync();
      await expectLater(
        store.save(collectionOf('rum')),
        throwsA(isA<Exception>()),
      );
      expect(readFile(storeName), codec.encode(collectionOf('gin')));
      expect(fileNamed(backupName(1)).existsSync(), isFalse);
    });
  });

  group('exportSnapshot', () {
    test('writes the collection beside the store, and answers where', () async {
      await store.save(collectionOf('gin'));
      final location = await store.exportSnapshot(collectionOf('gin'));
      expect(location, fileNamed(exportName).path);
      // Byte-identical to the store file: one canonical emitter (ADR 02).
      expect(readFile(exportName), readFile(storeName));
    });

    test('exports what it is given, not what the file on disk holds', () async {
      // The recovered-from-corrupt session in miniature: the collection on
      // screen is not what the store file says, and the copy follows the
      // screen (ADR 18).
      await store.save(collectionOf('gin'));
      await store.exportSnapshot(collectionOf('rum'));
      expect(readFile(exportName), codec.encode(collectionOf('rum')));
      expect(readFile(storeName), codec.encode(collectionOf('gin')));
    });

    test('exports an empty database when nothing was saved yet', () async {
      await store.exportSnapshot(Collection());
      expect(readFile(exportName), codec.encode(Collection()));
      expect(fileNamed(storeName).existsSync(), isFalse);
    });

    test('a save already under way is not disturbed', () async {
      unawaited(store.save(collectionOf('gin')));
      await store.exportSnapshot(collectionOf('rum'));
      expect(readFile(storeName), codec.encode(collectionOf('gin')));
      expect(readFile(exportName), codec.encode(collectionOf('rum')));
    });

    test('the exported copy re-imports as the same collection', () async {
      final collection = collectionOf('gin');
      final location = await store.exportSnapshot(collection);
      final result = codec.decode(File(location).readAsStringSync());
      expect((result as Decoded).collection, collection);
    });

    test('the copy an import keeps has its own file (FR-DAT-3)', () async {
      await store.exportSnapshot(collectionOf('gin'));
      await store.exportSnapshot(
        collectionOf('rum'),
        purpose: ExportPurpose.beforeImport,
      );
      // Neither writes over the other: an import cannot cost a reader the copy
      // they exported, and an export cannot cost them the net.
      expect(readFile(exportName), codec.encode(collectionOf('gin')));
      expect(readFile(beforeImportName), codec.encode(collectionOf('rum')));
    });
  });
}
