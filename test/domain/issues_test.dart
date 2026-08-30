import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/domain_test_support.dart';

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

    // Each build's own path is a fresh list, so this also proves equality
    // reads the path's values rather than its identity.
    valueEquality(() => ValidationIssue(['recipes', 0], kind, 'oops'), {
      'path': ValidationIssue(['recipes', 1], kind, 'oops'),
      'kind': ValidationIssue(
        ['recipes', 0],
        ValidationIssueKind.duplicateName,
        'oops',
      ),
      'message': ValidationIssue(['recipes', 0], kind, 'other'),
    });
  });
}
