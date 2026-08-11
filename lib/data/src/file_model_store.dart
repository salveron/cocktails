/// File adapter: atomic writes, rolling backups, recovery from newest valid backup (ADR-02).
library;

import 'dart:io';

import 'package:cocktails/domain/domain.dart';

import 'model_store.dart';
import 'sourced_issue.dart';
import 'yaml_codec.dart';

/// How many rolling backups sit beside the store file.
const int _backupDepth = 3;

const String _storeName = 'cocktails.yaml';
const String _exportName = 'cocktails-export.yaml';

/// The copy an import keeps of the collection it replaced (FR-DAT-3). Its own
/// file, so an export never writes over the net and the net never writes over
/// a copy on its way out to a reader.
const String _beforeImportName = 'cocktails-before-import.yaml';

String _backupName(int index) => 'cocktails.backup-$index.yaml';

final class FileModelStore implements ModelStore {
  static const _codec = YamlCodec();

  /// Directory for store, backups, exports; testable with any path.
  final Directory directory;

  /// Queue serializes ops; [_pending] collapses overlapping saves.
  Future<void> _queue = Future.value();
  Collection? _pending;

  FileModelStore(this.directory);

  File get _storeFile => _fileNamed(_storeName);

  @override
  Future<LoadOutcome> load() => _enqueue(_load);

  @override
  Future<void> save(Collection collection) {
    _pending = collection;
    return _enqueue(_writePending);
  }

  @override
  Future<String> exportSnapshot(
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  }) => _enqueue(() => _export(collection, purpose));

  Future<LoadOutcome> _load() async {
    if (!await _storeFile.exists()) return const Empty();
    final String text;
    try {
      text = await _storeFile.readAsString();
    } on Exception catch (error) {
      return Corrupt([
        _unreadable(_storeName, error),
      ], recoveredFromBackup: await _recover());
    }
    final result = _codec.decode(text);
    return switch (result) {
      Decoded(:final collection) => Loaded(collection),
      Rejected(:final issues) => Corrupt(
        issues,
        recoveredFromBackup: await _recover(),
      ),
    };
  }

  /// Newest backup that decodes; null if none do.
  Future<Collection?> _recover() async {
    for (var index = 1; index <= _backupDepth; index++) {
      final file = _fileNamed(_backupName(index));
      try {
        if (!await file.exists()) continue;
        final result = _codec.decode(await file.readAsString());
        if (result is Decoded) return result.collection;
      } on Exception {
        continue;
      }
    }
    return null;
  }

  /// Writes pending collection; no-op if earlier queue entry already wrote it.
  Future<void> _writePending() async {
    final collection = _pending;
    if (collection == null) return;
    _pending = null;
    final temp = await _writeTemp(_storeFile, _codec.encode(collection));
    await _rotateBackups();
    await temp.rename(_storeFile.path);
  }

  Future<String> _export(Collection collection, ExportPurpose purpose) async {
    final copy = _fileNamed(switch (purpose) {
      ExportPurpose.share => _exportName,
      ExportPurpose.beforeImport => _beforeImportName,
    });
    await _write(copy, _codec.encode(collection));
    return copy.path;
  }

  /// Temp+rename pattern: readers never see half-written files.
  Future<void> _write(File target, String text) async =>
      (await _writeTemp(target, text)).rename(target.path);

  Future<File> _writeTemp(File target, String text) async {
    await directory.create(recursive: true);
    final temp = File('${target.path}.tmp');
    return temp.writeAsString(text, flush: true);
  }

  /// Rotates backups down; current store enters newest slot for survival.
  Future<void> _rotateBackups() async {
    if (!await _storeFile.exists()) return;
    final oldest = _fileNamed(_backupName(_backupDepth));
    if (await oldest.exists()) await oldest.delete();
    for (var index = _backupDepth - 1; index >= 1; index--) {
      final file = _fileNamed(_backupName(index));
      if (await file.exists()) {
        await file.rename(_fileNamed(_backupName(index + 1)).path);
      }
    }
    await _storeFile.copy(_fileNamed(_backupName(1)).path);
  }

  File _fileNamed(String name) => File('${directory.path}/$name');

  static SourcedIssue _unreadable(String name, Object error) => SourcedIssue(
    ValidationIssue(
      const [],
      ValidationIssueKind.malformedValue,
      'Could not read $name: $error',
    ),
    null,
  );

  /// Runs [action] after queued work; caller sees own failures.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
