library;

import 'dart:math';

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

typedef ShelfIndex = ({List<Bar> bars, String? openId, String? deviceName});

abstract interface class BarStore {
  Future<Outcome<ShelfIndex>> loadShelf();

  /// Name and unit ride along; the index stays their authority (ADR 21).
  Future<Outcome<BarContent>> loadBar(String id);

  Future<void> saveShelf(ShelfIndex records);

  /// One file, no other bar's bytes read or rewritten (NFR-2).
  Future<void> saveBar(Bar bar, Collection collection);

  /// Deletes [id]'s file and its backups (FR-BAR-2).
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

/// Random ids are minted here, keeping chance out of the domain (ADR 20).
String newBarId() {
  final draw = Random();
  return [
    for (var i = 0; i < 6; i++) draw.nextInt(16).toRadixString(16),
  ].join();
}

/// Refuses ids that cannot safely name a file, such as `../secrets`.
bool isStorableBarId(String id) =>
    id.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
