/// The tags to pick from, to tag with or to narrow a list by
/// (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../lists/list_terms.dart';
import 'color_marks.dart';

/// Tag chips with [chosen] ticked, each toggling its tag.
List<Widget> tagChips(
  List<Tag> tags,
  Set<String> chosen,
  void Function(String name) onToggle,
) => [
  for (final tag in tags)
    InkWell(
      onTap: () => onToggle(tag.name),
      borderRadius: chipRadius,
      child: TagChip(tag, chosen: chosen.contains(tag.name)),
    ),
];

/// Tag chips wrapped, for tagging an ingredient or a recipe.
class TagChoices extends StatelessWidget {
  const TagChoices({
    required this.tags,
    required this.chosen,
    required this.onToggle,
    super.key,
  });

  final List<Tag> tags;
  final Set<String> chosen;
  final void Function(String name) onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: tagChips(tags, chosen, onToggle),
  );
}

/// The tag chips a list narrows by, ingredients and recipes alike (FR-ING-3,
/// FR-DIS-3): they double as the dots' legend, an entry kept only wearing
/// every one picked. [picked] reads against [tags] through `wornInOrder`
/// rather than trusted, so a tag deleted or renamed elsewhere stops narrowing
/// while a case-only rename goes on (ADR 08) — the shopping card marks its
/// recipes by the same rule. The test folds both sides since [chosen] carries
/// the vocabulary's spelling and [tagsOf] the entry's own, so a file
/// hand-recased after export still keeps its chip. [leading] is a narrowing
/// the screen builds itself — the recipes' base spirit (ADR 12) — its chip
/// standing before the tags and sharing the one message.
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
    chips: [...?leading?.chips, ...tagChips(tags, chosen, onToggle)],
    test: (entry) =>
        (leading?.test(entry) ?? true) &&
        (wanted.isEmpty || nameKeys(tagsOf(entry)).containsAll(wanted)),
    narrowing: reasons.isEmpty ? null : reasons.join(' and '),
    picks: [...?leading?.picks, ...chosen],
    tagPicks: [...?leading?.tagPicks, ...chosen],
  );
}
