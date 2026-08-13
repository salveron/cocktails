/// Where the platform crosses in, one provider each so a test swaps in a
/// function (ADR 18, docs/architecture.md#platform-facts).
library;

import 'dart:convert';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final barStoreProvider = Provider<BarStore>(
  (ref) => throw UnimplementedError('barStoreProvider must be overridden'),
);

/// Takes an export's opaque location; `text/plain`, Android knowing no YAML.
final sharerProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (location) => SharePlus.instance.share(
        ShareParams(files: [XFile(location, mimeType: 'text/plain')]),
      ),
);

/// The picked text, null where nothing was picked; no filter would match.
final filePickerProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final picked = await openFile();
    return picked == null ? null : pickedText(picked);
  },
);

/// Named, not inlined: overriding the provider with a plain string never
/// reaches this, and `readAsString` drops its own encoding here. Malformed
/// input throws over substituting U+FFFD, the same loss made quieter.
Future<String> pickedText(XFile picked) async =>
    utf8.decode(await picked.readAsBytes());

/// What a picked file turned out to be (FR-DAT-4). Never both.
typedef ImportReview = ({BarPayload? bar, List<String> issues});
