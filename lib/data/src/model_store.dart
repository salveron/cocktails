/// The storage interface and its load outcomes — the seam that keeps the
/// domain and the UI free of YAML, files, and the platform
/// (docs/architecture.md#storage-isolation).
library;

import 'package:cocktails/domain/domain.dart';

import 'sourced_issue.dart';

abstract interface class ModelStore {
  Future<LoadOutcome> load();

  Future<void> save(Collection collection);

  /// Writes a copy of [collection] for [purpose] and returns its opaque
  /// location: the store decides what a copy is and where it goes, and follows
  /// screen rather than the file on disk (FR-DAT-1, FR-DAT-3, ADR 18).
  Future<String> exportSnapshot(
    Collection collection, {
    ExportPurpose purpose = ExportPurpose.share,
  });
}

enum ExportPurpose { share, beforeImport }

sealed class LoadOutcome {
  const LoadOutcome();
}

final class Loaded extends LoadOutcome {
  final Collection collection;

  const Loaded(this.collection);
}

/// No store file yet — first run.
final class Empty extends LoadOutcome {
  const Empty();
}

/// The store file is missing content the app can read (FR-DAT-4).
final class Corrupt extends LoadOutcome {
  final List<SourcedIssue> issues;

  /// The newest backup that still decoded, null when none did.
  final Collection? recoveredFromBackup;

  Corrupt(List<SourcedIssue> issues, {this.recoveredFromBackup})
    : issues = List.unmodifiable(issues);
}
