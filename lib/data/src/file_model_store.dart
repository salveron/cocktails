/// The file adapter behind [ModelStore]: atomic writes, rolling backups, and
/// recovery from the newest backup that still decodes — the single-writer
/// discipline of docs/adr/02-persistence-and-export-format.md. File names and
/// backup depth are docs/architecture.md#platform-facts.
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

  /// Where the store, its backups, and the export copy live. The platform
  /// path is resolved at the composition root, so this adapter is testable
  /// against any directory.
  final Directory directory;

  /// Serialises every operation; [_pending] collapses overlapping saves so
  /// only the latest model reaches the disk.
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
  Future<String> exportSnapshot() => _enqueue(_export);

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

  /// The newest backup that decodes, null when none does.
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

  /// Writes whatever [save] last handed over; a no-op once an earlier queue
  /// entry has already written it.
  Future<void> _writePending() async {
    final model = _pending;
    if (model == null) return;
    _pending = null;
    final temp = await _writeTemp(_storeFile, _codec.encode(model));
    await _rotateBackups();
    await temp.rename(_storeFile.path);
  }

  Future<String> _export() async {
    final copy = _fileNamed(_exportName);
    await _write(
      copy,
      await _storeFile.exists()
          ? await _storeFile.readAsString()
          : _codec.encode(Model()),
    );
    return copy.path;
  }

  /// Temp file, then rename: a reader never sees a half-written file, and a
  /// failed write leaves the previous content and the backups untouched.
  Future<void> _write(File target, String text) async =>
      (await _writeTemp(target, text)).rename(target.path);

  Future<File> _writeTemp(File target, String text) async {
    await directory.create(recursive: true);
    final temp = File('${target.path}.tmp');
    return temp.writeAsString(text, flush: true);
  }

  /// Shifts the backups down and copies the current store into the newest
  /// slot, so the file being replaced survives.
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

  /// Runs [action] after everything already queued, whether that succeeded or
  /// failed; the caller still sees its own failure.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
