/// The frame and the row list both editors are built from — the recipe form
/// and the units screen alike (docs/ui-design.md#recipe-form, #units).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'vocabulary_dialogs.dart';

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
    this.readOnly = false,
    super.key,
  });

  final String title;

  /// Whether nothing here is this reader's to write, which is not the same as
  /// [onSave] being null: that is nothing valid to save *yet*. Read-only drops
  /// the Save rather than dimming it, a guest bar being offered nothing it
  /// would have to refuse (FR-BAR-4).
  final bool readOnly;

  /// Whether anything has changed since opening; untouched pops silently.
  final bool dirty;

  /// What the discard prompt asks about — the rest of its wording is shared.
  final String discardTitle;

  final VoidCallback? onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: readOnly || !dirty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_discard(context));
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: readOnly
            ? const []
            : [TextButton(onPressed: onSave, child: const Text('Save'))],
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
