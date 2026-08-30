import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/domain_test_support.dart';

void main() {
  final issue = ValidationIssue(
    const ['recipes', 0, 'lines', 2],
    ValidationIssueKind.malformedLine,
    'Unknown unit: "cup"',
  );

  group('SourcedIssue', () {
    valueEquality(() => SourcedIssue(issue, 5), {
      'line': SourcedIssue(issue, 6),
    });

    test('a null line is equal to another', () {
      expect(SourcedIssue(issue, null), SourcedIssue(issue, null));
    });

    test('prints the line ahead of the issue when it has one', () {
      expect(
        SourcedIssue(issue, 5).toString(),
        'line 5: recipes[0].lines[2]: Unknown unit: "cup"',
      );
      expect(
        SourcedIssue(issue, null).toString(),
        'recipes[0].lines[2]: Unknown unit: "cup"',
      );
    });
  });
}
