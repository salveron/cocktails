import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  tokenVocabulary(
    'Transport',
    values: Transport.values,
    token: (value) => value.token,
    fromToken: Transport.fromToken,
    tokens: const ['file', 'lan', 'cloud'],
    unknown: 'bluetooth',
  );

  group('BarSource', () {
    valueEquality(
      () => const BarSource(via: Transport.lan, at: 'a', from: 'b'),
      const {
        'via': BarSource(via: Transport.file, at: 'a', from: 'b'),
        'at': BarSource(via: Transport.lan, at: 'z', from: 'b'),
        'from': BarSource(via: Transport.lan, at: 'a', from: 'z'),
      },
    );
  });
}
