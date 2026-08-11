import 'package:cocktails/domain/src/names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('duplicateNameIndexes', () {
    test('empty and unique lists have no duplicates', () {
      expect(duplicateNameIndexes([]), isEmpty);
      expect(duplicateNameIndexes(['a', 'b']), isEmpty);
    });

    test('reports every repeated position', () {
      expect(duplicateNameIndexes(['a', 'b', 'a', 'a']), [2, 3]);
    });
  });

  group('listEquals', () {
    test('equal lists of equal elements are equal', () {
      expect(listEquals(<int>[], <int>[]), isTrue);
      expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
    });

    test('different lengths are never equal', () {
      expect(listEquals([1, 2], [1, 2, 3]), isFalse);
      expect(listEquals([1, 2, 3], [1, 2]), isFalse);
    });

    test('same length with a differing element is not equal', () {
      expect(listEquals([1, 2, 3], [1, 9, 3]), isFalse);
    });
  });
}
