import 'package:flutter/material.dart';

/// Whiskey amber — warm enough to read as a bar app without being a costume;
/// Material 3 derives both schemes from it (docs/ui-design.md#app-shell).
const seedColor = Color(0xFFB26A00);

ThemeData cocktailsTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colors,
    // A hint is an offer, not content: dim enough that an empty field is never
    // read as a filled one (docs/ui-design.md#recipe-form).
    inputDecorationTheme: InputDecorationThemeData(
      hintStyle: TextStyle(
        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    ),
  );
}
