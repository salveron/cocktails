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

String backupName(int index) => 'cocktails.backup-$index.yaml';

Model modelOf(String ingredient) =>
    Model(ingredients: [Ingredient(ingredient, stock: StockLevel.in_)]);

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
    test('a hand-written file decodes into the model', () async {
      writeFile(storeName, codec.encode(modelOf('gin')));
      expect(((await store.load()) as Loaded).model, modelOf('gin'));
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
      writeFile(backupName(1), codec.encode(modelOf('gin')));
      writeFile(backupName(2), codec.encode(modelOf('rum')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.issues, isNotEmpty);
      expect(outcome.recoveredFromBackup, modelOf('gin'));
    });

    test('a corrupt backup is skipped for an older one that decodes', () async {
      writeFile(storeName, 'not: a store\n');
      writeFile(backupName(1), 'nor: this one\n');
      writeFile(backupName(3), codec.encode(modelOf('rum')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.recoveredFromBackup, modelOf('rum'));
    });

    test('an unreadable store file is reported, not thrown', () async {
      fileNamed(storeName).writeAsBytesSync([0xC3, 0x28]);
      writeFile(backupName(1), codec.encode(modelOf('gin')));
      final outcome = await store.load() as Corrupt;
      expect(outcome.issues.single.issue.message, contains(storeName));
      expect(outcome.issues.single.line, isNull);
      expect(outcome.recoveredFromBackup, modelOf('gin'));
    });
  });

  group('save', () {
    test('writes the canonical codec text', () async {
      await store.save(modelOf('gin'));
      expect(readFile(storeName), codec.encode(modelOf('gin')));
    });

    test('creates the directory when it is missing', () async {
      directory.deleteSync(recursive: true);
      await store.save(modelOf('gin'));
      expect(readFile(storeName), codec.encode(modelOf('gin')));
    });

    test('leaves no temp file behind', () async {
      await store.save(modelOf('gin'));
      await store.save(modelOf('rum'));
      expect(namesInDirectory(), [backupName(1), storeName]);
    });

    test('the first save backs up nothing', () async {
      await store.save(modelOf('gin'));
      expect(namesInDirectory(), [storeName]);
    });

    test('each save backs up the file it replaces', () async {
      for (final name in ['gin', 'rum', 'vodka']) {
        await store.save(modelOf(name));
      }
      expect(readFile(storeName), codec.encode(modelOf('vodka')));
      expect(readFile(backupName(1)), codec.encode(modelOf('rum')));
      expect(readFile(backupName(2)), codec.encode(modelOf('gin')));
    });

    test('keeps three backups and drops the oldest', () async {
      for (final name in ['gin', 'rum', 'vodka', 'tequila', 'absinthe']) {
        await store.save(modelOf(name));
      }
      expect(readFile(backupName(1)), codec.encode(modelOf('tequila')));
      expect(readFile(backupName(2)), codec.encode(modelOf('vodka')));
      expect(readFile(backupName(3)), codec.encode(modelOf('rum')));
      expect(fileNamed(backupName(4)).existsSync(), isFalse);
    });

    test('overlapping saves collapse to the latest model', () async {
      await store.save(modelOf('gin'));
      await Future.wait([
        store.save(modelOf('rum')),
        store.save(modelOf('vodka')),
      ]);
      expect(readFile(storeName), codec.encode(modelOf('vodka')));
      // One write, so one rotation: 'rum' never reached the disk.
      expect(readFile(backupName(1)), codec.encode(modelOf('gin')));
      expect(fileNamed(backupName(2)).existsSync(), isFalse);
    });

    test('a failed write leaves the store and its backups intact', () async {
      await store.save(modelOf('gin'));
      // A directory where the temp file goes: the write fails, nothing else.
      Directory('${directory.path}/$storeName.tmp').createSync();
      await expectLater(store.save(modelOf('rum')), throwsA(isA<Exception>()));
      expect(readFile(storeName), codec.encode(modelOf('gin')));
      expect(fileNamed(backupName(1)).existsSync(), isFalse);
    });
  });

  group('exportSnapshot', () {
    test('writes the model beside the store, and answers where', () async {
      await store.save(modelOf('gin'));
      final location = await store.exportSnapshot(modelOf('gin'));
      expect(location, fileNamed(exportName).path);
      // Byte-identical to the store file: one canonical emitter (ADR 02).
      expect(readFile(exportName), readFile(storeName));
    });

    test('exports what it is given, not what the file on disk holds', () async {
      // The recovered-from-corrupt session in miniature: the collection on
      // screen is not what the store file says, and the copy follows the
      // screen (ADR 18).
      await store.save(modelOf('gin'));
      await store.exportSnapshot(modelOf('rum'));
      expect(readFile(exportName), codec.encode(modelOf('rum')));
      expect(readFile(storeName), codec.encode(modelOf('gin')));
    });

    test('exports an empty database when nothing was saved yet', () async {
      await store.exportSnapshot(Model());
      expect(readFile(exportName), codec.encode(Model()));
      expect(fileNamed(storeName).existsSync(), isFalse);
    });

    test('a save already under way is not disturbed', () async {
      unawaited(store.save(modelOf('gin')));
      await store.exportSnapshot(modelOf('rum'));
      expect(readFile(storeName), codec.encode(modelOf('gin')));
      expect(readFile(exportName), codec.encode(modelOf('rum')));
    });

    test('the exported copy re-imports as the same model', () async {
      final model = modelOf('gin');
      final location = await store.exportSnapshot(model);
      final result = codec.decode(File(location).readAsStringSync());
      expect((result as Decoded).model, model);
    });
  });
}
