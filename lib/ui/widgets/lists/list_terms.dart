/// The shapes a list is steered by, each filled by the screen or control that
/// owns it (docs/ui-design.md#searchable-lists).
library;

import 'package:flutter/material.dart';

typedef ListOrders<T> = Map<String, int Function(T entry)>;

const alphabetical = {'Name': alike};

int alike(Object? entry) => 0;

/// Controls to narrow a list — [picks] is `entry_list`'s own change-detection
/// key, [tagPicks] the tag names alone a caller may search or dot by.
typedef ListFilter<T> = ({
  Widget row,
  bool Function(T entry) test,
  String? narrowing,
  List<String> picks,
  List<String> tagPicks,
});

/// Draws one of a list's rows on show (FR-DIS-5); [icon] draws through its
/// own widget rather than an `IconData`, glyphs off-square being ADR 14's own.
typedef RandomDraw<T> = ({
  Widget icon,
  String tooltip,
  String? Function(List<T> onShow) draw,
});
