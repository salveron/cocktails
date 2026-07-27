import 'package:flutter/material.dart';

/// Whiskey amber — warm enough to read as a bar app without being a costume;
/// Material 3 derives both schemes from it (docs/components.md#ui-shell).
const seedColor = Color(0xFFB26A00);

ThemeData cocktailsTheme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  ),
);
