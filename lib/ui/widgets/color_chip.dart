/// Colored widgets: chip (label + fill), tag and signal chips, dot, dotted
/// name. Every one carries words or a tooltip — no meaning from hue alone.
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

/// The stock level in words — one home, so chip and dot cannot drift.
String stockLabel(StockLevel stock) => switch (stock) {
  StockLevel.in_ => 'In stock',
  StockLevel.low => 'Low',
  StockLevel.out => 'Out',
};

/// What is left of a bottle, on its inventory row.
class StockChip extends StatelessWidget {
  const StockChip(this.stock, {super.key});

  final StockLevel stock;

  @override
  Widget build(BuildContext context) => ColorChip(
    stockLabel(stock),
    swatch: stockColors(stock, Theme.of(context).brightness),
  );
}

/// What the bottles make of a recipe, on its list row (FR-DIS-1).
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip(this.availability, {super.key});

  final Availability availability;

  @override
  Widget build(BuildContext context) => ColorChip(switch (availability) {
    Availability.makeable => 'Ready',
    Availability.makeableLow => 'Low',
    Availability.missing => 'Missing',
  }, swatch: availabilityColors(availability, Theme.of(context).brightness));
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
  Widget build(BuildContext context) => _Dot(
    tagColors(tag.color, Theme.of(context).brightness).fill,
    tooltip: tag.name,
  );
}

/// A bottle beside a recipe line, where the chip's words would not fit; drawn
/// only where there is something to report, so no dot reads as in stock.
class StockDot extends StatelessWidget {
  const StockDot(this.stock, {super.key});

  final StockLevel stock;

  @override
  Widget build(BuildContext context) => _Dot(
    stockColors(stock, Theme.of(context).brightness).fill,
    tooltip: stockLabel(stock),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {required this.tooltip});

  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}
