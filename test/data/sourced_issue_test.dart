import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final issue = ValidationIssue(
    const ['recipes', 0, 'lines', 2],
    ValidationIssueKind.malformedLine,
    'Unknown unit: "cup"',
  );

  group('SourcedIssue', () {
    test('carries value equality', () {
      expect(SourcedIssue(issue, 5), SourcedIssue(issue, 5));
      expect(SourcedIssue(issue, 5).hashCode, SourcedIssue(issue, 5).hashCode);
      expect(SourcedIssue(issue, 5), isNot(SourcedIssue(issue, 6)));
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
