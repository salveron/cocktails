import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';
import 'recipe_form_screen.dart';

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

  void _toggle(String name) => setState(() {
    _expanded.toggle(name);
    if (!_expanded.contains(name)) _undo.remove(name);
  });

  @override
  Widget build(BuildContext context) => ModelView((model) {
    final vocabulary = sortedByName(model.recipeTags);
    return VocabularyList<Recipe>(
      entries: model.recipes,
      nameOf: (recipe) => recipe.name,
      rowOf: (recipe) => _row(model, vocabulary, recipe),
      onAdd: (query) async => await _openForm(initialName: query) != null,
      noun: 'recipe',
      plural: 'recipes',
      empty: const EmptyState(
        icon: Icons.local_bar_outlined,
        title: 'No recipes yet',
        message:
            'Recipes you add appear here, marked with what you can make '
            'from the bottles you have.',
      ),
    );
  });

  /// Compact or full when tapped; full hides summary since details appear below.
  VocabularyRow _row(Model model, List<Tag> vocabulary, Recipe recipe) {
    final expanded = _expanded.contains(recipe.name);
    final summary = [
      for (final line in recipe.lines) line.ingredient,
    ].join(' · ');
    return VocabularyRow(
      title: expanded
          ? Text(recipe.name)
          : DottedName(recipe.name, vocabulary: vocabulary, worn: recipe.tags),
      subtitle: expanded || summary.isEmpty
          ? null
          : Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      body: expanded
          ? _Details(
              vocabulary: vocabulary,
              recipe: recipe,
              onMade: () => unawaited(_made(recipe)),
              onReset: () => unawaited(_reset(recipe)),
              onUndo: _undo.containsKey(recipe.name)
                  ? () => unawaited(_undoMade(recipe))
                  : null,
            )
          : null,
      trailing: RowMenu({
        'Edit': () => unawaited(_edit(recipe)),
        'Delete': () => unawaited(_delete(recipe)),
      }),
      onTap: () => _toggle(recipe.name),
    );
  }

  /// Opens form and returns saved name (null if cancelled or unchanged).
  Future<String?> _openForm({Recipe? original, String initialName = ''}) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) =>
              RecipeFormScreen(original: original, initialName: initialName),
        ),
      );

  /// On rename, move expansion state from old name to new name.
  Future<void> _edit(Recipe recipe) async {
    final saved = await _openForm(original: recipe);
    if (saved == null || saved == recipe.name || !mounted) return;
    setState(() {
      if (_expanded.remove(recipe.name)) _expanded.add(saved);
      _undo.remove(recipe.name);
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
        _undo.remove(recipe.name);
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
      title: 'Reset "${recipe.name}"\' history?',
      message: 'It will appear as never made. Nothing else about it changes.',
      cancel: 'Cancel',
      confirm: 'Reset',
    );
    if (!confirmed || !mounted) return;
    setState(() => _undo.remove(recipe.name));
    await ref.read(modelProvider.notifier).setMade(recipe.name, null);
  }
}

/// Full recipe card: tags, lines, notes, made row; empty sections omitted.
class _Details extends StatelessWidget {
  const _Details({
    required this.vocabulary,
    required this.recipe,
    required this.onMade,
    required this.onReset,
    this.onUndo,
  });

  final List<Tag> vocabulary;
  final Recipe recipe;
  final VoidCallback onMade;
  final VoidCallback onReset;

  /// Null until a stamp leaves something to take back.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final worn = wornInOrder(vocabulary, recipe.tags);
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
            child: Text(formatRecipeLine(line)),
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
