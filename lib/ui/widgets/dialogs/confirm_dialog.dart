/// The one dialog that asks a yes-or-no, and every preset built on it: delete
/// (blocked or not) and discard (docs/ui-design.md#vocabulary-editing).
library;

import 'package:flutter/material.dart';

import 'dialog_frame.dart';

/// The one dialog that asks a yes-or-no: the question, whatever it has to list
/// under it, and two buttons. Dismissed without answering counts as no. Leave
/// [confirm] out for a refusal — there is nothing to agree to.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String cancel,
  List<String> bullets = const [],
  String? footer,
  String? confirm,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => DialogFrame(
        title: title,
        content: [
          Text(message),
          if (bullets.isNotEmpty) const SizedBox(height: 8),
          for (final entry in bullets) Text('• $entry'),
          if (footer != null) ...[const SizedBox(height: 8), Text(footer)],
        ],
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancel),
          ),
          if (confirm != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirm),
            ),
        ],
      ),
    ) ??
    false;

/// Ask to delete something nothing stands in the way of — for a caller that
/// already knows so, nothing referencing a recipe.
Future<bool> askToDelete(BuildContext context, {required String what}) =>
    confirmDialog(
      context,
      title: 'Delete "$what"?',
      message: 'Nothing references it. This cannot be undone.',
      cancel: 'Cancel',
      confirm: 'Delete',
    );

/// Name what stands in the way, and what to clear first (FR-VOC-1) — for a
/// caller that has already found something does. A telling, not an asking:
/// there is nothing here to answer.
Future<void> sayWhatBlocks(
  BuildContext context, {
  required String what,
  required List<String> blockedBy,
  required String blockedByNoun,
}) => confirmDialog(
  context,
  title: 'Cannot delete "$what"',
  message: 'Remove it from these $blockedByNoun first:',
  bullets: blockedBy,
  cancel: 'Close',
);

/// Ask to delete, or say why it cannot go — for a caller holding the answer to
/// "what references this" without having read it. True only if free and
/// confirmed; a blocked entry is told about, and a telling answers false.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  required List<String> blockedBy,
  required String blockedByNoun,
}) async {
  if (blockedBy.isEmpty) return askToDelete(context, what: what);
  await sayWhatBlocks(
    context,
    what: what,
    blockedBy: blockedBy,
    blockedByNoun: blockedByNoun,
  );
  return false;
}

/// Ask before dropping edits; only what is being dropped differs, so the rest
/// of the wording is settled here. [EditorScaffold] is its only caller.
Future<bool> confirmDiscard(BuildContext context, String title) =>
    confirmDialog(
      context,
      title: title,
      message: 'Edits will be lost.',
      cancel: 'Keep editing',
      confirm: 'Discard',
    );
