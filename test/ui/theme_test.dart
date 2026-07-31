import 'package:cocktails/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('theme', () {
    test('a hint reads fainter than what is typed over it', () {
      for (final brightness in Brightness.values) {
        final hint = cocktailsTheme(brightness).inputDecorationTheme.hintStyle;
        expect(hint?.color?.a, lessThan(1), reason: '$brightness');
        expect(hint?.color?.a, greaterThan(0.4), reason: '$brightness');
      }
    });
  });
}
