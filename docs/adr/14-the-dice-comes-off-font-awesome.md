# ADR: The dice comes off Font Awesome

**Status:** Accepted

## Context

[ADR 13](13-lists-scroll-by-index.md) took the fifth dependency and set the bar for the sixth:
*confined to one file, with the way out written down*.

M20's dice was `Icons.casino_rounded` — one die, five dots, the only filled die in the icon font
Flutter ships. A random pick reads as dice being *thrown*, and one die at the 24px an icon occupies
inside a 56px button reads as a domino tile. The shipped font offers nothing better: its other
three cuts of `casino` are the same die, and the outlined one reads as a keypad at that size.

Seven icon sets were surveyed for a pair of dice. Only two carry one: Font Awesome's `dice` and
Lucide's `dices`. Material Symbols' closest is `ifl`, a single die with three diagonal dots;
Ionicons', Tabler's and Remix's are all single dice, mostly drawn in 3-D.

## Decision

**The dice is Font Awesome's `dice`, on `font_awesome_flutter`.**

- Two dice, solid — the only candidate whose silhouette survives at 24px. Lucide's outlined pair
  crowds at that size, the second die reading as noise against the first.
- **`ListDraw.icon` carries a widget, not an `IconData`.** Font Awesome's glyphs are not square, and
  `FaIcon` exists for it: it drops the square `SizedBox` Flutter's own `Icon` imposes, laying a wide
  glyph out at its width rather than centring it in a box it overflows. Passing
  `FontAwesomeIcons.dice.data` to a plain `Icon` would draw it, wrongly. Carrying the widget puts
  the choice where the glyph is chosen, and keeps the font's name out of `vocabulary_list.dart` —
  ADR 13's bar, met the same way it was set.
- **By caret, not pinned.** ADR 13 pinned `scrollable_positioned_list` exactly *because* it is
  dormant: a release out of a quiet package wants reading before it resolves into a build. This one
  is the opposite case — a steady cadence, released within the year — so keeping up is the cheaper
  reading of its risk. The two lines in `pubspec.yaml` say which rule each is under.
- **The way out is one line.** Any `IconData` is a valid `ListDraw.icon` once wrapped in `Icon`, so
  dropping the package costs a glyph, not a redesign.

## Alternatives considered

- **Ionicons `dice_outline`.** Chosen first and found unusable: the package was last released in
  January 2023 and no longer compiles, `IconData` having since become a `final class` that
  `class IoniconsData extends IconData` cannot subclass. A reminder that the dormancy ADR 13 priced
  as a risk is one this collection actually realises.
- **Vendor a font subset.** Ionicons is MIT, and `pyftsubset` cuts it to **1.1 KB** for the one
  glyph — no dependency at all, and 300× smaller than what was taken. Passed over deliberately: it
  trades a dependency for a binary blob, a licence attribution, and a regeneration recipe nothing
  in the repo would ever run twice. Still the cheapest answer if the size below ever starts to
  matter.
- **Material Symbols `ifl`.** A live package and a clean die, but one die, behind an 11 MB font.
- **Keep `casino_rounded`.** Free, and the shape already rejected.

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
