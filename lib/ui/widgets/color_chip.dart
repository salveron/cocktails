/// The marks a fixed hue is drawn as — the pill, a tag's own chip and dot, and
/// the name-with-dots row (docs/ui-design.md#tag-and-stock-colours).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// A word on its own ground — the colour never carries the meaning alone, so
/// the row does not ask the reader to decode a hue.
class ColorChip extends StatelessWidget {
  const ColorChip(this.label, {required this.swatch, this.chosen, super.key});

  final String label;
  final Swatch swatch;

  /// Whether the ring shows, or null where the chip is no kind of choice.
  final bool? chosen;

  @override
  Widget build(BuildContext context) {
    final chosen = this.chosen;
    final chip = DecoratedBox(
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
    if (chosen == null) return chip;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        // Transparent rather than absent: a picked chip differs from an
        // unpicked one in colour alone, so nothing moves under the finger.
        border: Border.all(color: chosen ? swatch.ink : Colors.transparent),
      ),
      child: chip,
    );
  }
}

/// A tag wherever it appears in full: its name lettered on its own colour.
class TagChip extends StatelessWidget {
  const TagChip(this.tag, {this.chosen, super.key});

  final Tag tag;
  final bool? chosen;

  @override
  Widget build(BuildContext context) => ColorChip(
    tag.name,
    swatch: tagColors(tag.color, Theme.of(context).brightness),
    chosen: chosen,
  );
}

/// A name with the tags it wears as dots after it. The name gives way first:
/// a clipped run of dots would misreport how many tags there are.
class DottedName extends StatelessWidget {
  const DottedName(
    this.name, {
    required this.vocabulary,
    required this.worn,
    super.key,
  });

  final String name;
  final List<Tag> vocabulary;
  final List<String> worn;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
      for (final tag in wornInOrder(vocabulary, worn))
        Padding(padding: const EdgeInsets.only(left: 6), child: TagDot(tag)),
    ],
  );
}

/// A tag on a row with no width to spare: the fill its chip wears, because a
/// dot is read by matching it to a chip in the legend above — a second version
/// of the colour would be one more thing to match. The name is in the tooltip.
class TagDot extends StatelessWidget {
  const TagDot(this.tag, {super.key});

  final Tag tag;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tag.name,
    child: SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tagColors(tag.color, Theme.of(context).brightness).fill,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
