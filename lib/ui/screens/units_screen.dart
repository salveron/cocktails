import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/editor_form.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_dialogs.dart';

/// The measurement vocabulary (FR-VOC-5), edited in place: a row per unit and
/// one Save for the screen, so two units can trade names in a single edit.
/// Designed in docs/ui-design.md#units.
class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) => ModelView(_UnitsForm.new);
}

class _UnitsForm extends ConsumerStatefulWidget {
  const _UnitsForm(this.model);

  /// The vocabulary the rows open on; nothing else edits it while they stand.
  final Model model;

  @override
  ConsumerState<_UnitsForm> createState() => _UnitsFormState();
}

class _UnitsFormState extends ConsumerState<_UnitsForm> {
  late final _rows = GrowingRows<_UnitRow>(
    blankRow: () => _row(const Unit('')),
    isBlank: (row) => row.blank,
    disposeRow: (row) => row.dispose(),
    initial: [
      for (final unit in widget.model.units) _row(unit, was: unit.name),
    ],
  );

  _UnitRow _row(Unit unit, {String? was}) =>
      _UnitRow(unit, was: was, onEdit: () => setState(_rows.settle));

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  bool get _dirty => !listEquals([
    for (final row in _rows.entered) row.unit,
  ], widget.model.units);

  @override
  Widget build(BuildContext context) {
    final entered = _rows.entered;
    // The vocabulary's own rules judge the rows, so a name the file would
    // refuse is a name this screen refuses (ADR 05).
    final issues = validateModel(units: [for (final row in entered) row.unit]);
    // The bool is the plural column, so both fields of a row key apart.
    final problems = firstIssuePerField(
      issues,
      (issue) => switch (issue.path) {
        ['units', final int row] => (entered[row], false),
        ['units', final int row, 'plural'] => (entered[row], true),
        _ => null,
      },
    );
    return EditorScaffold(
      title: 'Units',
      dirty: _dirty,
      discardTitle: 'Discard these units?',
      onSave: issues.isEmpty ? () => unawaited(_save(entered)) : null,
      children: [
        Text(
          'A plural left empty reads like the name. '
          '"$partUnit", "$mlUnit" and "$ozUnit" cannot be renamed or deleted — '
          'amounts convert between them.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const _HeaderRow(),
        for (final row in _rows.rows)
          _Fields(
            row,
            nameError: problems[(row, false)],
            pluralError: problems[(row, true)],
            onDelete: () => unawaited(_delete(row)),
          ),
      ],
    );
  }

  /// Refuses while a recipe line measures in it, naming what stands in the way
  /// (FR-VOC-1); otherwise the row goes, and leaving without saving puts it
  /// back.
  Future<void> _delete(_UnitRow row) async {
    final was = row.was;
    if (was != null) {
      final blockedBy = widget.model.recipesUsingUnit(was);
      if (blockedBy.isNotEmpty) {
        await confirmDelete(
          context,
          what: was,
          blockedBy: blockedBy,
          blockedByNoun: 'recipes',
        );
        return;
      }
    }
    setState(() => _rows.remove(row));
  }

  Future<void> _save(List<_UnitRow> entered) async {
    await ref.read(modelProvider.notifier).setUnits([
      for (final row in entered) (unit: row.unit, was: row.was),
    ]);
    if (mounted) Navigator.of(context).pop();
  }
}

/// One row: the fields it is edited through, and the name it came from — null
/// where it is new, which is also what a delete asks the model about.
class _UnitRow {
  _UnitRow(Unit unit, {required this.was, required VoidCallback onEdit})
    : name = TextEditingController(text: unit.name),
      plural = TextEditingController(text: unit.plural) {
    name.addListener(onEdit);
    plural.addListener(onEdit);
  }

  final String? was;
  final TextEditingController name;
  final TextEditingController plural;

  bool get blank => name.isBlank && plural.isBlank;

  /// What the row now says, whitespace off.
  Unit get unit => Unit(name.typed, plural: plural.typed);

  /// A new row carries no name to be one of the fixed two by.
  bool get locked => isReservedUnit(was ?? '');

  void dispose() {
    name.dispose();
    plural.dispose();
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text('Unit', style: style)),
          const SizedBox(width: 12),
          Expanded(child: Text('Plural', style: style)),
          const SizedBox(width: _trailingWidth),
        ],
      ),
    );
  }
}

/// The width of the trailing control, kept off the fields either way so the
/// two columns stand in line whether a row can be deleted or not.
const _trailingWidth = 48.0;

class _Fields extends StatelessWidget {
  const _Fields(
    this.row, {
    required this.nameError,
    required this.pluralError,
    required this.onDelete,
  });

  final _UnitRow row;
  final String? nameError;
  final String? pluralError;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: row.name,
            enabled: !row.locked,
            decoration: InputDecoration(hintText: 'Unit', errorText: nameError),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: row.plural,
            decoration: InputDecoration(
              // Empty reads like the name, so the name is what it stands for.
              hintText: row.name.isBlank ? 'Plural' : row.name.typed,
              errorText: pluralError,
            ),
          ),
        ),
        SizedBox(width: _trailingWidth, child: _trailing(context)),
      ],
    ),
  );

  Widget? _trailing(BuildContext context) {
    if (row.locked) {
      return Tooltip(
        message: 'Fixed unit',
        child: Icon(
          Icons.lock_outline,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return row.blank
        ? null
        : IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: onDelete,
          );
  }
}
