import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('Amount', () {
    test('single value is not a range', () {
      const amount = Amount(1.5);
      expect(amount.min, 1.5);
      expect(amount.max, 1.5);
      expect(amount.isRange, isFalse);
    });

    test('range exposes both ends', () {
      const amount = Amount.range(1.5, 2);
      expect(amount.min, 1.5);
      expect(amount.max, 2);
      expect(amount.isRange, isTrue);
    });

    test('range with equal ends equals the single value', () {
      expect(const Amount.range(2, 2), const Amount(2));
    });

    valueEquality(() => const Amount.range(1.5, 2), const {
      'min': Amount.range(1, 2),
      'max': Amount.range(1.5, 3),
    });
  });
}
