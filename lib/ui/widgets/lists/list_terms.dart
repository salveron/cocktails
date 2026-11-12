/// List shapes, each filled by its owner (docs/ui-design.md#searchable-lists).
library;

import 'package:flutter/material.dart';

typedef ListOrders<T> = Map<String, int Function(T entry)>;

const alphabetical = {'Name': alike};

int alike(Object? entry) => 0;

/// [chips] ride the list's one chip row; [picks] is `entry_list`'s change key;
/// [tagPicks] are names to search or dot by.
typedef ListFilter<T> = ({
  List<Widget> chips,
  bool Function(T entry) test,
  String? narrowing,
  List<String> picks,
  List<String> tagPicks,
});

/// Draws a row on show (FR-DIS-5); [icon] is a Widget for off-square glyphs (ADR 14).
typedef RandomDraw<T> = ({
  Widget icon,
  String tooltip,
  String? Function(List<T> onShow) draw,
});
