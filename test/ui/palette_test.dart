import 'dart:math';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG's contrast ratio, 1 (invisible) to 21 (black on white). AA asks 4.5 of
/// text this size.
double contrast(Color a, Color b) {
  final (high, low) = (a.computeLuminance(), b.computeLuminance());
  return (max(high, low) + 0.05) / (min(high, low) + 0.05);
}

/// How far apart two colours look, by the "redmean" approximation — a coarse
/// stand-in for perceived difference, but far closer to the eye than plain RGB
/// distance, and enough to catch two swatches nobody could tell apart.
double apart(Color a, Color b) {
  final (red, green, blue) = (
    255 * (a.r - b.r),
    255 * (a.g - b.g),
    255 * (a.b - b.b),
  );
  final mean = 255 * (a.r + b.r) / 2;
  return sqrt(
    (2 + mean / 256) * red * red +
        4 * green * green +
        (2 + (255 - mean) / 256) * blue * blue,
  );
}

/// Both halves of a token's pair, in the theme where each is the fill: what one
/// eye ever compares against another.
List<Color> fills(Swatch Function(Brightness) of) => [
  of(Brightness.light).fill,
  of(Brightness.dark).fill,
];

void main() {
  final palette = {
    for (final color in TagColor.values)
      color.token: fills((brightness) => tagColors(color, brightness)),
  };
  final signals = {
    for (final stock in StockLevel.values)
      stock.token: fills((brightness) => stockColors(stock, brightness)),
  };

  group('palette', () {
    test('every tag colour letters legibly on itself, in both themes', () {
      for (final color in TagColor.values) {
        for (final brightness in Brightness.values) {
          final swatch = tagColors(color, brightness);
          expect(
            contrast(swatch.fill, swatch.ink),
            greaterThanOrEqualTo(4.5),
            reason: '${color.token} in $brightness',
          );
        }
      }
    });

    test('the two themes swap the pair rather than repainting it', () {
      for (final color in TagColor.values) {
        final light = tagColors(color, Brightness.light);
        final dark = tagColors(color, Brightness.dark);
        expect((light.fill, light.ink), (dark.ink, dark.fill));
      }
    });

    test('no two tag colours could be mistaken for each other', () {
      for (final a in palette.entries) {
        for (final b in palette.entries) {
          if (a.key == b.key) continue;
          for (var theme = 0; theme < 2; theme++) {
            expect(
              apart(a.value[theme], b.value[theme]),
              greaterThanOrEqualTo(45),
              reason: '${a.key} against ${b.key}',
            );
          }
        }
      }
    });

    test('no tag colour reads as a stock signal', () {
      for (final tag in palette.entries) {
        for (final signal in signals.entries) {
          for (var theme = 0; theme < 2; theme++) {
            expect(
              apart(tag.value[theme], signal.value[theme]),
              greaterThanOrEqualTo(45),
              reason: '${tag.key} against ${signal.key}',
            );
          }
        }
      }
    });
  });
}
