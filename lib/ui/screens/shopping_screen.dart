import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_list.dart';

/// The bottles as the shut card reads them, and the key its open card is
/// remembered under: they are what a basket *is* (FR-DIS-6), where the title is
/// only where it ranks — which the next budget hands to another basket.
String _bottlesOf(Purchase purchase) => purchase.bottles.join(' + ');

String _countOf(Purchase purchase) =>
    counted(purchase.unlocks.length, 'recipe');

/// What the switch widens the search to, spelt out where two words on it
/// cannot (FR-DIS-7, ADR 16).
const _lowMeans =
    'Buy the bottles running low alongside the ones you are out of.';

/// What to buy next (FR-DIS-6, FR-DIS-7): the baskets of exactly the budget's
/// worth of bottles, best first, each opening onto what it unlocks. Designed in
/// docs/ui-design.md#shopping-screen.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({required this.showing, super.key});

  /// Whether this is the destination on show. The shell keeps all three alive,
  /// and the optimizer is the one computation that must not run for a screen
  /// nobody is looking at — a stock tap on the inventory would otherwise fire
  /// a search whose answer no one is reading.
  final bool showing;

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  /// How many bottles a basket is allowed — and, the budget picking exactly
  /// that many, how many it holds.
  int _budget = budgets.first;

  /// Whether a bottle running low counts as short (ADR 16).
  bool _restocking = false;

  /// Which cards are reading open, by their bottles. Here rather than per-card,
  /// the list disposing what scrolls out of it.
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    // Nothing is watched while another destination is on show, so the search
    // is not made and its answer is let go (see [ShoppingScreen.showing]).
    if (!widget.showing) return const SizedBox.shrink();
    return ModelView((model) {
      final purchases = ref.watch(purchasesProvider(_restocking));
      final onShow = [
        for (final purchase in purchases)
          if (purchase.bottles.length == _budget) purchase,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Controls(
            budget: _budget,
            restocking: _restocking,
            onBudget: (budget) => setState(() => _budget = budget),
            onRestocking: (on) => setState(() => _restocking = on),
          ),
          Expanded(
            child: onShow.isEmpty
                ? _emptyFor(model, purchases)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: onShow.length,
                    itemBuilder: (context, index) =>
                        _card(model, onShow[index], index + 1),
                  ),
          ),
        ],
      );
    });
  }

  /// One basket, [rank] of the baskets on show: where it stands, the bottles
  /// under that, and how much they are worth. Open, the bottles move into the
  /// body to read at the level each stands at, beside every recipe in full.
  Widget _card(Model model, Purchase purchase, int rank) {
    final bottles = _bottlesOf(purchase);
    final expanded = _expanded.contains(bottles);
    final theme = Theme.of(context);
    return VocabularyRow(
      title: Text('Shopping Cart #$rank'),
      subtitle: expanded
          ? null
          : Text(bottles, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        _countOf(purchase),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      body: expanded ? _Basket(model: model, purchase: purchase) : null,
      onTap: () => setState(() => _expanded.toggle(bottles)),
    );
  }

  /// Why there is nothing to show, which is three different answers: no recipes
  /// to be short of, nothing short of anything, or nothing at this size worth
  /// the money. Only the last leaves somewhere to go, and offers it.
  Widget _emptyFor(Model model, List<Purchase> purchases) {
    if (model.recipes.isEmpty) {
      return const EmptyState(
        icon: Icons.local_bar_outlined,
        title: 'No recipes yet',
        message:
            'Add a few recipes and the bottles that unlock the most of them '
            'appear here.',
      );
    }
    if (purchases.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Nothing to shop for',
        message: _restocking
            ? 'Every bottle your recipes ask for is fully in stock.'
            : 'Every recipe you have can be made from what is on the shelf.',
      );
    }
    final elsewhere = purchases
        .map((purchase) => purchase.bottles.length)
        .reduce((a, b) => a < b ? a : b);
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Nothing worth buying in $_budget',
      message: _budget == 1
          ? 'No single bottle unlocks a recipe on its own here.'
          : 'Every $_budget-bottle basket does no better than a smaller one '
                'inside it.',
      action: FilledButton.tonal(
        onPressed: () => setState(() => _budget = elsewhere),
        child: Text('Try ${counted(elsewhere, 'bottle')}'),
      ),
    );
  }
}

/// The budget and what counts as short, on the one row above the list — the
/// two things a reader sets, and the whole of what the answer below depends on.
/// The switch says its meaning in two words and carries the rest as its tooltip.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.budget,
    required this.restocking,
    required this.onBudget,
    required this.onRestocking,
  });

  final int budget;
  final bool restocking;
  final ValueChanged<int> onBudget;
  final ValueChanged<bool> onRestocking;

  @override
  Widget build(BuildContext context) {
    // The size a chip's label reads at, which is what these two are: a word
    // naming the control beside it, not a heading over it.
    final label = Theme.of(context).textTheme.labelMedium;
    // Wrapped rather than one fixed row: both controls stand side by side on
    // any phone that fits them, and fall to two lines on one that does not,
    // which is the one thing neither may do at all — go off the edge.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Buy', style: label),
              const SizedBox(width: 4),
              SegmentedButton<int>(
                segments: [
                  for (final size in budgets)
                    ButtonSegment(
                      value: size,
                      label: Text('$size'),
                      tooltip: counted(size, 'bottle'),
                    ),
                ],
                selected: {budget},
                showSelectedIcon: false,
                // Narrowed to 48dp a segment — the floor a touch target has,
                // and what lets both controls share the one row. Density is
                // the lever: a minimumSize never reaches a segment.
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -4, vertical: -2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (picked) => onBudget(picked.single),
              ),
            ],
          ),
          Tooltip(
            message: _lowMeans,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Low too', style: label),
                Switch(
                  value: restocking,
                  onChanged: onRestocking,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The open card: what to buy, each bottle at the level it stands at, then
/// every recipe the basket unlocks. The dots are what the switch is worth
/// reading — with it on, a basket mixes bottles merely running low with ones
/// there are none of.
class _Basket extends StatelessWidget {
  const _Basket({required this.model, required this.purchase});

  final Model model;
  final Purchase purchase;

  @override
  Widget build(BuildContext context) => BulletRuns([
    (
      label: 'Ingredients',
      bullets: [
        for (final bottle in purchase.bottles)
          (name: bottle, trailing: StockDot(stockOf(model, bottle))),
      ],
    ),
    bulletRun(purchase.unlocks, label: 'Unlocks'),
  ]);
}
