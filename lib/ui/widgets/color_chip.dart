/// The pill a fixed hue is drawn as, and a tag's own form of it
/// (docs/ui-design.md#tag-and-stock-colours).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// A word on its own ground — the colour never carries the meaning alone, so
/// the row does not ask the reader to decode a hue.
class ColorChip extends StatelessWidget {
  const ColorChip(this.label, {required this.swatch, super.key});

  final String label;
  final Swatch swatch;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: swatch.fill,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: swatch.ink),
      ),
    ),
  );
}

/// A tag wherever it appears in full: its name lettered on its own colour.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {super.key});

  final Tag tag;

  @override
  Widget build(BuildContext context) => ColorChip(
    tag.name,
    swatch: tagColors(tag.color, Theme.of(context).brightness),
  );
}
