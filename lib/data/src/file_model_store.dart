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

String _backupName(int index) => 'cocktails.backup-$index.yaml';

final class FileModelStore implements ModelStore {
  static const _codec = YamlCodec();

  /// Directory for store, backups, exports; testable with any path.
  final Directory directory;

  /// Queue serializes ops; [_pending] collapses overlapping saves.
  Future<void> _queue = Future.value();
  Model? _pending;

  FileModelStore(this.directory);

  File get _storeFile => _fileNamed(_storeName);

  @override
  Future<LoadOutcome> load() => _enqueue(_load);

  @override
  Future<void> save(Model model) {
    _pending = model;
    return _enqueue(_writePending);
  }

  @override
  Future<String> exportSnapshot(Model model) => _enqueue(() => _export(model));

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
      Decoded(:final model) => Loaded(model),
      Rejected(:final issues) => Corrupt(
        issues,
        recoveredFromBackup: await _recover(),
      ),
    };
  }

  /// Newest backup that decodes; null if none do.
  Future<Model?> _recover() async {
    for (var index = 1; index <= _backupDepth; index++) {
      final file = _fileNamed(_backupName(index));
      try {
        if (!await file.exists()) continue;
        final result = _codec.decode(await file.readAsString());
        if (result is Decoded) return result.model;
      } on Exception {
        continue;
      }
    }
    return null;
  }

  /// Writes pending model; no-op if earlier queue entry already wrote it.
  Future<void> _writePending() async {
    final model = _pending;
    if (model == null) return;
    _pending = null;
    final temp = await _writeTemp(_storeFile, _codec.encode(model));
    await _rotateBackups();
    await temp.rename(_storeFile.path);
  }

  Future<String> _export(Model model) async {
    final copy = _fileNamed(_exportName);
    await _write(copy, _codec.encode(model));
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
