import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme.dart';
import '../widgets/forms/editor_form.dart';
import '../widgets/forms/field_issues.dart';
import '../widgets/forms/form_fields.dart';

/// The unit amounts read in and what each of the others is worth (FR-SET-1),
/// designed in docs/ui-design.md#amounts.
class AmountsScreen extends ConsumerStatefulWidget {
  const AmountsScreen({super.key});

  @override
  ConsumerState<AmountsScreen> createState() => _AmountsScreenState();
}

/// A row per unit carrying a size of its own; ml is the anchor and carries
/// none, so it is the one fixed unit without a row (ADR 17).
final _sizedUnits = FixedUnit.values
    .where((unit) => unit != FixedUnit.ml)
    .toList();

class _AmountsScreenState extends ConsumerState<AmountsScreen> {
  /// The collection this screen opened on; nothing else edits it while it
  /// stands.
  late final Collection _opened = ref.read(collectionProvider);

  /// What the bar read in when the screen opened — the pick's own baseline, so
  /// a Save this screen makes can never revert a change a live watch here
  /// could otherwise race (ADR 21).
  late final FixedUnit _openedDisplay =
      ref.read(openBarProvider)?.display ?? FixedUnit.part;

  /// What a Save would write. The rows are readings of it, never the other way
  /// round: a size the reader has not typed at keeps the number it had, so
  /// picking another unit cannot drift it.
  late Settings _entered = _opened.settings;

  /// The pick, edited beside the sizes and saved to the bar rather than into
  /// the collection — the two belong to different people on a guest bar
  /// (ADR 21).
  late FixedUnit _display = _openedDisplay;

  late final _fields = {
    for (final sized in _sizedUnits)
      sized: TextEditingController(text: _reading(sized)),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// [sized]'s row as "1 lead = N trail". The global unit leads, except ml —
  /// "1 ml = 0.0333 part" is a number no one can read or type back — so under
  /// ml each row leads with the unit it sizes, which is the file's own shape.
  (FixedUnit, FixedUnit) _unitsFor(FixedUnit sized) {
    if (_display == FixedUnit.ml) return (sized, FixedUnit.ml);
    return (_display, sized == _display ? FixedUnit.ml : sized);
  }

  String _reading(FixedUnit sized) {
    final (lead, trail) = _unitsFor(sized);
    return formatNumber(_rounded(_entered.ratio(lead, trail)));
  }

  /// What a row says, or null where that is not a number above zero — a ratio
  /// of zero has no inverse, so the field refuses it before a size can.
  double? _typed(FixedUnit sized) {
    final value = double.tryParse(_fields[sized]!.typed);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  void _apply(FixedUnit sized) => setState(() {
    final typed = _typed(sized);
    if (typed != null) {
      final (lead, trail) = _unitsFor(sized);
      _entered = _entered.withRatio(lead, trail, typed);
    }
    _rewrite(except: sized);
  });

  void _pick(FixedUnit display) => setState(() {
    _display = display;
    _rewrite();
  });

  /// Puts every row but the one being typed in back in step with the sizes,
  /// since a row reading across two of them moves when either does.
  void _rewrite({FixedUnit? except}) {
    for (final sized in _sizedUnits) {
      if (sized != except) _fields[sized]!.text = _reading(sized);
    }
  }

  @override
  Widget build(BuildContext context) {
    final writer = ref.watch(barWriterProvider);
    final issues = validateCollection(settings: _entered);
    final errors = _errors(issues, writable: writer != null);
    return EditorScaffold(
      title: 'Amounts',
      dirty:
          (writer != null && _entered != _opened.settings) ||
          _display != _openedDisplay,
      discardTitle: 'Discard these amounts?',
      onSave: issues.isEmpty && errors.isEmpty
          ? () => unawaited(_save(writer))
          : null,
      children: [
        MutedText(
          'Amounts in "$partUnit", "$mlUnit" and "$ozUnit" read in the unit '
          'picked here; every other unit reads as entered. Nothing converted '
          'is written — a recipe keeps every line as it was entered.'
          '${writer == null ? " The sizes below are the owner's." : ''}',
        ),
        const SizedBox(height: 16),
        Segments(
          values: FixedUnit.values,
          selected: _display,
          labelOf: (unit) => unit.token,
          onPick: _pick,
        ),
        const SizedBox(height: 16),
        _SizeTable(
          sizedUnits: _sizedUnits,
          fields: _fields,
          writable: writer != null,
          unitsFor: _unitsFor,
          errorFor: (sized) => errors[sized],
          onEdit: _apply,
        ),
      ],
    );
  }

  /// The message each row's field shows: a row nobody may type in cannot be
  /// wrong, and the owner's sizes are not this reader's to be told off for.
  /// The settings' own rules judge the rows, so a ratio the file would refuse
  /// is a ratio this screen refuses (ADR 05).
  Map<FixedUnit, String> _errors(
    List<ValidationIssue> issues, {
    required bool writable,
  }) {
    if (!writable) return const {};
    final refused = firstIssuePerField(
      issues,
      (issue) => switch (issue.path) {
        ['settings', 'part_ml'] => FixedUnit.part,
        ['settings', 'oz_ml'] => FixedUnit.oz,
        _ => null,
      },
    );
    final errors = <FixedUnit, String>{};
    for (final sized in _sizedUnits) {
      final message = _typed(sized) == null
          ? 'Must be a number above zero'
          : refused[sized];
      if (message != null) errors[sized] = message;
    }
    return errors;
  }

  /// Two writes, because the sizes go to the collection's file and the pick to
  /// the bar's record (ADR 21); each is a no-op where nothing moved. Two
  /// surfaces with them: the sizes are the owner's, the pick the reader's on a
  /// guest bar as on their own (FR-BAR-3), so a guest saves the pick alone.
  Future<void> _save(BarWriter? writer) async {
    await writer?.setSettings(_entered);
    await ref.read(shelfProvider.notifier).setDisplay(_display);
    if (mounted) Navigator.of(context).pop();
  }
}

/// A table, so both rows' fields stand in line whatever the units around them
/// are spelled like — and go on doing so under a reader's larger text, which
/// no width written here would survive.
class _SizeTable extends StatelessWidget {
  const _SizeTable({
    required this.sizedUnits,
    required this.fields,
    required this.writable,
    required this.unitsFor,
    required this.errorFor,
    required this.onEdit,
  });

  final List<FixedUnit> sizedUnits;
  final Map<FixedUnit, TextEditingController> fields;
  final bool writable;
  final (FixedUnit, FixedUnit) Function(FixedUnit sized) unitsFor;
  final String? Function(FixedUnit sized) errorFor;
  final void Function(FixedUnit sized) onEdit;

  @override
  Widget build(BuildContext context) => Table(
    columnWidths: const {
      0: IntrinsicColumnWidth(),
      1: FlexColumnWidth(),
      2: IntrinsicColumnWidth(),
    },
    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      for (final sized in sizedUnits)
        _ratioRow(
          row: unitsFor(sized),
          field: fields[sized]!,
          writable: writable,
          error: errorFor(sized),
          onEdit: () => onEdit(sized),
        ),
    ],
  );
}

/// Ratios read to four decimals — enough to spell a US ounce (29.5735) exactly,
/// short enough to take in. Only the reading rounds: a row left alone writes
/// nothing back, so the stored size keeps every digit it had.
double _rounded(double value) => (value * 10000).roundToDouble() / 10000;

/// One ratio as a sentence — "1 part = [30] ml" — the number its only field.
TableRow _ratioRow({
  required (FixedUnit, FixedUnit) row,
  required TextEditingController field,
  required bool writable,
  required String? error,
  required VoidCallback onEdit,
}) {
  final (lead, trail) = row;
  return TableRow(
    children: [
      Text('1 ${lead.token} ='),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: field,
          enabled: writable,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(errorText: error),
          onChanged: (_) => onEdit(),
        ),
      ),
      Text(trail.token),
    ],
  );
}
