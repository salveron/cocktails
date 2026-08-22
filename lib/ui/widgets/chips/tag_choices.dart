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

/// The tag row a list narrows by — the ingredients and the recipes alike
/// (FR-ING-3, FR-DIS-3): chips that double as the legend for the dots on the
/// rows, and an entry kept only where it wears every one picked. A vocabulary
/// with nothing in it has no row and narrows nothing.
///
/// [picked] is read against [tags] through `wornInOrder` rather than
/// trusted, so a tag deleted or renamed elsewhere stops narrowing rather than
/// emptying the list, while one renamed only in its case goes on narrowing (ADR
/// 08). That is the one home for reading picks against a vocabulary — the
/// shopping card marks its recipes with the picks they answer off the same
/// rule, so nothing is ever dotted by a pick that has stopped narrowing.
///
/// The test folds both sides, because they come from different places: [chosen]
/// carries the vocabulary's spelling, [tagsOf] the entry's own. A file the app
/// exported and a hand then recased — which `validateCollection` accepts, tag
/// references being resolved by the fold — would otherwise drop that entry off
/// its own chip.
///
/// [leading] is a narrowing the screen builds itself — the recipes' base spirit
/// (ADR 12). Its row stands first among the chips, in the one scroller, and its
/// reason joins the tags' in the one message; a vocabulary with nothing in it
/// still draws it.
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
  );
}
