/// The shapes a list is steered by: the orders it can be read in, a
/// narrowing's own shape and how a pick set changes, and the random draw one
/// offers (docs/ui-design.md#searchable-lists). What fills these shapes — the
/// tag row, the base spirit, the guest-bar pull — is each screen's or each
/// control's own.
library;

import 'package:flutter/material.dart';

/// The orders a list can be read in — a label each, and where it ranks an
/// entry — first the one the list opens in (docs/ui-design.md#searchable-lists).
/// Ranks come off the domain's own enums, whose declaration order is already
/// the traffic light and the palette.
typedef ListOrders<T> = Map<String, int Function(T entry)>;

const alphabetical = {'Name': alike};

int alike(Object? entry) => 0;

/// A pick set is what narrows a list — each control's own toggle changes it.
extension ToggleMembership<T> on Set<T> {
  void toggle(T value) {
    if (!remove(value)) add(value);
  }
}

/// Controls to narrow list: row widget, test function, human description, and
/// [picks] — what is chosen, spelled out, which is what tells one narrowing
/// from another where the sentence a reader is shown cannot.
typedef ListFilter<T> = ({
  Widget row,
  bool Function(T entry) test,
  String? narrowing,
  List<String> picks,
});

/// The button over a list that draws one of the rows on show — the recipes'
/// random pick (FR-DIS-5). It answers with the name to put on screen, or null
/// where it drew nothing, so a screen never learns where a row stands or how
/// the list scrolls to it (ADR 13).
///
/// [icon] is the drawn glyph rather than an `IconData`, since one off a font
/// whose glyphs are not square is drawn by its own widget (ADR 14) — so the
/// screen picking the glyph is the only place that font is named.
typedef RandomDraw<T> = ({
  Widget icon,
  String tooltip,
  String? Function(List<T> onShow) draw,
});
