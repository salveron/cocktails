import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../palette.dart';
import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';

/// Every ingredient and what is left of it — searchable by name, one tap per
/// stock change (FR-INV-1/2) — and the vocabulary itself: add, rename, delete
/// (FR-VOC-1). Designed in docs/ui-design.md#inventory-screen.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ModelView(
    (model) => VocabularyList<Ingredient>(
      entries: model.ingredients,
      nameOf: (ingredient) => ingredient.name,
      rowOf: (ingredient) => _row(context, ref, model, ingredient),
      onAdd: (query) => _add(context, ref, model, query),
      noun: 'ingredient',
      plural: 'ingredients',
      empty: const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No ingredients yet',
        message:
            'Every ingredient your recipes use is listed here, with what you '
            'have in stock.',
      ),
    ),
  );
}

/// The row's own tap belongs to stock — the life of a bottle is in → low → out
/// → in, so every real transition costs one tap (FR-INV-2). Rename and delete
/// take the ⋮ instead of a hidden gesture.
VocabularyRow _row(
  BuildContext context,
  WidgetRef ref,
  Model model,
  Ingredient ingredient,
) => VocabularyRow(
  title: Text(ingredient.name),
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _StockChip(ingredient.stock),
      RowMenu({
        'Rename': () => unawaited(_rename(context, ref, model, ingredient)),
        'Delete': () => unawaited(_delete(context, ref, model, ingredient)),
      }),
    ],
  ),
  onTap: () => unawaited(
    ref
        .read(modelProvider.notifier)
        .setStock(ingredient.name, ingredient.stock.next),
  ),
);

/// True once an ingredient was added, which is what clears the search.
Future<bool> _add(
  BuildContext context,
  WidgetRef ref,
  Model model,
  String query,
) async {
  final name = await promptForName(
    context,
    title: 'New ingredient',
    hintText: 'Ingredient name',
    validate: _nameRule(model),
    initial: query,
  );
  if (name == null || !context.mounted) return false;
  await ref.read(modelProvider.notifier).upsertIngredient(Ingredient(name));
  return true;
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Model model,
  Ingredient ingredient,
) async {
  final name = await promptForName(
    context,
    title: 'Rename "${ingredient.name}"',
    hintText: 'Ingredient name',
    validate: _nameRule(model, except: ingredient.name),
    initial: ingredient.name,
  );
  if (name == null || !context.mounted) return;
  await ref
      .read(modelProvider.notifier)
      .renameIngredient(ingredient.name, name);
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Model model,
  Ingredient ingredient,
) async {
  final confirmed = await confirmDelete(
    context,
    what: ingredient.name,
    blockedBy: model.recipesUsingIngredient(ingredient.name),
    blockedByNoun: 'recipes',
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(modelProvider.notifier).removeIngredient(ingredient.name);
}

/// The vocabulary's rules bound to the model, with [except] left out so a
/// rename never collides with the name being renamed.
List<ValidationIssue> Function(String) _nameRule(
  Model model, {
  String? except,
}) =>
    (name) => validateIngredient(
      Ingredient(name),
      knownIngredientTags: {for (final tag in model.ingredientTags) tag.name},
      otherIngredientNames: {
        for (final ingredient in model.ingredients)
          if (ingredient.name != except) ingredient.name,
      },
    );

/// The stock level in words as well as colour, so the row never asks the reader
/// to decode a hue.
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
