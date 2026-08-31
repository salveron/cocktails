/// The one document a stranger writes and this app reads (ADR 22): what a
/// device offers, answered for whole or not at all.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/data/src/yaml_writer.dart' show encodeOfferings;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const home = (id: 'a1', name: 'Home bar', path: 'f00d');
  const beach = (id: 'b2', name: 'Beach bar', path: 'cafe');

  test('reads back what the emitter wrote, by id (FR-BAR-1)', () {
    final read = readOfferings(encodeOfferings(const [home, beach]));
    expect(read, {'a1': home, 'b2': beach});
  });

  /// A device that is up and offering nothing is not a device that will not
  /// answer: the guest is told the bar is withdrawn, not that nothing is there.
  test('a device offering nothing reads as an empty list', () {
    expect(readOfferings(encodeOfferings(const [])), isEmpty);
  });

  /// The number moves with the LAN protocol rather than the schema on disk, so
  /// a guest is turned away at discovery rather than part way through (ADR 22).
  test('a list of another lan_format is turned away', () {
    final ahead = encodeOfferings(const [
      home,
    ]).replaceFirst('lan_format: 1', 'lan_format: 2');
    expect(readOfferings(ahead), isNull);
  });

  test('a list naming no version at all is turned away', () {
    expect(readOfferings('bars: []\n'), isNull);
  });

  test('what is not a list of bars is turned away', () {
    for (final text in [
      'not yaml: [unclosed',
      'lan_format: 1\n',
      'lan_format: 1\nbars: nothing\n',
      'lan_format: 1\nbars:\n  - a scalar\n',
      '- a list\n',
    ]) {
      expect(readOfferings(text), isNull, reason: text);
    }
  });

  test('an entry missing what a fetch needs is turned away', () {
    for (final entry in [
      '{name: Home bar, path: f00d}',
      '{id: a1, path: f00d}',
      '{id: a1, name: Home bar}',
    ]) {
      expect(
        readOfferings('lan_format: 1\n\nbars:\n  - $entry\n'),
        isNull,
        reason: entry,
      );
    }
  });
}
