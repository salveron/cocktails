/// The one row of tags to pick from (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../lists/list_terms.dart';
import 'color_marks.dart';

/// Tag chips with [chosen] ticked (same row for ingredient tagging & filtering).
class TagChoices extends StatelessWidget {
  const TagChoices({
    required this.tags,
    required this.chosen,
    required this.onToggle,
    this.scrolling = false,
    this.leading,
    super.key,
  });

  final List<Tag> tags;
  final Set<String> chosen;
  final void Function(String name) onToggle;

  /// If true, scroll horizontally; if false, wrap (single line when pinned).
  final bool scrolling;

  /// A chip of the screen's own, standing before the tags in the same row so
  /// one scroller carries both narrowings (ADR 12).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // Unbounded width prevents wrapping; works both inside/outside scroller.
    final row = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ?leading,
        for (final tag in tags)
          InkWell(
            onTap: () => onToggle(tag.name),
            borderRadius: chipRadius,
            child: TagChip(tag, chosen: chosen.contains(tag.name)),
          ),
      ],
    );
    return scrolling
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
        : row;
  }
}

/// The tag row a list narrows by, ingredients and recipes alike (FR-ING-3,
/// FR-DIS-3): chips double as the dots' legend, an entry kept only wearing
/// every one picked. [picked] reads against [tags] through `wornInOrder`
/// rather than trusted, so a tag deleted or renamed elsewhere stops narrowing
/// while a case-only rename goes on (ADR 08) — the shopping card marks its
/// recipes by the same rule. The test folds both sides since [chosen] carries
/// the vocabulary's spelling and [tagsOf] the entry's own, so a file
/// hand-recased after export still keeps its chip. [leading] is a narrowing
/// the screen builds itself — the recipes' base spirit (ADR 12) — sharing the
/// one row and the one message.
ListFilter<T>? tagFilter<T>({
  required List<Tag> tags,
  required Set<String> picked,
  required void Function(String tag) onToggle,
  required List<String> Function(T entry) tagsOf,
  ListFilter<T>? leading,
}) {
  if (tags.isEmpty && leading == null) return null;
  final chosen = {for (final tag in wornInOrder(tags, picked)) tag.name};
  final wanted = nameKeys(chosen);
  final reasons = [
    ?leading?.narrowing,
    if (chosen.isNotEmpty) 'every tag picked',
  ];
  return (
    row: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TagChoices(
        tags: tags,
        chosen: chosen,
        onToggle: onToggle,
        scrolling: true,
        leading: leading?.row,
      ),
    ),
    test: (entry) =>
        (leading?.test(entry) ?? true) &&
        (wanted.isEmpty || nameKeys(tagsOf(entry)).containsAll(wanted)),
    narrowing: reasons.isEmpty ? null : reasons.join(' and '),
    picks: [...?leading?.picks, ...chosen],
    tagPicks: [...?leading?.tagPicks, ...chosen],
  );
}
