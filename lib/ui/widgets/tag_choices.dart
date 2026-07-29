/// The one row of tags to pick from (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import 'color_chip.dart';

/// [vocabulary] as chips, the [chosen] ones ticked. Tagging an ingredient and
/// filtering the inventory by tags are the same choice made twice, so they are
/// made on the same row.
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

  /// Whether the row scrolls sideways instead of wrapping: pinned over a list
  /// it must stay one line deep however long the vocabulary grows.
  final bool scrolling;

  @override
  Widget build(BuildContext context) {
    // Unbounded width leaves a wrap nothing to wrap at, so one row serves
    // both: a single line inside the scroller, as many as it needs outside.
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
