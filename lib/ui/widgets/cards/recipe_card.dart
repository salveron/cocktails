/// A recipe as a card: shut, open, and the reading it is under
/// (docs/ui-design.md#recipes-screen).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../wording.dart';
import '../chips/color_marks.dart';
import '../dialogs/scale_dialog.dart';
import 'entry_card.dart';

String? _viewNote(AmountView view, AmountView resting) {
  final notes = [
    if (view.scale != resting.scale) '×${view.scale}',
    if (view.unit != resting.unit) view.unit.token,
  ];
  return notes.isEmpty ? null : '(${notes.join(', ')})';
}

/// What a search reaches a recipe by: its name, and every spelling of every
/// ingredient it is built from (FR-DIS-2, FR-VOC-6). A line is held under its
/// ingredient's own name (ADR 10), so the vocabulary is what widens it to the
/// rest — and a line naming no ingredient still answers to what it says.
List<String> recipeSpellings(Collection collection, Recipe recipe) => [
  recipe.name,
  for (final line in recipe.lines)
    for (final ingredient in line.ingredients)
      ...(collection.ingredientNamed(ingredient)?.spellings ?? [ingredient]),
];

/// [availability] arrives from the screen's own watch, so this never draws a
/// chip off an answer fresher than the one used to judge the row. [actions]
/// is the caller's own — built from a writer where it has one, "Scale &
/// convert" surviving a guest bar besides, scaling being a way of reading the
/// owner's line rather than a change to it (FR-BAR-4).
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    required this.collection,
    required this.tags,
    required this.recipe,
    required this.availability,
    required this.resting,
    required this.view,
    required this.expanded,
    required this.onToggle,
    required this.onReach,
    required this.actions,
    super.key,
  });

  final Collection collection;
  final List<Tag> tags;
  final Recipe recipe;
  final Availability? availability;
  final AmountView resting;
  final AmountView view;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String ingredient) onReach;
  final Map<String, VoidCallback> actions;

  @override
  Widget build(BuildContext context) {
    final availability = this.availability;
    final summary = [
      for (final line in recipe.lines) line.ingredients.join(_orSeparator),
    ].join(beside);
    return ExpandingCard(
      open: expanded,
      title: _recipeCardTitle(
        recipe,
        tags,
        expanded: expanded,
        note: _viewNote(view, resting),
      ),
      subtitle: summary.isEmpty ? null : summary,
      body: _RecipeDetails(
        collection: collection,
        tags: tags,
        recipe: recipe,
        view: view,
        resting: resting,
        onReach: onReach,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (availability != null) AvailabilityChip(availability),
          RowMenu(actions),
        ],
      ),
      onToggle: onToggle,
    );
  }
}

/// The name, dotted by its tags while compact; expanded, plain with the note
/// on how it is being read.
Widget _recipeCardTitle(
  Recipe recipe,
  List<Tag> tags, {
  required bool expanded,
  required String? note,
}) {
  if (!expanded) return DottedName(recipe.name, tags: tags, worn: recipe.tags);
  return Row(
    children: [
      Flexible(child: Text(recipe.name, overflow: TextOverflow.ellipsis)),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: MutedText(note),
        ),
    ],
  );
}

/// How a substitution group reads on a card — prose, where the grammar and the
/// file keep the separator (ADR 11).
const _orSeparator = ' or ';

/// Full recipe card: tags, lines, notes; empty sections omitted.
class _RecipeDetails extends StatelessWidget {
  const _RecipeDetails({
    required this.collection,
    required this.tags,
    required this.recipe,
    required this.view,
    required this.resting,
    required this.onReach,
  });

  /// Read for the stock behind each line (FR-DIS-1), and for the ratios the
  /// fixed units convert at (FR-SET-1).
  final Collection collection;

  final List<Tag> tags;
  final Recipe recipe;

  /// How this card is reading its amounts, [resting] until asked otherwise.
  final AmountView view;

  /// Where the card would rest, so a body knows whether it has been asked to
  /// read otherwise; the bar's pick is the notifier's to watch, not a card's.
  final AmountView resting;

  /// Where an ingredient named on a line is kept (FR-DIS-9).
  final void Function(String ingredient) onReach;

  @override
  Widget build(BuildContext context) {
    final worn = wornInOrder(tags, recipe.tags);
    final transformed = view != resting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (worn.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final tag in worn) TagChip(tag)],
          ),
          const SizedBox(height: 12),
        ],
        for (final line in recipe.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RecipeLineRow(
              line,
              measure: scaledAmountText(
                line,
                collection.unitSizes,
                view.unit,
                collection.units,
                scale: view.scale,
              ),
              collection: collection,
              transformed: transformed,
              onReach: onReach,
            ),
          ),
        if (recipe.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(recipe.notes),
        ],
      ],
    );
  }
}

const _italic = TextStyle(fontStyle: FontStyle.italic);

/// One line: the measure, the ingredients it may be built from, the mark — then
/// a dot where the line is short (FR-DIS-1). An optional line is marked too:
/// the dot reports the ingredient, and the line's own "(optional)" says it does
/// not count against the verdict. Where a group has something on hand, the
/// alternatives that are out fall to [dimmedInk], the ink an unfilled field's
/// hint wears, so the eye lands on the one to reach for; where it has nothing,
/// none dims and the dot carries it alone (ADR 11). A [transformed] card
/// italicises the measure, the only part of the line that is then not what the
/// recipe says.
///
/// Each ingredient it names reaches its row on the Ingredients screen
/// (FR-DIS-9, ADR 19) — the name alone, so a group offers one target per
/// alternative where a whole line could only ever offer the first. The measure,
/// the "or" and the mark stay inert, naming nothing that is kept anywhere.
class _RecipeLineRow extends StatefulWidget {
  const _RecipeLineRow(
    this.line, {
    required this.measure,
    required this.collection,
    required this.transformed,
    required this.onReach,
  });

  final RecipeLine line;
  final String measure;
  final Collection collection;
  final bool transformed;
  final void Function(String ingredient) onReach;

  @override
  State<_RecipeLineRow> createState() => _RecipeLineRowState();
}

class _RecipeLineRowState extends State<_RecipeLineRow> {
  /// One per ingredient the line names. A recognizer outlives the build that
  /// spans it and has to be let go by hand, so they are kept here rather than
  /// made afresh each time; a line naming fewer than it did leaves a spare,
  /// which costs nothing and goes with the card.
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final tap in _taps) {
      tap.dispose();
    }
    super.dispose();
  }

  /// The recognizer for the ingredient at [index], aimed afresh: the line it
  /// spans may have been re-edited under it.
  TapGestureRecognizer _tap(int index, String ingredient) {
    while (_taps.length <= index) {
      _taps.add(TapGestureRecognizer());
    }
    return _taps[index]..onTap = () => widget.onReach(ingredient);
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final collection = widget.collection;
    final stock = stockOfLine(collection, line);
    final dimmed = TextStyle(color: dimmedInk(Theme.of(context).colorScheme));
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: widget.measure,
                  style: widget.transformed ? _italic : null,
                ),
                for (var i = 0; i < line.ingredients.length; i++) ...[
                  if (i == 0)
                    const TextSpan(text: ' ')
                  else
                    const TextSpan(text: _orSeparator, style: _italic),
                  TextSpan(
                    text: line.ingredients[i],
                    recognizer: _tap(i, line.ingredients[i]),
                    style:
                        stock != StockLevel.out &&
                            stockOf(collection, line.ingredients[i]) ==
                                StockLevel.out
                        ? dimmed
                        : null,
                  ),
                ],
                TextSpan(text: lineMarkSuffix(line.mark)),
              ],
            ),
          ),
        ),
        if (stock != StockLevel.in_)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: StockDot(stock),
          ),
      ],
    );
  }
}
