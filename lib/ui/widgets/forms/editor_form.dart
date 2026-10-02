/// The pushed editor both forms wear: the Save/discard frame, the
/// self-growing row list, and the one ask that guards them both
/// (docs/ui-design.md#recipe-form, #units).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../dialogs/confirm_dialog.dart';

extension FieldText on TextEditingController {
  /// What the field says, whitespace off.
  String get typed => text.trim();

  bool get isBlank => typed.isEmpty;
}

/// A list of editable rows that keeps one blank row at its foot: typing into
/// the last one grows another, erasing the spare takes it back. [T] is
/// whatever a row is edited through — one controller or several.
class GrowingRows<T> {
  GrowingRows({
    required this.blankRow,
    required this.isBlank,
    required this.disposeRow,
    Iterable<T> initial = const [],
  }) {
    rows
      ..addAll(initial)
      ..add(blankRow());
  }

  final T Function() blankRow;
  final bool Function(T row) isBlank;
  final void Function(T row) disposeRow;

  /// What the screen draws, the blank foot included.
  final rows = <T>[];

  /// Rows the list has taken back. Their fields outlive them by a build, so
  /// disposing one where it is dropped would be a use-after-dispose; the
  /// screen disposes them all when it closes.
  final _dropped = <T>[];

  /// The rows that say something — the ones a Save would write.
  List<T> get entered => [
    for (final row in rows)
      if (!isBlank(row)) row,
  ];

  /// One row stands empty, never two, and never the one the cursor is in.
  void settle() {
    if (!isBlank(rows.last)) {
      rows.add(blankRow());
    } else if (rows.length > 1 && isBlank(rows[rows.length - 2])) {
      _dropped.add(rows.removeLast());
    }
  }

  /// Takes [row] back at the screen's asking. Leaving without saving is what
  /// puts it back, so it is only set aside here, never disposed.
  void remove(T row) {
    if (rows.remove(row)) _dropped.add(row);
  }

  void dispose() {
    for (final row in [...rows, ..._dropped]) {
      disposeRow(row);
    }
  }
}

/// A pushed editor: Save in the app bar, and a back that asks before dropping
/// edits. [onSave] is null while there is nothing valid to save.
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    required this.title,
    required this.dirty,
    required this.discardTitle,
    required this.onSave,
    required this.children,
    this.onReset,
    this.writable = true,
    super.key,
  });

  final String title;

  /// Whether anything here is this reader's to write — drops the Save rather
  /// than dimming it, a guest bar being offered nothing it would have to
  /// refuse (FR-BAR-4).
  final bool writable;

  /// Whether anything has changed since opening; untouched pops silently.
  final bool dirty;

  /// What the discard prompt asks about — the rest of its wording is shared.
  final String discardTitle;

  final VoidCallback? onSave;

  /// A way back to what the screen opened as, before Save because it is the
  /// lesser act and the commit should be the last thing under the thumb.
  /// Absent where there is nothing to put back.
  final VoidCallback? onReset;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !writable || !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_discard(context));
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: writable
            ? [
                if (onReset != null)
                  TextButton(onPressed: onReset, child: const Text('Reset')),
                TextButton(onPressed: onSave, child: const Text('Save')),
              ]
            : const [],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    ),
  );

  Future<void> _discard(BuildContext context) async {
    if (await confirmDiscard(context, discardTitle) && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
