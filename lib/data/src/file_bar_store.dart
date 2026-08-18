/// File adapter: one file per bar beside the index, atomic writes, rolling
/// backups per file, recovery from the newest valid backup (ADR 02), and the
/// one-way migration off the format-1 store (ADR 21).
library;

import 'dart:io';

import 'package:cocktails/domain/domain.dart';

import 'bar_store.dart';
import 'sourced_issue.dart';
import 'yaml_codec.dart';

/// How many rolling backups sit beside each file.
const int _backupDepth = 3;

const String _indexName = 'shelf';
const String _barsDirectory = 'bars';

/// The format-1 store this device may still be carrying, and the name the bar
/// migrated out of it is given (FR-BAR-2 lets the reader change it).
const String _legacyName = 'cocktails.yaml';
const String _migratedBarName = 'Home bar';

const String _beforeImportName = 'cocktails-before-import.yaml';
const String _beforeDeleteName = 'cocktails-before-delete.yaml';

final class FileBarStore implements BarStore {
  static const _codec = YamlCodec();

  /// Directory for the index, the bars, their backups and the copies;
  /// testable with any path.
  final Directory directory;

  /// Queue serializes ops across every file: two bars are never written in the
  /// same breath, and one order is what makes a refresh landing behind an edit
  /// predictable.
  Future<void> _queue = Future.value();

  /// Collapses overlapping saves of one bar; the index has its own slot.
  final Map<String, (Bar, Collection)> _pendingBars = {};
  Records? _pendingShelf;

  FileBarStore(this.directory);

  @override
  Future<Outcome<Records>> loadShelf() => _enqueue(_loadShelf);

  @override
  Future<Outcome<BarPayload>> loadBar(String id) => _enqueue(() {
    if (!isStorableBarId(id)) {
      return Future.value(Rejected<BarPayload>([_refusedId(id)]));
    }
    return _read(_barPath(id), '$_barsDirectory/$id.yaml', _codec.decode);
  });

  @override
  Future<void> saveShelf(Records records) {
    _pendingShelf = records;
    return _enqueue(_writePendingShelf);
  }

  @override
  Future<void> saveBar(Bar bar, Collection collection) {
    _pendingBars[bar.id] = (bar, collection);
    return _enqueue(() => _writePendingBar(bar.id));
  }

  @override
  Future<void> removeBar(String id) => _enqueue(() async {
    if (!isStorableBarId(id)) return;
    _pendingBars.remove(id);
    for (final file in [
      File(_barPath(id)),
      for (var i = 1; i <= _backupDepth; i++)
        File(_backupPath(_barPath(id), i)),
    ]) {
      if (await file.exists()) await file.delete();
    }
  });

  @override
  Future<String> exportSnapshot(
    Bar bar,
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  }) => _enqueue(() async {
    final copy = File(
      '${directory.path}/${switch (purpose) {
        // Named from the bar, so a reader holding three can tell them apart
        // (docs/architecture.md#platform-facts).
        ExportPurpose.share => '${_basenameOf(bar.name)}.yaml',
        ExportPurpose.beforeImport => _beforeImportName,
        ExportPurpose.beforeDelete => _beforeDeleteName,
      }}',
    );
    await _write(copy, _codec.encode(_payloadOf(bar, collection)));
    return copy.path;
  });

  /// The index, or the format-1 store migrated into one. A device with neither
  /// is a first run and answers [Empty].
  Future<Outcome<Records>> _loadShelf() async {
    if (await File(_indexPath).exists()) {
      return _read(_indexPath, '$_indexName.yaml', _codec.decodeIndex);
    }
    return await File('${directory.path}/$_legacyName').exists()
        ? _migrateLegacy()
        : const Empty();
  }

  /// The format-1 store read as an import would read it and written back out as
  /// this device's first owned bar (docs/architecture.md#storage-isolation).
  /// The bar's file lands **before** the index, which is the commit point: a
  /// crash between the two leaves no index, so the next run migrates again
  /// rather than opening a bar whose file never arrived. The old file and its
  /// backups are never touched, being the net this runs over.
  Future<Outcome<Records>> _migrateLegacy() async {
    final legacy = File('${directory.path}/$_legacyName');
    final Outcome<BarPayload> result;
    try {
      result = _codec.decode(await legacy.readAsString());
    } on Exception catch (error) {
      return Rejected([_unreadable(_legacyName, error)]);
    }
    if (result case Rejected(:final issues)) return Rejected(issues);
    final payload = (result as Ok<BarPayload>).value;
    final bar = Bar(
      id: newBarId(),
      name: payload.name.isEmpty ? _migratedBarName : payload.name,
      mode: BarMode.owner,
      // The reader's pick survives the move: it was in the old file's
      // settings and is the bar's from here on (ADR 21).
      display: payload.display,
    );
    final records = (bars: [bar], openId: bar.id);
    await _writeBar(bar, payload.collection);
    await _writeRotating(File(_indexPath), _codec.encodeIndex(records));
    return Ok(records);
  }

  /// [path]'s content through [decode], falling back to the newest backup that
  /// decodes. A file that is not there at all is [Empty], not a failure. A
  /// decode already answers in [Outcome]; attaching [recovered] to a rejection
  /// is this method's only conversion.
  Future<Outcome<T>> _read<T>(
    String path,
    String name,
    Outcome<T> Function(String) decode,
  ) async {
    final file = File(path);
    if (!await file.exists()) return const Empty();
    final String text;
    try {
      text = await file.readAsString();
    } on Exception catch (error) {
      return Rejected([
        _unreadable(name, error),
      ], recovered: await _recover(path, decode));
    }
    final result = decode(text);
    return result is Rejected<T>
        ? Rejected(result.issues, recovered: await _recover(path, decode))
        : result;
  }

  /// Newest backup of [path] that decodes; null if none do.
  Future<T?> _recover<T>(
    String path,
    Outcome<T> Function(String) decode,
  ) async {
    for (var index = 1; index <= _backupDepth; index++) {
      final file = File(_backupPath(path, index));
      try {
        if (!await file.exists()) continue;
        if (decode(await file.readAsString()) case Ok(:final value)) {
          return value;
        }
      } on Exception {
        continue;
      }
    }
    return null;
  }

  /// No-op where an earlier queue entry already wrote what was pending.
  Future<void> _writePendingBar(String id) async {
    final pending = _pendingBars.remove(id);
    if (pending == null) return;
    await _writeBar(pending.$1, pending.$2);
  }

  Future<void> _writeBar(Bar bar, Collection collection) => _writeRotating(
    File(_barPath(bar.id)),
    _codec.encode(_payloadOf(bar, collection)),
  );

  Future<void> _writePendingShelf() async {
    final records = _pendingShelf;
    if (records == null) return;
    _pendingShelf = null;
    await _writeRotating(File(_indexPath), _codec.encodeIndex(records));
  }

  /// Temp + rename: readers never see a half-written file.
  Future<void> _write(File target, String text) async =>
      (await _writeTemp(target, text)).rename(target.path);

  /// The same, with the file being replaced entering the newest backup slot on
  /// its way out. The store's own files only — a copy going out to a reader
  /// keeps no history, and rotating one would leave three more files in the
  /// backed-up directory for every share (docs/architecture.md#platform-facts).
  Future<void> _writeRotating(File target, String text) async {
    final temp = await _writeTemp(target, text);
    await _rotateBackups(target);
    await temp.rename(target.path);
  }

  Future<File> _writeTemp(File target, String text) async {
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.tmp');
    return temp.writeAsString(text, flush: true);
  }

  Future<void> _rotateBackups(File target) async {
    if (!await target.exists()) return;
    final oldest = File(_backupPath(target.path, _backupDepth));
    if (await oldest.exists()) await oldest.delete();
    for (var index = _backupDepth - 1; index >= 1; index--) {
      final file = File(_backupPath(target.path, index));
      if (await file.exists()) {
        await file.rename(_backupPath(target.path, index + 1));
      }
    }
    await target.copy(_backupPath(target.path, 1));
  }

  String get _indexPath => '${directory.path}/$_indexName.yaml';

  String _barPath(String id) => '${directory.path}/$_barsDirectory/$id.yaml';

  /// `<name>.backup-<index>.yaml` beside the file it backs up.
  static String _backupPath(String path, int index) =>
      '${path.substring(0, path.length - '.yaml'.length)}'
      '.backup-$index.yaml';

  static BarPayload _payloadOf(Bar bar, Collection collection) =>
      (name: bar.name, display: bar.display, collection: collection);

  /// A bar's name folded to something a file system and a stranger's downloads
  /// folder both take, `bar` where nothing survives the fold.
  static String _basenameOf(String name) {
    final folded = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return folded.isEmpty ? 'bar' : folded;
  }

  static SourcedIssue _unreadable(String name, Object error) =>
      _issue('Could not read $name: $error');

  static SourcedIssue _refusedId(String id) =>
      _issue('"$id" does not name a bar this device stored');

  static SourcedIssue _issue(String message) => SourcedIssue(
    ValidationIssue(const [], ValidationIssueKind.malformedValue, message),
    null,
  );

  /// Runs [action] after queued work; caller sees own failures.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}
