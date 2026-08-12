/// The storage interface and its load outcomes: the seam keeping the domain
/// and the UI free of YAML (docs/architecture.md#storage-isolation).
library;

import 'dart:math';

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

/// The index: every bar and which is open, no collection in it (NFR-2).
typedef Records = ({List<Bar> bars, String? openId});

abstract interface class BarStore {
  Future<LoadOutcome<Records>> loadShelf();

  /// Contents, plus the name and unit the file carries — of which the index is
  /// the authority (ADR 21).
  Future<LoadOutcome<BarPayload>> loadBar(String id);

  Future<void> saveShelf(Records records);

  /// One file, no other bar's bytes read or rewritten (NFR-2).
  Future<void> saveBar(Bar bar, Collection collection);

  /// [id]'s file and its backups (FR-BAR-2).
  Future<void> removeBar(String id);

  /// A copy for [purpose], at an opaque location and following the screen
  /// rather than the file on disk (FR-DAT-1, ADR 18).
  Future<String> exportSnapshot(
    Bar bar,
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  });
}

/// Why a copy was written, never where — one file each, so no act costs a
/// reader the copy another just staged (FR-DAT-3, FR-BAR-2).
enum ExportPurpose { share, beforeImport, beforeDelete }

sealed class LoadOutcome<T> {
  const LoadOutcome();
}

final class Loaded<T> extends LoadOutcome<T> {
  final T value;

  const Loaded(this.value);
}

/// Nothing stored yet — a first run, or a bar whose file never landed.
final class Empty<T> extends LoadOutcome<T> {
  const Empty();
}

/// Unreadable (FR-DAT-4); [recovered] is the newest backup that decoded.
final class Corrupt<T> extends LoadOutcome<T> {
  final List<SourcedIssue> issues;
  final T? recovered;

  Corrupt(List<SourcedIssue> issues, {this.recovered})
    : issues = List.unmodifiable(issues);
}

/// Six hex characters, drawn here rather than in the domain, which stays clear
/// of ambient chance. Never in a bar's file, so no copy claims to be it (ADR 20).
String newBarId([Random? random]) {
  final draw = random ?? Random();
  return [
    for (var i = 0; i < 6; i++) draw.nextInt(16).toRadixString(16),
  ].join();
}

/// Whether [id] may name a file: an index carrying `../secrets` is refused.
bool isStorableBarId(String id) =>
    id.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
