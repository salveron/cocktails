/// Colored widgets: chip (label + fill), tag and signal chips, dot, dotted
/// name. Every one carries words or a tooltip — no meaning from hue alone.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// A chip's outer corner — its ring, and the ripple of whatever makes it
/// tappable. One home, so a chip and the ink under it cannot round differently.
const chipRadius = BorderRadius.all(Radius.circular(11));

/// Label on colored ground (no meaning from color alone).
class ColorChip extends StatelessWidget {
  const ColorChip(
    this.label, {
    required this.swatch,
    this.chosen,
    this.opensMenu = false,
    super.key,
  });

  final String label;
  final Swatch swatch;

  /// If true/false, show ring; if null, no ring (not a choice).
  final bool? chosen;

  /// If true, wear the arrow saying a tap opens a menu rather than toggling.
  final bool opensMenu;

  @override
  Widget build(BuildContext context) {
    final chosen = this.chosen;
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: swatch.ink);
    final text = Text(label, style: style);
    final chip = DecoratedBox(
      decoration: BoxDecoration(
        color: swatch.fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 4, opensMenu ? 2 : 10, 4),
        child: opensMenu
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  text,
                  // Sized to the label's own line, so a chip opening a menu
                  // stands exactly as tall as one that toggles; a theme
                  // dropping either number falls back to labelMedium's own.
                  Icon(
                    Icons.arrow_drop_down,
                    size: (style?.fontSize ?? 12) * (style?.height ?? 1.33),
                    color: swatch.ink,
                  ),
                ],
              )
            : text,
      ),
    );
    if (chosen == null) return chip;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: chipRadius,
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

/// Whose bar this is, on its row in the bar list (FR-BAR-3). Words on colour
/// as every other chip is: the mode decides what the bar offers, and a reader
/// meets that difference here before the bottom bar shows it to them.
class BarModeChip extends StatelessWidget {
  const BarModeChip(this.mode, {super.key});

  final BarMode mode;

  @override
  Widget build(BuildContext context) => ColorChip(switch (mode) {
    BarMode.owner => 'Owned',
    BarMode.guest => 'Guest',
  }, swatch: barModeColors(mode, Theme.of(context).colorScheme));
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

/// Tags as a run of dots, set off from each other; setting the run off from
/// whatever it follows is the caller's. Every tags-as-dots reading is this one
/// — a list row's own tags, and the picks a basket's recipe answers.
class TagDots extends StatelessWidget {
  const TagDots(this.tags, {super.key});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [for (final tag in tags) TagDot(tag)],
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
  Widget build(BuildContext context) {
    final dots = wornInOrder(vocabulary, worn);
    return Row(
      children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
        if (dots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: TagDots(dots),
          ),
      ],
    );
  }
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
