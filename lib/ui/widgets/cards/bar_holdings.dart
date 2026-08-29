/// What an arriving file turned out to hold, kind by kind, read the same way
/// wherever it was picked (FR-DAT-4, FR-BAR-7).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../../toggling.dart';
import '../../wording.dart';
import 'bullet_runs.dart';
import 'entry_card.dart';

/// Everything the file carries, kind by kind, each card opening to every name
/// behind its count: a reader agreeing to a collection is owed sight of it, and
/// a list cut short is where the entry they came looking for would have been.
class BarHoldings extends StatefulWidget {
  const BarHoldings(this.arriving, {super.key});

  final Collection arriving;

  @override
  State<BarHoldings> createState() => _BarHoldingsState();
}

class _BarHoldingsState extends State<BarHoldings> {
  final _open = <Holding>{};

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final holding in _holdingsOf(widget.arriving))
        _HoldingCard(
          holding: holding,
          open: _open.contains(holding.kind),
          onToggle: () => setState(() => _open.toggle(holding.kind)),
        ),
    ],
  );
}

/// Count as the title, the names as the line under it, the whole list when
/// opened. A kind holding none offers no chevron and answers no tap.
class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.open,
    required this.onToggle,
  });

  final _HoldingGroup holding;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final empty = holding.count == 0;
    return ExpandingCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      open: open,
      title: Text(counted(holding.count, holding.kind.noun)),
      subtitle: empty ? null : holding.line,
      trailing: empty
          ? null
          : Icon(open ? Icons.expand_less : Icons.expand_more),
      body: BulletRuns(holding.runs),
      onToggle: empty ? null : onToggle,
    );
  }
}

/// One kind the file carries, and the names behind it.
final class _HoldingGroup {
  const _HoldingGroup(this.kind, this.runs);

  final Holding kind;

  /// One run but for the tags, whose single count covers two vocabularies a
  /// body has to keep apart (ADR 07).
  final List<BulletRun> runs;

  int get count => runs.fold(0, (total, run) => total + run.bullets.length);

  /// Runs end to end, as the line under the title reads them — and only as far
  /// as the ellipsis can outrun, the body being where the rest is owed. Joining
  /// two thousand names lays out a paragraph to show one line of it.
  String get line => runs
      .expand((run) => run.bullets)
      .take(_lineNames)
      .map((bullet) => bullet.name)
      .join(', ');
}

/// More names than a phone's width fits, so the ellipsis lands on the line
/// rather than on the count of what was left out of it.
const _lineNames = 24;

/// What the file amounts to, in [Holding]'s own order and under its own nouns —
/// the same four a bar card counts. Each kind is named and ordered as the
/// screen managing it does, so a card here reads as the list it stands for.
List<_HoldingGroup> _holdingsOf(Collection collection) => [
  for (final kind in Holding.values)
    _HoldingGroup(kind, switch (kind) {
      Holding.recipe => [_run(collection.recipes.map((it) => it.name))],
      Holding.ingredient => [_run(collection.ingredients.map((it) => it.name))],
      Holding.tag => [
        _run(collection.recipeTags.map((it) => it.name), label: 'Recipe'),
        _run(
          collection.ingredientTags.map((it) => it.name),
          label: 'Ingredient',
        ),
      ],
      Holding.unit => [
        _run(collection.units.map((it) => it.name), sorted: false),
      ],
    }),
];

/// A→Z on the app's one ordering (ADR 08), so a reader scanning a long card
/// finds a name where every other list in the app would put it — but for the
/// units, whose vocabulary order carries the fixed three first and which
/// `units_screen.dart` leaves standing (ADR 17).
BulletRun _run(Iterable<String> names, {String? label, bool sorted = true}) =>
    bulletRun(sorted ? ([...names]..sort(compareNames)) : names, label: label);
