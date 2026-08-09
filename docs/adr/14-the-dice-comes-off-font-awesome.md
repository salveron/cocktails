# ADR: The dice comes off Font Awesome

**Status:** Accepted

## Context

ADR 13 set bar for sixth dependency: *confined to one file, way out written down*. M20 used `Icons.casino_rounded` (single die, looks like domino at 24px in 56px button). Seven icon sets surveyed; only Font Awesome and Lucide carry a pair. Symbols closest is `ifl` (single 3D die); others single 3D dice.

## Decision

**Font Awesome `dice` on `font_awesome_flutter`, by caret.**

- Two solid dice, silhouette survives at 24px. Lucide outlined pair crowds; second die reads as noise.
- `ListDraw.icon` carries widget, not `IconData`. Font Awesome glyphs non-square; `FaIcon` drops `SizedBox` Flutter's `Icon` imposes. Keeps font name out of `vocabulary_list.dart`.
- By caret (not pinned): steady release cadence, opposite of ADR 13's dormant package.
- Fallback one line: any `IconData` wrapped in `Icon` is valid `ListDraw.icon`; dropping package costs glyph, not redesign.

## Alternatives considered

- **Ionicons `dice_outline`**: last release January 2023, no longer compiles (`IconData` became `final class`). Dormancy ADR 13 priced realized.
- **Vendor font subset**: Ionicons MIT, `pyftsubset` cuts to 1.1 KB. Passed: trades dependency for binary blob, licence, regeneration recipe.
- **Material Symbols `ifl`**: live package, clean die; one die, 11 MB font.
- **Keep `casino_rounded`**: free, shape already rejected.

## Consequences

- A sixth dependency, taken under the fifth's rule. The bar stands where ADR 13 put it.
- `ListDraw` names a widget, so any list's draw button can wear a glyph from any font without the
  shared list learning which.
- **The font costs ~302 KB, and tree-shaking will not touch it.** The style actually used shrinks
  from 414,664 to 1,596 bytes (99.6%), but the shaker only shrinks a style *some* glyph is drawn
  from — the unused `Brands` (215 KB) and `Free-Regular` (87 KB) files ship whole
  ([flutter#64106](https://github.com/flutter/flutter/issues/64106)). Measured on a release APK, not
  assumed; `flutter build bundle` shakes nothing and will say otherwise. It is ~0.6% of the build
  and was accepted at that price. The package's own configurator can drop styles, but only by
  vendoring the package — at which point the subset above is the better trade.
