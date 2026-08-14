import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/editor_form.dart';
import '../widgets/vocabulary_dialogs.dart';

/// The unit amounts read in and what each of the others is worth (FR-SET-1),
/// designed in docs/ui-design.md#amounts.
class AmountsScreen extends ConsumerWidget {
  const AmountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _AmountsForm(ref.watch(collectionProvider));
}

class _AmountsForm extends ConsumerStatefulWidget {
  const _AmountsForm(this.collection);

  /// The settings the screen opens on; nothing else edits them while it stands.
  final Collection collection;

  @override
  ConsumerState<_AmountsForm> createState() => _AmountsFormState();
}

/// A row per unit carrying a size of its own; ml is the anchor and carries
/// none, so it is the one fixed unit without a row (ADR 17).
final _sizedUnits = FixedUnit.values
    .where((unit) => unit != FixedUnit.ml)
    .toList();

class _AmountsFormState extends ConsumerState<_AmountsForm> {
  /// What a Save would write. The rows are readings of it, never the other way
  /// round: a size the reader has not typed at keeps the number it had, so
  /// picking another unit cannot drift it.
  late Settings _entered = widget.collection.settings;

  /// The pick, edited beside the sizes and saved to the bar rather than into
  /// the collection — the two belong to different people on a guest bar
  /// (ADR 21).
  late FixedUnit _display = _saved;

  FixedUnit get _saved => ref.read(openBarProvider)?.display ?? FixedUnit.part;

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
  (FixedUnit, FixedUnit) _row(FixedUnit sized) {
    if (_display == FixedUnit.ml) return (sized, FixedUnit.ml);
    return (_display, sized == _display ? FixedUnit.ml : sized);
  }

  String _reading(FixedUnit sized) {
    final (lead, trail) = _row(sized);
    return formatNumber(_rounded(_entered.ratio(lead, trail)));
  }

  /// What a row says, or null where that is not a number above zero — a ratio
  /// of zero has no inverse, so the field refuses it before a size can.
  double? _typed(FixedUnit sized) {
    final value = double.tryParse(_fields[sized]!.typed);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  void _edit(FixedUnit sized) => setState(() {
    final typed = _typed(sized);
    if (typed != null) {
      final (lead, trail) = _row(sized);
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
    // The settings' own rules judge the rows, so a ratio the file would refuse
    // is a ratio this screen refuses (ADR 05).
    final issues = validateCollection(settings: _entered);
    final refused = firstIssuePerField(
      issues,
      (issue) => switch (issue.path) {
        ['settings', 'part_ml'] => FixedUnit.part,
        ['settings', 'oz_ml'] => FixedUnit.oz,
        _ => null,
      },
    );
    final unread = {
      for (final sized in _sizedUnits)
        if (_typed(sized) == null) sized: 'Must be a number above zero',
    };
    return EditorScaffold(
      title: 'Amounts',
      dirty: _entered != widget.collection.settings || _display != _saved,
      discardTitle: 'Discard these amounts?',
      onSave: issues.isEmpty && unread.isEmpty
          ? () => unawaited(_save())
          : null,
      children: [
        Text(
          'Amounts in "$partUnit", "$mlUnit" and "$ozUnit" read in the unit '
          'picked here; every other unit reads as entered. Nothing converted '
          'is written — a recipe keeps every line as you typed it.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<FixedUnit>(
          segments: [
            for (final unit in FixedUnit.values)
              ButtonSegment(value: unit, label: Text(unit.token)),
          ],
          selected: {_display},
          showSelectedIcon: false,
          onSelectionChanged: (picked) => _pick(picked.single),
        ),
        const SizedBox(height: 16),
        // A table, so both rows' fields stand in line whatever the units around
        // them are spelled like — and go on doing so under a reader's larger
        // text, which no width written here would survive.
        Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(),
            1: FlexColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (final sized in _sizedUnits)
              _ratioRow(
                row: _row(sized),
                field: _fields[sized]!,
                error: unread[sized] ?? refused[sized],
                onEdit: () => _edit(sized),
              ),
          ],
        ),
      ],
    );
  }

  /// Two writes, because the sizes go to the collection's file and the pick to
  /// the bar's record (ADR 21); each is a no-op where nothing moved. Two
  /// surfaces with them: the sizes are the owner's, the pick the reader's on a
  /// guest bar as on their own (FR-BAR-3), so a guest bar is offered the pick
  /// alone.
  Future<void> _save() async {
    await ref.read(barWriterProvider)!.setSettings(_entered);
    await ref.read(shelfProvider.notifier).setDisplay(_display);
    if (mounted) Navigator.of(context).pop();
  }
}

/// Ratios read to four decimals — enough to spell a US ounce (29.5735) exactly,
/// short enough to take in. Only the reading rounds: a row left alone writes
/// nothing back, so the stored size keeps every digit it had.
double _rounded(double value) => (value * 10000).roundToDouble() / 10000;

/// One ratio as a sentence — "1 part = [30] ml" — the number its only field.
TableRow _ratioRow({
  required (FixedUnit, FixedUnit) row,
  required TextEditingController field,
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(errorText: error),
          onChanged: (_) => onEdit(),
        ),
      ),
      Text(trail.token),
    ],
  );
}
