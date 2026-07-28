/// The two dialogs vocabulary editing needs — name entry and deletion — shared
/// by the ingredient and tag screens (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

/// Asks for a vocabulary name and answers with it, or null when the user backs
/// out. [validate] is that vocabulary's own rule set, so this dialog holds no
/// name rules and cannot drift from the ones the codec applies.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (context) => _NameDialog(
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
  ),
);

/// Asks whether to delete [what]; true only when a free entry was confirmed.
/// [blockedBy] names the recipes referencing it — a non-empty list turns the
/// question into a refusal naming them, which is where FR-VOC-1's blocking
/// rule meets the user.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  required List<String> blockedBy,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(what: what, blockedBy: blockedBy),
    ) ??
    false;

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hintText,
    required this.validate,
    required this.initial,
  });

  final String title;
  final String hintText;
  final List<ValidationIssue> Function(String name) validate;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text;
    final issues = widget.validate(name);
    final problem = issues.isEmpty ? null : issues.first.message;
    final save = name.isEmpty || problem != null
        ? null
        : () => Navigator.of(context).pop(name);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hintText,
          // An untouched field is not a mistake yet, so an empty one says
          // nothing and simply leaves Save out of reach.
          errorText: name.isEmpty ? null : problem,
        ),
        onSubmitted: save == null ? null : (_) => save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.what, required this.blockedBy});

  final String what;
  final List<String> blockedBy;

  @override
  Widget build(BuildContext context) {
    final blocked = blockedBy.isNotEmpty;
    return AlertDialog(
      scrollable: true,
      title: Text(blocked ? 'Cannot delete "$what"' : 'Delete "$what"?'),
      content: blocked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Remove it from these recipes first:'),
                const SizedBox(height: 8),
                for (final recipe in blockedBy) Text('• $recipe'),
              ],
            )
          : const Text('Nothing references it. This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(blocked ? 'Close' : 'Cancel'),
        ),
        if (!blocked)
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
      ],
    );
  }
}
