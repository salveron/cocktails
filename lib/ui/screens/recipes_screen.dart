import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../palette.dart';
import '../theme.dart';
import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';
import 'recipe_form_screen.dart';

/// A card's reading of its own amounts: the factor it multiplies them by
/// (FR-REC-7) and the unit part-based ones show in (FR-SET-1, this card only).
/// Display alone — nothing here reaches the model or the file.
typedef _AmountView = ({int scale, DisplayUnit unit});

const _asWritten = (scale: 1, unit: DisplayUnit.part);

/// What the list is narrowed to by base spirit (FR-DIS-4, ADR 12) — a record,
/// so a null *spirit*, the recipes marking no base, is told apart from a null
/// _pick_, which is no narrowing at all.
typedef _BasePick = ({String? spirit});

/// How a substitution group reads on a card — prose, where the grammar and the
/// file keep the separator (ADR 11). Italic on the open card, so a word made of
/// two letters is still seen between the bottles it stands between.
const _or = ' or ';
const _italic = TextStyle(fontStyle: FontStyle.italic);

/// What the name row adds while a card is reading its amounts otherwise.
String? _viewNote(_AmountView view) {
  final notes = [
    if (view.scale != 1) '×${view.scale}',
    if (view.unit != _asWritten.unit) view.unit.token,
  ];
  return notes.isEmpty ? null : '(${notes.join(', ')})';
}

/// Every recipe as a card that expands in place — the compact two lines, or
/// the full view: tags, lines, notes, made-history (FR-DIS-2) — and the
/// recipes themselves: add and edit through the pushed form, delete behind
/// the ⋮ (FR-REC-1). Designed in docs/ui-design.md#recipes-screen.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  /// Expansion state here, not per-card (list disposes what scrolls).
  final _expanded = <String>{};

  /// What a recipe's history read before its last stamp, offered as Undo for
  /// as long as the card that stamped it stays open. A null value is an
  /// answer — never made — so membership is the test, never the value.
  final _undo = <String, MadeHistory?>{};

  /// How an open card is reading its amounts (FR-REC-7), absent while it reads
  /// them as written. Kept beside the undo and let go with it: both are a way
  /// of looking at one card, and neither outlives it.
  final _views = <String, _AmountView>{};

  /// The tags narrowing the list (FR-DIS-3) — screen state like the order and
  /// the search, so nothing about a way of looking reaches the file.
  final _picked = <String>{};

  /// The base spirit narrowing it beside them, absent while it narrows nothing.
  _BasePick? _base;

  void _toggle(String name) => setState(() {
    _expanded.toggle(name);
    if (!_expanded.contains(name)) _forget(name);
  });

  void _forget(String name) {
    _undo.remove(name);
    _views.remove(name);
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(availabilityProvider);
    return ModelView((model) {
      final vocabulary = sortedByName(model.recipeTags);
      return VocabularyList<Recipe>(
        entries: model.recipes,
        nameOf: (recipe) => recipe.name,
        spellingsOf: (recipe) => _spellings(model, recipe),
        rowOf: (recipe) =>
            _row(model, vocabulary, recipe, availability[recipe.name]),
        onAdd: (query) => _add(model.units, query),
        noun: 'recipe',
        plural: 'recipes',
        filter: tagFilter(
          vocabulary: vocabulary,
          picked: _picked,
          onToggle: (tag) => setState(() => _picked.toggle(tag)),
          tagsOf: (recipe) => recipe.tags,
          leading: _baseFilter(model),
        ),
        orders: {
          // A recipe the pass has yet to judge ranks with the missing ones,
          // where a card drawing no chip belongs.
          'Availability': (recipe) =>
              (availability[recipe.name] ?? Availability.missing).index,
          ...alphabetical,
        },
        empty: const EmptyState(
          icon: Icons.local_bar_outlined,
          title: 'No recipes yet',
          message:
              'Recipes you add appear here, marked with what you can make '
              'from the bottles you have.',
        ),
      );
    });
  }

  /// Compact or full when tapped; full hides summary since details appear below.
  /// [availability] is derived from the model this row is built from, so it is
  /// there; an absent one draws no chip rather than standing on an assertion.
  VocabularyRow _row(
    Model model,
    List<Tag> vocabulary,
    Recipe recipe,
    Availability? availability,
  ) {
    final expanded = _expanded.contains(recipe.name);
    final view = _views[recipe.name] ?? _asWritten;
    final note = _viewNote(view);
    final summary = [
      for (final line in recipe.lines) line.ingredients.join(_or),
    ].join(' · ');
    return VocabularyRow(
      title: expanded
          ? Row(
              children: [
                Flexible(
                  child: Text(recipe.name, overflow: TextOverflow.ellipsis),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      note,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            )
          : DottedName(recipe.name, vocabulary: vocabulary, worn: recipe.tags),
      subtitle: expanded || summary.isEmpty
          ? null
          : Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      body: expanded
          ? _Details(
              model: model,
              vocabulary: vocabulary,
              recipe: recipe,
              view: view,
              onMade: () => unawaited(_made(recipe)),
              onReset: () => unawaited(_reset(recipe)),
              onUndo: _undo.containsKey(recipe.name)
                  ? () => unawaited(_undoMade(recipe))
                  : null,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (availability != null) AvailabilityChip(availability),
          RowMenu({
            // Only where there are amounts to transform: the choice is the
            // open card's, and dies with it.
            if (expanded) 'Scale & convert': () => unawaited(_scale(recipe)),
            'Edit': () => unawaited(_edit(model.units, recipe)),
            'Delete': () => unawaited(_delete(recipe)),
          }),
        ],
      ),
      onTap: () => _toggle(recipe.name),
    );
  }

  /// The base spirit chip and what it keeps (FR-DIS-4, ADR 12). A pick gone
  /// stale — the bottle renamed, deleted, or its last base mark cleared — is
  /// absent from what the collection offers, and so stops narrowing rather than
  /// emptying the list. Nothing marked anywhere leaves nothing to offer.
  ListFilter<Recipe>? _baseFilter(Model model) {
    final spirits = baseSpirits(model);
    if (spirits.isEmpty) return null;
    final chosen = _standingPick(model, spirits);
    return (
      row: _BaseChip(
        spirits: spirits,
        chosen: chosen,
        onPick: (pick) => setState(() => _base = pick),
      ),
      test: (recipe) => chosen == null || marksBase(recipe, chosen.spirit),
      narrowing: switch (chosen) {
        null => null,
        (spirit: null) => 'no base at all',
        (spirit: final spirit) => '$spirit as its base',
      },
    );
  }

  /// The pick as the collection spells it now, or null where it no longer
  /// stands among [spirits]. A bottle answers under its own name, so a rename
  /// changing only its case goes on narrowing (ADR 08) and the chip reads the
  /// new spelling; one renamed in earnest stops.
  _BasePick? _standingPick(Model model, List<String> spirits) {
    final pick = _base;
    if (pick == null) return null;
    final picked = pick.spirit;
    if (picked == null) return pick;
    final spirit = baseSpiritNamed(model, picked);
    return spirits.contains(spirit) ? (spirit: spirit) : null;
  }

  /// Opens form and returns saved name (null if cancelled or unchanged).
  Future<String?> _openForm({
    required List<Unit> units,
    Recipe? original,
    String initialName = '',
  }) => Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => RecipeFormScreen(
        units: units,
        original: original,
        initialName: initialName,
      ),
    ),
  );

  /// The form, and every narrowing let go along with the search once it saves:
  /// a recipe wearing none of the picked tags, or built on another spirit,
  /// would otherwise land out of sight.
  Future<bool> _add(List<Unit> units, String query) async {
    final saved = await _openForm(units: units, initialName: query);
    if (saved != null && mounted) {
      setState(() {
        _picked.clear();
        _base = null;
      });
    }
    return saved != null;
  }

  /// What a search reaches a recipe by: its name, and every spelling of every
  /// bottle it is built from (FR-DIS-2, FR-VOC-6). A line is held under its
  /// bottle's own name (ADR 10), so the vocabulary is what widens it to the
  /// rest — and a line naming no bottle still answers to what it says.
  static List<String> _spellings(Model model, Recipe recipe) => [
    recipe.name,
    for (final line in recipe.lines)
      for (final ingredient in line.ingredients)
        ...(model.ingredientNamed(ingredient)?.spellings ?? [ingredient]),
  ];

  /// On rename, move expansion state from old name to new name.
  Future<void> _edit(List<Unit> units, Recipe recipe) async {
    final saved = await _openForm(units: units, original: recipe);
    if (saved == null || saved == recipe.name || !mounted) return;
    setState(() {
      if (_expanded.remove(recipe.name)) _expanded.add(saved);
      _forget(recipe.name);
    });
  }

  /// Reads the open card at another factor, in another unit, or both — for as
  /// long as it stays open (FR-REC-7). Nothing about the recipe changes, so
  /// the way back is the reading it was written in.
  Future<void> _scale(Recipe recipe) async {
    final chosen = await showDialog<_AmountView>(
      context: context,
      builder: (_) => _ScaleDialog(
        recipe: recipe.name,
        view: _views[recipe.name] ?? _asWritten,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (chosen == _asWritten) {
        _views.remove(recipe.name);
      } else {
        _views[recipe.name] = chosen;
      }
    });
  }

  /// Delete: never blocked since nothing references recipes.
  Future<void> _delete(Recipe recipe) async {
    final confirmed = await confirmDelete(
      context,
      what: recipe.name,
      blockedBy: const [],
      blockedByNoun: 'recipes',
    );
    if (!confirmed || !mounted) return;
    await ref.read(modelProvider.notifier).removeRecipe(recipe.name);
    if (mounted) {
      setState(() {
        _expanded.remove(recipe.name);
        _forget(recipe.name);
      });
    }
  }

  /// Stamps today onto the recipe, keeping what stood there so Undo can put it
  /// back — nothing else lowers a count that only climbs (FR-REC-6).
  Future<void> _made(Recipe recipe) async {
    setState(() => _undo[recipe.name] = recipe.made);
    await ref.read(modelProvider.notifier).markMade(recipe.name);
  }

  /// Puts that history back, date included: a stamp taken back leaves no trace.
  Future<void> _undoMade(Recipe recipe) async {
    final previous = _undo[recipe.name];
    setState(() => _undo.remove(recipe.name));
    await ref.read(modelProvider.notifier).setMade(recipe.name, previous);
  }

  /// The long press on the button, asked about first — a count is not rebuilt
  /// by tapping, and there is nothing left to undo with once it is gone.
  Future<void> _reset(Recipe recipe) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Reset "${recipe.name}"\'s history?',
      message: 'It will appear as never made. Nothing else about it changes.',
      cancel: 'Cancel',
      confirm: 'Reset',
    );
    if (!confirmed || !mounted) return;
    setState(() => _undo.remove(recipe.name));
    await ref.read(modelProvider.notifier).setMade(recipe.name, null);
  }
}

/// What the list is narrowed to, and the menu settling it: any base, no base,
/// or one of the spirits the collection is built on (FR-DIS-4, ADR 12). Shaped
/// like the tag chips it stands among, but neutral — a bottle's name is neither
/// a tag nor a signal, and the chip names its own dimension so it cannot be
/// read as a tag that happens to be called "Base".
///
/// The menu carries its pick wrapped, since a bare null selection is how
/// [PopupMenuButton] reports a menu dismissed — and "Any base" is a null pick.
class _BaseChip extends StatelessWidget {
  const _BaseChip({
    required this.spirits,
    required this.chosen,
    required this.onPick,
  });

  final List<String> spirits;
  final _BasePick? chosen;
  final void Function(_BasePick? pick) onPick;

  @override
  Widget build(BuildContext context) {
    final chosen = this.chosen;
    return PopupMenuButton<({_BasePick? pick})>(
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
  PopupMenuItem<({_BasePick? pick})> _item(String label, _BasePick? pick) =>
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

/// Full recipe card: tags, lines, notes, made row; empty sections omitted.
class _Details extends StatelessWidget {
  const _Details({
    required this.model,
    required this.vocabulary,
    required this.recipe,
    required this.view,
    required this.onMade,
    required this.onReset,
    this.onUndo,
  });

  /// Read for the stock behind each line (FR-DIS-1), and for the ratio one
  /// part converts at (FR-SET-1).
  final Model model;

  final List<Tag> vocabulary;
  final Recipe recipe;

  /// How this card is reading its amounts, [_asWritten] until asked otherwise.
  final _AmountView view;

  final VoidCallback onMade;
  final VoidCallback onReset;

  /// Null until a stamp leaves something to take back.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final worn = wornInOrder(vocabulary, recipe.tags);
    final settings = model.settings.copyWith(display: view.unit);
    final transformed = view != _asWritten;
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
            child: _Line(
              line,
              measure: displayMeasure(
                line,
                settings,
                model.units,
                scale: view.scale,
              ),
              model: model,
              transformed: transformed,
            ),
          ),
        if (recipe.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(recipe.notes),
        ],
        const SizedBox(height: 4),
        _MadeRow(
          made: recipe.made,
          onMade: onMade,
          onReset: onReset,
          onUndo: onUndo,
        ),
      ],
    );
  }
}

/// One line: the measure, the bottles it may be built from, the mark — then a
/// dot where the line is short (FR-DIS-1). An optional line is marked too: the
/// dot reports the bottle, and the line's own "(optional)" says it does not
/// count against the verdict. Where a group has something on hand, the
/// alternatives that are out fall to [dimmedInk], the ink an unfilled field's
/// hint wears, so the eye lands on the one to reach for; where it has nothing,
/// none dims and the dot carries it alone (ADR 11).
/// A [transformed] card italicises the measure, the only part of the line that
/// is then not what the recipe says.
class _Line extends StatelessWidget {
  const _Line(
    this.line, {
    required this.measure,
    required this.model,
    required this.transformed,
  });

  final RecipeLine line;
  final String measure;
  final Model model;
  final bool transformed;

  @override
  Widget build(BuildContext context) {
    final stock = stockOfLine(model, line);
    final dimmed = TextStyle(color: dimmedInk(Theme.of(context).colorScheme));
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: measure, style: transformed ? _italic : null),
                for (var i = 0; i < line.ingredients.length; i++) ...[
                  if (i == 0)
                    const TextSpan(text: ' ')
                  else
                    const TextSpan(text: _or, style: _italic),
                  TextSpan(
                    text: line.ingredients[i],
                    style:
                        stock != StockLevel.out &&
                            stockOf(model, line.ingredients[i]) ==
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

/// The card's last line: what the history reads, the Undo the last stamp left
/// behind, and the button that stamps (FR-REC-6). A recipe never made says
/// nothing on its left — the button stands there alone. The text gives way
/// first, since a clipped date beats a wrapped row.
class _MadeRow extends StatelessWidget {
  const _MadeRow({
    required this.made,
    required this.onMade,
    required this.onReset,
    this.onUndo,
  });

  final MadeHistory? made;
  final VoidCallback onMade;
  final VoidCallback onReset;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final made = this.made;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: made == null
              ? const SizedBox.shrink()
              : Text(
                  _madeLine(made),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        if (onUndo != null)
          TextButton(onPressed: onUndo, child: const Text('Undo')),
        FilledButton.tonalIcon(
          onPressed: onMade,
          onLongPress: made == null ? null : onReset,
          icon: const Icon(Icons.check),
          label: const Text('Made it'),
        ),
      ],
    );
  }
}

/// Both readings settled in one place, applied on Apply and dropped on Cancel
/// — the card behind stands as it was until then. ×1 in parts is the way back,
/// so the dialog needs no reset of its own.
class _ScaleDialog extends StatefulWidget {
  const _ScaleDialog({required this.recipe, required this.view});

  final String recipe;
  final _AmountView view;

  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  late _AmountView _view = widget.view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      title: const Text('Scale & convert'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        // Full width, so both controls start where the recipe's name does.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.recipe,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _section(
            'Amounts',
            SegmentedButton<int>(
              segments: [
                for (final factor in scaleFactors)
                  ButtonSegment(value: factor, label: Text('×$factor')),
              ],
              selected: {_view.scale},
              showSelectedIcon: false,
              onSelectionChanged: (picked) => setState(
                () => _view = (scale: picked.single, unit: _view.unit),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _section(
            'Show in',
            SegmentedButton<DisplayUnit>(
              segments: [
                for (final unit in DisplayUnit.values)
                  ButtonSegment(value: unit, label: Text(unit.token)),
              ],
              selected: {_view.unit},
              showSelectedIcon: false,
              onSelectionChanged: (picked) => setState(
                () => _view = (scale: _view.scale, unit: picked.single),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_view),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _section(String label, Widget control) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      control,
    ],
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _madeLine(MadeHistory made) {
  final last = made.last;
  final date = '${last.day} ${_months[last.month - 1]} ${last.year}';
  return made.times == 1
      ? 'Made once · $date'
      : 'Made ${made.times} times · last $date';
}
