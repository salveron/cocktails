import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../palette.dart';
import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/tag_choices.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';

/// Every ingredient and what is left of it — searchable by name and by tag, one
/// tap per stock change (FR-INV-1/2/3) — and the vocabulary itself: add, edit,
/// delete (FR-VOC-1). Designed in docs/ui-design.md#inventory-screen.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _picked = <String>{};

  void _toggle(String tag) => setState(() => _picked.toggle(tag));

  @override
  Widget build(BuildContext context) => ModelView((model) {
    final vocabulary = sortedByName(model.ingredientTags);
    // Ignore deleted/renamed tags; keep intersection with current vocabulary.
    final picked = _picked.intersection(model.tagNames(TagKind.ingredient));
    return VocabularyList<Ingredient>(
      entries: model.ingredients,
      nameOf: (ingredient) => ingredient.name,
      rowOf: (ingredient) => _row(model, vocabulary, ingredient),
      onAdd: (query) => _add(model, vocabulary, query),
      noun: 'ingredient',
      plural: 'ingredients',
      filter: vocabulary.isEmpty
          ? null
          : (
              row: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TagChoices(
                  vocabulary: vocabulary,
                  chosen: picked,
                  onToggle: _toggle,
                  scrolling: true,
                ),
              ),
              test: (ingredient) => picked.every(ingredient.tags.contains),
              narrowing: picked.isEmpty ? null : 'every tag you picked',
            ),
      empty: const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No ingredients yet',
        message:
            'Every ingredient your recipes use is listed here, with what you '
            'have in stock.',
      ),
    );
  });

  /// Row tap toggles stock (in → low → out → in); vocab actions use ⋮.
  VocabularyRow _row(
    Model model,
    List<Tag> vocabulary,
    Ingredient ingredient,
  ) => VocabularyRow(
    title: DottedName(
      ingredient.name,
      vocabulary: vocabulary,
      worn: ingredient.tags,
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StockChip(ingredient.stock),
        RowMenu({
          'Edit': () => unawaited(_edit(model, vocabulary, ingredient)),
          'Delete': () => unawaited(_delete(model, ingredient)),
        }),
      ],
    ),
    onTap: () => unawaited(
      ref
          .read(modelProvider.notifier)
          .setStock(ingredient.name, ingredient.stock.next),
    ),
  );

  /// Returns true after adding; clears picked tags along with search.
  Future<bool> _add(Model model, List<Tag> vocabulary, String query) async {
    final added = await promptForIngredient(
      context,
      title: 'New ingredient',
      hintText: 'Ingredient name',
      validate: _nameRule(model),
      vocabulary: vocabulary,
      initial: query,
    );
    if (added == null || !context.mounted) return false;
    await ref
        .read(modelProvider.notifier)
        .upsertIngredient(Ingredient(added.name, tags: added.tags));
    if (mounted) setState(_picked.clear);
    return true;
  }

  /// Atomic upsert: name + tags edited together; stock stays unchanged.
  Future<void> _edit(
    Model model,
    List<Tag> vocabulary,
    Ingredient ingredient,
  ) async {
    final edited = await promptForIngredient(
      context,
      title: 'Edit "${ingredient.name}"',
      hintText: 'Ingredient name',
      validate: _nameRule(model, except: ingredient.name),
      vocabulary: vocabulary,
      chosen: ingredient.tags,
      initial: ingredient.name,
    );
    if (edited == null || !context.mounted) return;
    await ref
        .read(modelProvider.notifier)
        .upsertIngredient(
          ingredient.copyWith(name: edited.name, tags: edited.tags),
          replacing: ingredient.name,
        );
  }

  Future<void> _delete(Model model, Ingredient ingredient) async {
    final confirmed = await confirmDelete(
      context,
      what: ingredient.name,
      blockedBy: model.recipesUsingIngredient(ingredient.name),
      blockedByNoun: 'recipes',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(modelProvider.notifier).removeIngredient(ingredient.name);
  }
}

/// Name rules (excluding [except] to prevent collision on rename).
List<ValidationIssue> Function(String) _nameRule(
  Model model, {
  String? except,
}) =>
    (name) => validateIngredient(
      Ingredient(name),
      knownIngredientTags: model.tagNames(TagKind.ingredient),
      otherIngredientNames: otherNames(model.ingredientNames, except),
    );

/// Stock level as text and color (no color-only decoding required).
class _StockChip extends StatelessWidget {
  const _StockChip(this.stock);

  final StockLevel stock;

  @override
  Widget build(BuildContext context) => ColorChip(switch (stock) {
    StockLevel.in_ => 'In stock',
    StockLevel.low => 'Low',
    StockLevel.out => 'Out',
  }, swatch: stockColors(stock, Theme.of(context).brightness));
}
