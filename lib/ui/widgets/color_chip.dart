/// Colored widgets: chip (label + fill), tag chip, dot, dotted name.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Label on colored ground (no meaning from color alone).
class ColorChip extends StatelessWidget {
  const ColorChip(this.label, {required this.swatch, this.chosen, super.key});

  final String label;
  final Swatch swatch;

  /// If true/false, show ring; if null, no ring (not a choice).
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
        // Transparent border keeps layout stable on state change.
        border: Border.all(color: chosen ? swatch.ink : Colors.transparent),
      ),
      child: chip,
    );
  }
}

/// Tag with its own color (full version of TagDot).
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

/// Name with tag dots (name clips first to avoid misreporting count).
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

/// Tag as dot (matches chip in legend above); name in tooltip.
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
