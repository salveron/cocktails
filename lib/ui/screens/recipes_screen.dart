import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_list.dart';

/// Every recipe as a card that expands in place — the compact two lines, or
/// the full view: tags, lines, notes, made-history (FR-DIS-2). Read-only until
/// the form lands (M14). Designed in docs/ui-design.md#recipes-screen.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  /// Held here rather than in the cards: the list disposes what scrolls away.
  final _expanded = <String>{};

  void _toggle(String name) => setState(() {
    if (!_expanded.remove(name)) _expanded.add(name);
  });

  @override
  Widget build(BuildContext context) => ModelView((model) {
    final vocabulary = [...model.recipeTags]
      ..sort((a, b) => byName(a.name, b.name));
    return VocabularyList<Recipe>(
      entries: model.recipes,
      nameOf: (recipe) => recipe.name,
      rowOf: (recipe) => _row(vocabulary, recipe),
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

  /// Compact, or full when tapped open: the full card replaces the dots and
  /// the ingredient summary with the real thing, so neither line repeats what
  /// sits right below it.
  VocabularyRow _row(List<Tag> vocabulary, Recipe recipe) {
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
      body: expanded ? _Details(vocabulary: vocabulary, recipe: recipe) : null,
      onTap: () => _toggle(recipe.name),
    );
  }
}

/// The full card, top to bottom: the tags as their chips, the lines exactly as
/// the file writes them, the notes as typed, the made-history. A section with
/// nothing to say is absent.
class _Details extends StatelessWidget {
  const _Details({required this.vocabulary, required this.recipe});

  final List<Tag> vocabulary;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final made = recipe.made;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recipe.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in vocabulary)
                if (recipe.tags.contains(tag.name)) TagChip(tag),
            ],
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
        if (made != null) ...[
          const SizedBox(height: 12),
          Text(
            _madeLine(made),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
