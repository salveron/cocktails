import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kind = ValidationIssueKind.emptyName;

  group('ValidationIssue', () {
    test('location renders keys and indexes', () {
      expect(
        ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops').location,
        'recipes[0].lines[2]',
      );
      expect(
        ValidationIssue(['settings', 'part_ml'], kind, 'oops').location,
        'settings.part_ml',
      );
    });

    test('an entry-relative issue has an empty location', () {
      expect(ValidationIssue(const [], kind, 'oops').location, '');
    });

    test('toString carries location and message', () {
      expect(
        ValidationIssue(['tags', 1], kind, 'oops').toString(),
        'tags[1]: oops',
      );
    });

    test(
      'equal path values, kind and message are equal, even from separate lists',
      () {
        final a = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
        final b = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
        expect(identical(a.path, b.path), isFalse);
        expect(a, b);
      },
    );

    test('hashCode agrees for equal issues', () {
      final a = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
      final b = ValidationIssue(['recipes', 0, 'lines', 2], kind, 'oops');
      expect(a.hashCode, b.hashCode);
    });

    test('differing path is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(ValidationIssue(['recipes', 1], kind, 'oops')),
      );
    });

    test('differing kind is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(
          ValidationIssue(
            ['recipes', 0],
            ValidationIssueKind.duplicateName,
            'oops',
          ),
        ),
      );
    });

    test('differing message is not equal', () {
      expect(
        ValidationIssue(['recipes', 0], kind, 'oops'),
        isNot(ValidationIssue(['recipes', 0], kind, 'other')),
      );
    });
  });
}
