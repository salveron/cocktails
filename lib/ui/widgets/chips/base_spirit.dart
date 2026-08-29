/// The base spirit chip and the narrowing it keeps (FR-DIS-4, ADR 12).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../../palette.dart';
import '../lists/list_terms.dart';
import 'color_marks.dart';

/// What the list is narrowed to by base spirit (FR-DIS-4, ADR 12) — a record,
/// so a null *spirit*, the recipes marking no base, is told apart from a null
/// _pick_, which is no narrowing at all.
typedef BasePick = ({String? spirit});

/// What the list is narrowed to, and the menu settling it: any base, no base,
/// or one of the spirits the collection is built on (FR-DIS-4, ADR 12). Shaped
/// like the tag chips it stands among, but neutral — an ingredient's name is
/// neither a tag nor a signal, and the chip names its own dimension so it
/// cannot be read as a tag that happens to be called "Base". The menu carries
/// its pick wrapped, since a bare null selection is how [PopupMenuButton]
/// reports a menu dismissed — and "Any base" is a null pick.
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
      // Ringed like a picked tag while it narrows, and ringed in the clear
      // besides, so the chip stands in line with the tags either way.
      child: ColorChip(
        'Base: ${chosen == null ? 'Any' : chosen.spirit ?? 'None'}',
        swatch: neutralSwatch(Theme.of(context).colorScheme),
        chosen: chosen != null,
        opensMenu: true,
      ),
    );
  }

  /// One offering, the one in force wearing the tick.
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

/// The base spirit chip and what it keeps (FR-DIS-4, ADR 12). A pick gone
/// stale — renamed, deleted, or its last base mark cleared — is absent from
/// what the collection offers, so it stops narrowing rather than emptying
/// the list.
ListFilter<Recipe>? baseFilter(
  Collection collection, {
  required BasePick? base,
  required void Function(BasePick? pick) onPick,
}) {
  final spirits = baseSpirits(collection);
  if (spirits.isEmpty) return null;
  final chosen = _standingPick(collection, spirits, base);
  // Spelled out once, read as both what narrows and what the reader is told.
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
    // Not a tag: a base spirit has no place among names a caller would
    // search or dot recipes by.
    tagPicks: const [],
  );
}

/// [pick] as the collection spells it now, or null where it no longer stands
/// among [spirits] — a rename recased still narrows (ADR 08); one renamed in
/// earnest stops.
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
