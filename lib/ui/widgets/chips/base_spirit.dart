/// The base spirit chip and the narrowing it keeps (FR-DIS-4, ADR 12).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../../palette.dart';
import '../lists/list_terms.dart';
import 'color_marks.dart';

/// A base narrowing (FR-DIS-4, ADR 12): a record, so a null spirit (no base)
/// differs from a null pick (no narrowing at all).
typedef BasePick = ({String? spirit});

/// The menu's pick is wrapped: a bare null is how [PopupMenuButton] reports a
/// dismissal, and "Any base" is a null pick (FR-DIS-4, ADR 12).
/// Neutral, not a tag: "Base:" names its dimension so it cannot pass for one.
class BaseSpiritChip extends StatelessWidget {
  const BaseSpiritChip({
    required this.spirits,
    required this.chosen,
    required this.onPick,
    super.key,
  });

  final List<String> spirits;
  final BasePick? chosen;
  final void Function(BasePick? pick) onPick;

  @override
  Widget build(BuildContext context) {
    final chosen = this.chosen;
    return PopupMenuButton<({BasePick? pick})>(
      tooltip: 'Base spirit',
      borderRadius: chipRadius,
      onSelected: (choice) => onPick(choice.pick),
      itemBuilder: (context) => [
        _item('Any base', null),
        _item('No base', (spirit: null)),
        for (final spirit in spirits) _item(spirit, (spirit: spirit)),
      ],
      // Ringed whether or not it narrows, so it lines up with the tags.
      child: ColorChip(
        'Base: ${chosen == null ? 'Any' : chosen.spirit ?? 'None'}',
        swatch: neutralSwatch(Theme.of(context).colorScheme),
        chosen: chosen != null,
        opensMenu: true,
      ),
    );
  }

  PopupMenuItem<({BasePick? pick})> _item(String label, BasePick? pick) =>
      PopupMenuItem(
        value: (pick: pick),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: pick == chosen ? const Icon(Icons.check, size: 18) : null,
            ),
            Text(label),
          ],
        ),
      );
}

/// A pick gone stale (renamed, deleted, or unmarked as a base) stops
/// narrowing rather than emptying the list (FR-DIS-4).
ListFilter<Recipe>? baseFilter(
  Collection collection, {
  required BasePick? base,
  required void Function(BasePick? pick) onPick,
}) {
  final spirits = baseSpirits(collection);
  if (spirits.isEmpty) return null;
  final chosen = _standingPick(collection, spirits, base);
  // Spelled out once: it both narrows and is what the reader is told.
  final narrowing = switch (chosen) {
    null => null,
    (spirit: null) => 'no base at all',
    (spirit: final spirit) => '$spirit as its base',
  };
  return (
    row: BaseSpiritChip(spirits: spirits, chosen: chosen, onPick: onPick),
    test: (recipe) => chosen == null || marksBase(recipe, chosen.spirit),
    narrowing: narrowing,
    picks: [?narrowing],
    // Not a tag: a base spirit is no name to search or dot recipes by.
    tagPicks: const [],
  );
}

/// [pick] as the collection spells it now, or null when not among [spirits].
/// A rename recased still narrows (ADR 08); one renamed in earnest stops.
BasePick? _standingPick(
  Collection collection,
  List<String> spirits,
  BasePick? pick,
) {
  if (pick == null) return null;
  final picked = pick.spirit;
  if (picked == null) return pick;
  final spirit = collection.spellingOf(picked);
  return spirits.contains(spirit) ? (spirit: spirit) : null;
}
