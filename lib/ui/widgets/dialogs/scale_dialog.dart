/// The reading a recipe card is asked for (FR-REC-7), designed in
/// docs/ui-design.md#recipes-screen.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../cards/recipe_card.dart';
import '../forms/form_fields.dart';
import 'dialog_frame.dart';

/// Reads the open card at another factor, in another unit, or both — for as
/// long as it stays open (FR-REC-7). Nothing about the recipe changes, so the
/// way back is [view] handed straight back, the reading every other card is
/// under.
Future<AmountView?> promptForScale(
  BuildContext context, {
  required String recipe,
  required AmountView view,
}) => showDialog<AmountView>(
  context: context,
  builder: (_) => _ScaleDialog(recipe: recipe, view: view),
);

/// Both readings settled in one place, applied on Apply and dropped on Cancel
/// — the card behind stands as it was until then. Picking [restingView] again
/// is the way back, so the dialog needs no reset of its own.
class _ScaleDialog extends StatefulWidget {
  const _ScaleDialog({required this.recipe, required this.view});

  final String recipe;
  final AmountView view;

  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  late AmountView _view = widget.view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DialogFrame(
      title: 'Scale & convert',
      // Full width, so both controls start where the recipe's name does.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      content: [
        MutedText(widget.recipe, style: theme.textTheme.bodyMedium),
        const SectionLabel('Scale'),
        Segments(
          values: scaleFactors,
          selected: _view.scale,
          labelOf: (factor) => '×$factor',
          onPick: (factor) =>
              setState(() => _view = (scale: factor, unit: _view.unit)),
        ),
        const SectionLabel('Show in'),
        Segments(
          values: FixedUnit.values,
          selected: _view.unit,
          labelOf: (unit) => unit.token,
          onPick: (unit) =>
              setState(() => _view = (scale: _view.scale, unit: unit)),
        ),
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_view),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
