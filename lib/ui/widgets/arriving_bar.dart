/// A bar arriving by file: the pick, what it turned out to hold, and why it
/// could not be read — one file read the same way wherever it was picked, on
/// the one form that agrees to it (FR-DAT-4, FR-BAR-7). The readings are
/// columns, so the screen showing one owns the scrolling.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vocabulary_list.dart';

/// A file off the system's picker, decoded and judged before anything is done
/// with it (FR-DAT-3/4). Null where nothing came back to judge: picking nothing
/// is nothing done, and a picker that would not open says so where it stands
/// rather than leaving the screen silent.
Future<ImportReview?> pickBar(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picker = ref.read(filePickerProvider);
  final shelf = ref.read(shelfProvider.notifier);
  try {
    final text = await picker();
    return text == null ? null : shelf.review(text);
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not read that file: $error')),
    );
    return null;
  }
}

/// Why the file was not read, and where (FR-DAT-4), under the one sentence that
/// matters — [standing], what is true despite it, which differs by what the
/// file was about to be used for. There is nothing here to agree to.
class RefusedFile extends StatelessWidget {
  const RefusedFile(this.issues, {required this.standing, super.key});

  final List<String> issues;
  final String standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This file cannot be read',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          standing,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        BulletRuns([bulletRun(issues)]),
      ],
    );
  }
}

/// The pull a guest bar's lists answer (FR-BAR-5): its source asked again,
/// whatever way it came — a newer file, for the file transport. Null on an
/// owned bar, which has no source. `RefreshFailure` meets what it comes to.
Future<void> Function()? refreshOf(WidgetRef ref) {
  final open = ref.watch(openBarProvider);
  if (open == null || open.isOwned) return null;
  return () => ref.read(shelfProvider.notifier).refresh(open.id);
}

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
      for (final holding in _holdingsOf(widget.arriving)) _card(holding),
    ],
  );

  /// Count as the title, the names as the line under it, the whole list when
  /// opened. A kind holding none offers no chevron and answers no tap.
  Widget _card(_Holding holding) {
    final open = _open.contains(holding.kind);
    final empty = holding.count == 0;
    return VocabularyRow(
      title: Text(counted(holding.count, holding.kind.noun)),
      subtitle: open || empty
          ? null
          : Text(holding.line, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: empty
          ? null
          : Icon(open ? Icons.expand_less : Icons.expand_more),
      body: open ? BulletRuns(holding.runs) : null,
      onTap: empty ? null : () => setState(() => _open.toggle(holding.kind)),
    );
  }
}

/// One kind the file carries, and the names behind it.
final class _Holding {
  const _Holding(this.kind, this.runs);

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
/// the same four a bar card counts. Each kind is named and ordered within itself
/// as the screen managing it does, so a card here reads as the list it stands
/// for (`inventory_screen.dart`, `tags_screen.dart`, `units_screen.dart`).
List<_Holding> _holdingsOf(Collection collection) => [
  for (final kind in Holding.values)
    _Holding(kind, switch (kind) {
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
    bulletRun(sorted ? ([...names]..sort(byName)) : names, label: label);
