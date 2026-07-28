import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/search_field.dart';

/// Every ingredient and what is left of it, searchable by name, one tap per
/// stock change (FR-INV-1/2, docs/ui-design.md#inventory-screen).
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

  @override
  Widget build(BuildContext context) => ModelView((model) {
    if (model.ingredients.isEmpty) return const _NoIngredients();
    final matches =
        model.ingredients
            .where((ingredient) => matchesQuery(ingredient.name, _search.text))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return Column(
      children: [
        SearchField(controller: _search, hintText: 'Search ingredients'),
        Expanded(
          child: matches.isEmpty
              ? _NoMatch(_search.text.trim())
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) => _Row(matches[index]),
                ),
        ),
      ],
    );
  });
}

class _Row extends ConsumerWidget {
  const _Row(this.ingredient);

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    key: ValueKey(ingredient.name),
    title: Text(ingredient.name),
    trailing: _StockChip(ingredient.stock),
    onTap: () => unawaited(
      ref
          .read(modelProvider.notifier)
          .setStock(ingredient.name, ingredient.stock.next),
    ),
  );
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
  const _NoMatch(this.query);

  final String query;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off_outlined,
    title: 'Nothing matches',
    message: 'No ingredient here is called "$query".',
  );
}
