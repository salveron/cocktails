/// Every fixed hue the app draws (docs/ui-design.md#tag-and-stock-colours).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

/// What a token wears in one theme: [fill] grounds a chip, [ink] letters it —
/// and [ink] alone draws a dot, being the half that carries against the page.
typedef Swatch = ({Color fill, Color ink});

/// Fixed hues, not scheme roles: the amber seed makes `primaryContainer` brown
/// and `tertiaryContainer` green, so in-stock and low wore each other's signal.
Swatch stockColors(StockLevel stock, Brightness brightness) => _forTheme(
  switch (stock) {
    StockLevel.in_ => const (pale: Color(0xFFC8E6C9), deep: Color(0xFF1B5E20)),
    StockLevel.low => const (pale: Color(0xFFFFECB3), deep: Color(0xFF6B4E00)),
    StockLevel.out => const (pale: Color(0xFFFFCDD2), deep: Color(0xFFB71C1C)),
  },
  brightness,
);

/// The palette a tag is painted from (docs/adr/07-tag-colour.md). A new
/// [TagColor] member will not compile until it is given a pair here.
Swatch tagColors(TagColor color, Brightness brightness) => _forTheme(
  switch (color) {
    TagColor.teal => const (pale: Color(0xFFA5DED6), deep: Color(0xFF00635A)),
    TagColor.indigo => const (pale: Color(0xFFC3C8F5), deep: Color(0xFF2F3A9E)),
    TagColor.plum => const (pale: Color(0xFFDEB8F2), deep: Color(0xFF6A1B9A)),
    TagColor.rose => const (pale: Color(0xFFF2A4C8), deep: Color(0xFF7A1149)),
    TagColor.sand => const (pale: Color(0xFFE8DCBE), deep: Color(0xFF6D5B3E)),
    TagColor.slate => const (pale: Color(0xFFAEBAC2), deep: Color(0xFF37474F)),
  },
  brightness,
);

/// Pale grounds a chip in light and letters it in dark; deep does the reverse.
Swatch _forTheme(({Color pale, Color deep}) tones, Brightness brightness) =>
    brightness == Brightness.light
    ? (fill: tones.pale, ink: tones.deep)
    : (fill: tones.deep, ink: tones.pale);
