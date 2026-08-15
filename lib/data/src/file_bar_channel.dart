/// The file transport (FR-BAR-7): a bar travels as a document the reader hands
/// over, so every fetch is the picker and there is nothing to offer or
/// withdraw. The one interactive fetch, legal because none here is unattended
/// ([ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)).
library;

import 'package:cocktails/domain/domain.dart';

import 'bar_channel.dart';
import 'sourced_issue.dart';
import 'yaml_codec.dart';

final class FileBarChannel implements BarChannel {
  /// The one source a file bar keeps — no address, and no file names a sender.
  static const source = BarSource(via: Transport.file, at: '', from: '');

  /// The `filePickerProvider` seam handed in, so no file is needed here.
  final Future<String?> Function() _pick;

  const FileBarChannel(this._pick);

  @override
  Transport get transport => Transport.file;

  /// [source] goes unread: which document answers is the reader's judgement
  /// every time (ADR 21).
  @override
  Future<FetchOutcome?> fetch(BarSource source) async {
    final String? text;
    try {
      text = await _pick();
    } catch (error) {
      return Refused([_unreadable('$error')]);
    }
    if (text == null) return null;
    return switch (const YamlCodec().decode(text)) {
      Decoded(:final value) => Fetched(value),
      Rejected(:final issues) => Refused(issues),
    };
  }

  /// A picker that failed is a file the app could not read, which is what a
  /// refusal already says — and a fetch answers rather than throws (ADR 22).
  static SourcedIssue _unreadable(String error) => SourcedIssue(
    ValidationIssue(
      const [],
      ValidationIssueKind.malformedValue,
      'That file could not be read: $error',
    ),
    null,
  );
}
