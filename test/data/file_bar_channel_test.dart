/// The file transport (FR-BAR-7): every fetch is the picker, so what a reader
/// hands over — a bar, a file the app cannot read, nothing at all — is the
/// whole of what this channel can answer (ADR 22).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  group('channel contract', () => barChannelContract(FileBarChannel.new));

  /// A channel over a picker answering [text].
  FileBarChannel picking(String? text) => FileBarChannel(() async => text);

  test('the transport it answers for is the file', () {
    expect(picking(null).transport, Transport.file);
  });

  /// The address is empty because there is none: the reader is asked every
  /// time, and no file names who sent it.
  test('the source it mints holds no address and no sender', () {
    expect(
      FileBarChannel.source,
      const BarSource(via: Transport.file, at: '', from: ''),
    );
  });

  /// The source is unread: which document answers is the reader's judgement,
  /// so a bar sourced from anywhere else would still be met by the picker.
  test('the source it is handed goes unread', () async {
    final channel = picking(encoded(Collection()));
    const elsewhere = BarSource(
      via: Transport.lan,
      at: '10.0.0.4',
      from: 'Ada',
    );
    expect(await channel.fetch(elsewhere), isA<Ok<BarContent>>());
  });

  test('a reader who picks nothing has not fetched at all', () async {
    expect(await picking(null).fetch(FileBarChannel.source), isNull);
  });
}
