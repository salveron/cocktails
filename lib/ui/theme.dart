import 'package:flutter/material.dart';

/// Whiskey amber — warm enough to read as a bar app without being a costume;
/// Material 3 derives both schemes from it (docs/ui-design.md#app-shell).
const seedColor = Color(0xFFB26A00);

/// The one dim, worn by a hint and by a bottle a group offers that the bar
/// lacks: faint enough that neither reads as the text beside it (ui-design.md).
Color dimmedInk(ColorScheme colors) =>
    colors.onSurfaceVariant.withValues(alpha: 0.6);

ThemeData cocktailsTheme(Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colors,
    inputDecorationTheme: InputDecorationThemeData(
      hintStyle: TextStyle(color: dimmedInk(colors)),
    ),
  );
}
