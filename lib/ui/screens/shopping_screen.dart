import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../destinations.dart';
import '../widgets/color_chip.dart';
import '../widgets/editor_form.dart';
import '../widgets/empty_state.dart';
import '../widgets/vocabulary_list.dart';

String _ingredientsOf(Purchase purchase) => purchase.ingredients.join(' + ');

String _countOf(Purchase purchase) =>
    counted(purchase.unlocks.length, 'recipe');

/// What the switch widens the search to, spelt out where two words on it
/// cannot (FR-DIS-7, ADR 16).
const _lowMeans =
    'Buys the ingredients running low alongside the ones out of stock.';

/// What to buy next (FR-DIS-6, FR-DIS-7, FR-DIS-10): the baskets of exactly the
/// budget's worth of ingredients, best first, narrowed to the categories
/// picked, each opening onto what it unlocks. Designed in
/// docs/ui-design.md#shopping-screen.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({required this.showing, super.key});

  /// Whether this is the destination on show. The shell keeps all three alive,
  /// and the optimizer is the one computation that must not run for a screen
  /// nobody is looking at — a stock tap on the ingredients screen would
  /// otherwise fire a search whose answer no one is reading.
  final bool showing;

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  /// Where the two controls stand once the reader has moved them — absent
  /// while a control still reads the bar's settings (FR-SET-2) live, so a
  /// default moved in Settings takes hold at once there, and moving one
  /// control never carries the other away from its own default (the shell
  /// keeps this screen alive across a crossing, so there is no fresh build to
  /// re-open on). Judged and written back to separately, each stands on its
  /// own once picked, exactly as "move freely from there, writing neither
  /// back" promises.
  int? _budgetOverride;
  bool? _restockingOverride;

  final _expanded = <String>{};

  /// The recipe tags narrowing the baskets (FR-DIS-10) — screen state like the
  /// budget and the switch, so nothing about a way of looking reaches the file.
  final _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    if (!widget.showing) return const SizedBox.shrink();
    final opening = ref.watch(shoppingProvider);
    final budget = _budgetOverride ?? opening.budget;
    final restocking = _restockingOverride ?? opening.restocking;
    final aiming = opening.aiming;
    final collection = ref.watch(collectionProvider);
    final vocabulary = ref.watch(recipeTagsProvider);
    final worn = {
      for (final recipe in collection.recipes) recipe.name: recipe.tags,
    };
    final filter = _tagFilter(vocabulary, worn, aiming: aiming);
    // Aiming, the picks are what the search was for, so they reach it; sifting,
    // they narrow what it already answered and the key must not move (ADR 24).
    final purchases = ref.watch(
      purchasesProvider(
        ShoppingAsk(
          restocking: restocking,
          aimedAt: aiming ? filter?.picks ?? const [] : const [],
        ),
      ),
    );
    // Off `tagFilter`'s own published picks rather than `_picked` again, so
    // nothing is dotted by a pick that stopped narrowing.
    final lit = wornInOrder(vocabulary, filter?.picks ?? const []);
    // Ranked among every basket of the size, then narrowed — the rank is bound
    // before the tags drop any, so sifting gaps the numbering. Aiming keeps
    // them all, the search having answered the picks itself, so it runs
    // unbroken: which reading is in force is read off the gaps (ADR 24).
    final onShow = [
      for (final (rank, purchase)
          in purchases
              .where((purchase) => purchase.ingredients.length == budget)
              .indexed)
        if (filter?.test(purchase) ?? true) (rank: rank + 1, basket: purchase),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Controls(
          budget: budget,
          restocking: restocking,
          onBudget: (budget) => setState(() => _budgetOverride = budget),
          onRestocking: (on) => setState(() => _restockingOverride = on),
        ),
        ?filter?.row,
        Expanded(
          child: onShow.isEmpty
              ? _emptyFor(
                  collection,
                  purchases,
                  filter,
                  aiming: aiming,
                  budget: budget,
                  restocking: restocking,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: onShow.length,
                  itemBuilder: (context, index) => _card(
                    collection,
                    onShow[index].basket,
                    onShow[index].rank,
                    lit: lit,
                    worn: worn,
                  ),
                ),
        ),
      ],
    );
  }

  /// The chip row and what it keeps (FR-DIS-10), on the recipes' own terms: a
  /// basket answers to the tags of every recipe it unlocks, so the row's own
  /// test — every picked tag worn — reaches a basket bringing one tiki recipe
  /// and one sour rather than demanding a recipe that is both. A pick gone
  /// stale is read against the vocabulary there and stops narrowing, and a
  /// collection with no recipe tags draws no row at all.
  ///
  /// [aiming] is the other reading (ADR 24): the picks went into the search, so
  /// every basket that came back already answers them and the row keeps them
  /// all. Its reason turns with it, a basket having been weighed by any pick
  /// rather than kept for every one.
  ListFilter<Purchase>? _tagFilter(
    List<Tag> vocabulary,
    Map<String, List<String>> worn, {
    required bool aiming,
  }) {
    final sifting = tagFilter<Purchase>(
      vocabulary: vocabulary,
      picked: _picked,
      onToggle: (tag) => setState(() => _picked.toggle(tag)),
      tagsOf: (purchase) => [
        for (final recipe in purchase.unlocks) ...?worn[recipe],
      ],
    );
    if (sifting == null || !aiming) return sifting;
    return (
      row: sifting.row,
      test: (_) => true,
      narrowing: sifting.picks.isEmpty ? null : 'any tag picked',
      picks: sifting.picks,
    );
  }

  Widget _card(
    Collection collection,
    Purchase purchase,
    int rank, {
    required List<Tag> lit,
    required Map<String, List<String>> worn,
  }) {
    final ingredients = _ingredientsOf(purchase);
    return ExpandingRow(
      open: _expanded.contains(ingredients),
      title: Text('Shopping Cart #$rank'),
      subtitle: ingredients,
      trailing: MutedText(
        _countOf(purchase),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      body: _Basket(
        collection: collection,
        purchase: purchase,
        lit: lit,
        worn: worn,
      ),
      onToggle: () => setState(() => _expanded.toggle(ingredients)),
    );
  }

  /// Why there is nothing to show, which is three different answers: no recipes
  /// to be short of, nothing short of anything, or nothing on show worth the
  /// money. Only the last leaves somewhere to go — the smallest size answering
  /// under the tags in force, absent where none does — and it blames the picks
  /// rather than the size where they are what emptied the screen.
  Widget _emptyFor(
    Collection collection,
    List<Purchase> purchases,
    ListFilter<Purchase>? filter, {
    required bool aiming,
    required int budget,
    required bool restocking,
  }) {
    if (collection.recipes.isEmpty) {
      return const EmptyState(
        icon: Icons.local_bar_outlined,
        title: 'No recipes yet',
        message:
            'Add a few recipes and the ingredients that unlock the most of them '
            'appear here.',
      );
    }
    if (purchases.isEmpty) {
      // Aiming, the picks went into the search, so an empty answer is about
      // them rather than about the shelf: the untagged recipes may be short of
      // plenty, and saying the bar wants for nothing would be false (ADR 24).
      final aimed = aiming ? filter?.narrowing : null;
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Nothing to shop for',
        message: switch (aimed) {
          final aimed? => 'No shopping unlocks a recipe matching $aimed.',
          null when restocking =>
            'Every ingredient the recipes ask for is fully in stock.',
          null => 'Every recipe here can be made from what is on the shelf.',
        },
      );
    }
    final narrowing = filter?.narrowing;
    final basket = budget == 1
        ? 'single ingredient'
        : '$budget-ingredient basket';
    final sizes = purchases
        .where((purchase) => filter?.test(purchase) ?? true)
        .map((purchase) => purchase.ingredients.length);
    final elsewhere = sizes.isEmpty
        ? null
        : sizes.reduce((a, b) => a < b ? a : b);
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Nothing worth buying in $budget',
      message: switch (narrowing) {
        final narrowing? =>
          'No $basket here unlocks a recipe matching '
              '$narrowing.',
        null when budget == 1 =>
          'No single ingredient unlocks a recipe on its own here.',
        null => 'Every $basket does no better than a smaller one inside it.',
      },
      action: elsewhere == null
          ? null
          : FilledButton.tonal(
              onPressed: () => setState(() => _budgetOverride = elsewhere),
              child: Text('Try ${counted(elsewhere, 'ingredient')}'),
            ),
    );
  }
}

/// The budget and what counts as short, on the one row above the list — the two
/// things a reader sets, and the whole of what the answer below depends on. The
/// switch says its meaning in two words and carries the rest as its tooltip.
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
    final label = Theme.of(context).textTheme.labelMedium;
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
              Segments(
                values: budgets,
                selected: budget,
                labelOf: (size) => '$size',
                tooltipOf: (size) => counted(size, 'ingredient'),
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -4, vertical: -2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPick: onBudget,
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

/// The open card: what to buy, each ingredient at the level it stands at, then
/// every recipe the basket unlocks, each marking the picks it answered
/// (FR-DIS-10). The stock dots are what the switch is worth reading — with it
/// on, a basket mixes ingredients merely running low with ones there are none
/// of.
///
/// Every name here reaches the row it stands for, on the destination that keeps
/// it (FR-DIS-9, ADR 19): an ingredient the Ingredients screen, a recipe the
/// Recipes. A basket holds entries' own names, so nothing here resolves a
/// spelling.
class _Basket extends ConsumerWidget {
  const _Basket({
    required this.collection,
    required this.purchase,
    required this.lit,
    required this.worn,
  });

  final Collection collection;
  final Purchase purchase;
  final List<Tag> lit;
  final Map<String, List<String>> worn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void reach(Destination destination, String name) =>
        ref.read(revealProvider.notifier).ask(destination, name);
    return BulletRuns([
      (
        label: 'Ingredients',
        bullets: [
          for (final ingredient in purchase.ingredients)
            (
              name: ingredient,
              trailing: StockDot(stockOf(collection, ingredient)),
            ),
        ],
        onTap: (ingredient) => reach(Destination.ingredients, ingredient),
      ),
      (
        label: 'Unlocks',
        bullets: [
          for (final recipe in purchase.unlocks)
            (name: recipe, trailing: _dotsOn(recipe)),
        ],
        onTap: (recipe) => reach(Destination.recipes, recipe),
      ),
    ]);
  }

  Widget? _dotsOn(String recipe) {
    final dots = wornInOrder(lit, worn[recipe] ?? const []);
    return dots.isEmpty ? null : TagDots(dots);
  }
}
