/// Material 3 app theme: the seed colour, the two schemes, `dimmedInk` — and
/// `MutedText`, the text anything secondary is read in, joining its sibling
/// (docs/ui-design.md#app-shell).
library;

import 'package:flutter/material.dart';

/// Whiskey amber — warm enough to read as a bar app without being a costume;
/// Material 3 derives both schemes from it (docs/ui-design.md#app-shell).
const seedColor = Color(0xFFB26A00);

/// The one dim, worn by a hint and by an ingredient a group offers that the bar
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

/// [text] at [style] (the surrounding default where null), read as anything
/// secondary is — a caption, a note, a name standing in for the one on show.
class MutedText extends StatelessWidget {
  const MutedText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: (style ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
