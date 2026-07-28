import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/search_field.dart';
import '../widgets/vocabulary_dialogs.dart';

/// Every ingredient and what is left of it — searchable by name, one tap per
/// stock change (FR-INV-1/2) — and the vocabulary itself: add, rename, delete
/// (FR-VOC-1). Designed in docs/ui-design.md#inventory-screen.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The screen brings its own [Scaffold]: the destinations share the shell's
  /// one, which has no room for a per-screen button.
  @override
  Widget build(BuildContext context) => ModelView(
    (model) => Scaffold(
      body: model.ingredients.isEmpty
          ? const _NoIngredients()
          : _Ingredients(
              model: model,
              search: _search,
              onAdd: (name) => unawaited(_add(model, initial: name)),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_add(model)),
        tooltip: 'Add ingredient',
        child: const Icon(Icons.add),
      ),
    ),
  );

  /// Clears the search before saving, so the new entry cannot land outside the
  /// query and leave the screen looking as if nothing happened.
  Future<void> _add(Model model, {String initial = ''}) async {
    final name = await promptForName(
      context,
      title: 'New ingredient',
      hintText: 'Ingredient name',
      validate: _nameRule(model),
      initial: initial,
    );
    if (name == null || !mounted) return;
    _search.clear();
    await ref.read(modelProvider.notifier).upsertIngredient(Ingredient(name));
  }
}

/// The vocabulary's rules bound to the model, with [except] left out so a
/// rename never collides with the name being renamed.
List<ValidationIssue> Function(String) _nameRule(
  Model model, {
  String? except,
}) =>
    (name) => validateIngredient(
      Ingredient(name),
      otherIngredientNames: {
        for (final ingredient in model.ingredients)
          if (ingredient.name != except) ingredient.name,
      },
    );

class _Ingredients extends StatelessWidget {
  const _Ingredients({
    required this.model,
    required this.search,
    required this.onAdd,
  });

  final Model model;
  final TextEditingController search;
  final void Function(String name) onAdd;

  @override
  Widget build(BuildContext context) {
    final matches =
        model.ingredients
            .where((ingredient) => matchesQuery(ingredient.name, search.text))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return Column(
      children: [
        SearchField(controller: search, hintText: 'Search ingredients'),
        Expanded(
          child: matches.isEmpty
              ? _NoMatch(search.text.trim(), onAdd: onAdd)
              : ListView.builder(
                  // Room for the last row to clear the button above it.
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _Row(matches[index], model),
                ),
        ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.ingredient, this.model);

  final Ingredient ingredient;
  final Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: ValueKey(ingredient.name),
    title: Text(ingredient.name),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [_StockChip(ingredient.stock), _RowMenu(ingredient, model)],
    ),
    onTap: () => unawaited(
      ref
          .read(modelProvider.notifier)
          .setStock(ingredient.name, ingredient.stock.next),
    ),
  );
}

enum _RowAction { rename, delete }

/// Rename and delete live here because the row's tap belongs to stock.
class _RowMenu extends ConsumerWidget {
  const _RowMenu(this.ingredient, this.model);

  final Ingredient ingredient;
  final Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PopupMenuButton<_RowAction>(
        tooltip: 'More',
        onSelected: (action) => unawaited(switch (action) {
          _RowAction.rename => _rename(context, ref),
          _RowAction.delete => _delete(context, ref),
        }),
        itemBuilder: (context) => const [
          PopupMenuItem(value: _RowAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _RowAction.delete, child: Text('Delete')),
        ],
      );

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDelete(
      context,
      what: ingredient.name,
      blockedBy: model.recipesUsingIngredient(ingredient.name),
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(modelProvider.notifier).removeIngredient(ingredient.name);
  }
}

/// The stock level in words as well as colour, so the row does not ask the
/// reader to decode a hue.
class _StockChip extends StatelessWidget {
  const _StockChip(this.stock);

  final StockLevel stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, foreground, background) = switch (stock) {
      StockLevel.in_ => (
        'In stock',
        theme.colorScheme.onPrimaryContainer,
        theme.colorScheme.primaryContainer,
      ),
      StockLevel.low => (
        'Low',
        theme.colorScheme.onTertiaryContainer,
        theme.colorScheme.tertiaryContainer,
      ),
      StockLevel.out => (
        'Out',
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHighest,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _NoIngredients extends StatelessWidget {
  const _NoIngredients();

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.inventory_2_outlined,
    title: 'No ingredients yet',
    message:
        'Every ingredient your recipes use is listed here, with what you '
        'have in stock.',
  );
}

class _NoMatch extends StatelessWidget {
  const _NoMatch(this.query, {required this.onAdd});

  final String query;
  final void Function(String name) onAdd;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off_outlined,
    title: 'Nothing matches',
    message: 'No ingredient here is called "$query".',
    action: FilledButton.tonalIcon(
      onPressed: () => onAdd(query),
      icon: const Icon(Icons.add),
      label: Text('Add "$query"'),
    ),
  );
}
