/// The small controls a field-carrying screen reaches for.
library;

import 'package:flutter/material.dart';

/// What the run of fields under it settles — the one heading every editor
/// divides itself by, so two forms never space their sections apart.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// One pick of a fixed few, full width — the Amounts screen's own control, the
/// Shopping settings' three, and every other segmented choice in the app, made
/// the one way.
class Segments<T> extends StatelessWidget {
  const Segments({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onPick,
    this.tooltipOf,
    this.showSelectedIcon = false,
    this.style,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final String Function(T value)? tooltipOf;
  final ValueChanged<T> onPick;
  final bool showSelectedIcon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    segments: [
      for (final value in values)
        ButtonSegment(
          value: value,
          label: Text(labelOf(value)),
          tooltip: tooltipOf?.call(value),
        ),
    ],
    selected: {selected},
    showSelectedIcon: showSelectedIcon,
    style: style,
    onSelectionChanged: (picked) => onPick(picked.single),
  );
}

/// Two or more acts in one segmented shape — [Segments]' look, where a tap
/// leaves the screen rather than settling a choice. [taken] is the act whose
/// answer the form is holding, lit and ticked exactly as a picked segment is,
/// and null before any has been taken. Tapping the lit one takes it again:
/// nothing here is a choice to be un-made.
class SegmentedActions<T> extends StatelessWidget {
  const SegmentedActions({
    required this.values,
    required this.labelOf,
    required this.iconOf,
    required this.onAct,
    this.taken,
    super.key,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final IconData Function(T value) iconOf;
  final T? taken;

  /// Null closes every segment at once — a wait the whole control is under.
  final ValueChanged<T>? onAct;

  @override
  Widget build(BuildContext context) {
    final taken = this.taken;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: [
          for (final value in values)
            ButtonSegment(
              value: value,
              label: Text(labelOf(value)),
              icon: Icon(iconOf(value)),
            ),
        ],
        selected: taken == null ? const {} : {taken},
        emptySelectionAllowed: true,
        // A tap on the lit one comes back as nothing selected, this being a
        // control that lets go; it means take that act again, which is what
        // its label offers.
        onSelectionChanged: onAct == null
            ? null
            : (acted) => onAct!(acted.isEmpty ? taken as T : acted.single),
      ),
    );
  }
}

/// A dimmed line under a control saying what it will do — what a hint cannot
/// carry, at the size the fact is worth.
class FieldNote extends StatelessWidget {
  const FieldNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
    ),
  );
}
