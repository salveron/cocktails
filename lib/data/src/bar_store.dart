/// The storage interface, its loads answering in [Outcome]: the seam keeping
/// the domain and the UI free of YAML (docs/architecture.md#storage-isolation).
library;

import 'dart:math';

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

/// The index: every bar and which is open, no collection in it (NFR-2).
typedef Records = ({List<Bar> bars, String? openId});

abstract interface class BarStore {
  Future<Outcome<Records>> loadShelf();

  /// Name and unit ride along too; the index stays their authority (ADR 21).
  Future<Outcome<BarPayload>> loadBar(String id);

  Future<void> saveShelf(Records records);

  /// One file, no other bar's bytes read or rewritten (NFR-2).
  Future<void> saveBar(Bar bar, Collection collection);

  /// [id]'s file and its backups (FR-BAR-2).
  Future<void> removeBar(String id);

  /// A copy for [purpose], always the screen's state (FR-DAT-1, ADR 18).
  Future<String> exportSnapshot(
    Bar bar,
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  });
}

/// Why a copy was written, never where (FR-DAT-3, FR-BAR-2).
enum ExportPurpose { share, beforeImport, beforeDelete }

/// Six hex characters — keeps chance out of the domain (ADR 20).
String newBarId([Random? random]) {
  final draw = random ?? Random();
  return [
    for (var i = 0; i < 6; i++) draw.nextInt(16).toRadixString(16),
  ].join();
}

/// Whether [id] may name a file: an index carrying `../secrets` is refused.
bool isStorableBarId(String id) =>
    id.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
