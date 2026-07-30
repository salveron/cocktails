/// The one row of tags to pick from (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import 'color_chip.dart';

/// Tag chips with [chosen] ticked (same row for ingredient tagging & filtering).
class TagChoices extends StatelessWidget {
  const TagChoices({
    required this.vocabulary,
    required this.chosen,
    required this.onToggle,
    this.scrolling = false,
    super.key,
  });

  final List<Tag> vocabulary;
  final Set<String> chosen;
  final void Function(String name) onToggle;

  /// If true, scroll horizontally; if false, wrap (single line when pinned).
  final bool scrolling;

  @override
  Widget build(BuildContext context) {
    // Unbounded width prevents wrapping; works both inside/outside scroller.
    final row = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in vocabulary)
          InkWell(
            onTap: () => onToggle(tag.name),
            borderRadius: BorderRadius.circular(11),
            child: TagChip(tag, chosen: chosen.contains(tag.name)),
          ),
      ],
    );
    return scrolling
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
        : row;
  }
}
