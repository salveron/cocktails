/// Every ground a chip stands on (docs/ui-design.md#tag-and-stock-colours): the
/// fixed hues that mean something, and the one neutral that means nothing.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

typedef Swatch = ({Color fill, Color ink});

/// The one traffic light — worn by a bottle, by the recipe it holds up, and by
/// the bar all of it stands in. Fixed hues, not scheme roles, to avoid signal
/// confusion.
const _green = (pale: Color(0xFFC8E6C9), deep: Color(0xFF1B5E20));
const _amber = (pale: Color(0xFFFFECB3), deep: Color(0xFF6B4E00));
const _red = (pale: Color(0xFFFFCDD2), deep: Color(0xFFB71C1C));

Swatch stockColors(StockLevel stock, Brightness brightness) =>
    _forTheme(switch (stock) {
      StockLevel.in_ => _green,
      StockLevel.low => _amber,
      StockLevel.out => _red,
    }, brightness);

Swatch availabilityColors(Availability availability, Brightness brightness) =>
    _forTheme(switch (availability) {
      Availability.makeable => _green,
      Availability.makeableLow => _amber,
      Availability.missing => _red,
    }, brightness);

/// Tag color palette (new colors must be added here to compile).
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

/// What this device is to a bar (FR-BAR-3), on that same light: green where all
/// the app offers is offered, amber where half of it is not (FR-BAR-4).
Swatch barModeColors(BarMode mode, Brightness brightness) =>
    _forTheme(switch (mode) {
      BarMode.owner => _green,
      BarMode.guest => _amber,
    }, brightness);

/// What a chip carrying no signal stands on — the base filter, naming a bottle
/// rather than a level (ADR 12). Scheme roles precisely because every other
/// swatch is a fixed hue: this reads as neither tag nor traffic light.
Swatch neutralSwatch(ColorScheme colors) =>
    (fill: colors.surfaceContainerHighest, ink: colors.onSurfaceVariant);

/// Map tones to theme: pale fill/deep ink in light, reverse in dark.
Swatch _forTheme(({Color pale, Color deep}) tones, Brightness brightness) =>
    brightness == Brightness.light
    ? (fill: tones.pale, ink: tones.deep)
    : (fill: tones.deep, ink: tones.pale);
