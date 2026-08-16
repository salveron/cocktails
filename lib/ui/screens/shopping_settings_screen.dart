import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/editor_form.dart';

/// What the optimizer is asked and where its screen starts (FR-SET-2, ADR 24),
/// designed in docs/ui-design.md#shopping. Every control settles on the tap:
/// nothing here can be half-entered, so there is nothing to save and no Save to
/// say otherwise — which is what tells this screen from the two above it.
///
/// Owned bars only: Settings dims the row leading here on a guest one, which
/// has no optimizer to ask (FR-BAR-4).
class ShoppingSettingsScreen extends ConsumerWidget {
  const ShoppingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopping = ref.watch(shoppingProvider);
    void settle(Shopping edited) =>
        unawaited(ref.read(shelfProvider.notifier).setShopping(edited));
    return Scaffold(
      appBar: AppBar(title: const Text('Shopping')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionLabel('Tags'),
          _Segments(
            values: const [false, true],
            selected: shopping.aiming,
            labelOf: (aiming) => aiming ? 'Aim' : 'Sift',
            onPick: (aiming) => settle(shopping.copyWith(aiming: aiming)),
          ),
          FieldNote(
            shopping.aiming
                ? 'Baskets rank by how many of those recipes they unlock.'
                : 'Baskets are kept where every tag picked is unlocked.',
          ),
          const SectionLabel('Baskets'),
          _Segments(
            values: basketCounts,
            selected: shopping.most,
            labelOf: (most) => '$most',
            onPick: (most) => settle(shopping.copyWith(most: most)),
          ),
          const FieldNote('How many of each size the list offers.'),
          const SectionLabel('Opens at'),
          _Segments(
            values: budgets,
            selected: shopping.budget,
            labelOf: (budget) => '$budget',
            onPick: (budget) => settle(shopping.copyWith(budget: budget)),
          ),
          const FieldNote('The budget the shopping screen starts on.'),
          _Toggle(
            title: 'Low too',
            note: 'Start with what is running low counted as short.',
            value: shopping.restocking,
            onChanged: (on) => settle(shopping.copyWith(restocking: on)),
          ),
          _Toggle(
            title: 'Optional lines',
            note: 'Shop for the lines a recipe marks optional.',
            value: shopping.buyingOptional,
            onChanged: (on) => settle(shopping.copyWith(buyingOptional: on)),
          ),
        ],
      ),
    );
  }
}

/// One pick of a fixed few, full width — the Amounts screen's own control, and
/// the shopping screen's, so a setting is made here the way it is made there.
class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onPick,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    segments: [
      for (final value in values)
        ButtonSegment(value: value, label: Text(labelOf(value))),
    ],
    selected: {selected},
    showSelectedIcon: false,
    onSelectionChanged: (picked) => onPick(picked.single),
  );
}

/// A switch and what it does, laid out as the pickers above are: the label at
/// the section labels' weight, the sentence in a [FieldNote] under it.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.note,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: SectionLabel(title)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
      FieldNote(note),
    ],
  );
}
