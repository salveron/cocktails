/// The two dialogs vocabulary editing needs — name entry and deletion — shared
/// by the ingredient and tag screens (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Asks for a vocabulary name and answers with it, or null when the user backs
/// out. [validate] is that vocabulary's own rule set, so this dialog holds no
/// name rules and cannot drift from the ones the codec applies.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  String initial = '',
}) async => (await _prompt(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  color: null,
))?.$1;

/// [promptForName] with the palette under the field, so a tag's name and its
/// colour are settled in one place (FR-VOC-3). [color] is what the swatch row
/// opens on: the colour the tag already wears, or the one a new tag is offered.
Future<Tag?> promptForTag(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  required TagColor color,
  String initial = '',
}) async => switch (await _prompt(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  color: color,
)) {
  (final String name, final TagColor color) => Tag(name, color: color),
  _ => null,
};

/// Asks whether to delete [what]; true only when a free entry was confirmed.
/// [blockedBy] names the entries referencing it, [blockedByNoun] what they are
/// — a non-empty list turns the question into a refusal naming them, which is
/// where FR-VOC-1's blocking rule meets the user.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  required List<String> blockedBy,
  required String blockedByNoun,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(
        what: what,
        blockedBy: blockedBy,
        blockedByNoun: blockedByNoun,
      ),
    ) ??
    false;

Future<(String name, TagColor? color)?> _prompt(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  required String initial,
  required TagColor? color,
}) => showDialog<(String, TagColor?)>(
  context: context,
  builder: (context) => _EntryDialog(
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
    color: color,
  ),
);

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({
    required this.title,
    required this.hintText,
    required this.validate,
    required this.initial,
    required this.color,
  });

  final String title;
  final String hintText;
  final List<ValidationIssue> Function(String name) validate;
  final String initial;

  /// The colour to open on, or null for a vocabulary that wears none.
  final TagColor? color;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final _name = TextEditingController(text: widget.initial);
  late TagColor? _color = widget.color;

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
        : () => Navigator.of(context).pop((name, _color));
    final color = _color;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
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
          if (color != null) ...[
            const SizedBox(height: 20),
            _Swatches(
              selected: color,
              onPick: (picked) => setState(() => _color = picked),
            ),
          ],
        ],
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

/// The whole palette at once — six is few enough that a grid or a submenu would
/// only put a step between the tag and its colour. The check is drawn in the
/// swatch's own ink, so the picker shows the contrast it is choosing.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onPick});

  final TagColor selected;
  final void Function(TagColor color) onPick;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in TagColor.values)
          Tooltip(
            message: color.token,
            child: InkWell(
              onTap: () => onPick(color),
              customBorder: const CircleBorder(),
              child: _Dot(
                swatch: tagColors(color, brightness),
                chosen: color == selected,
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.swatch, required this.chosen});

  final Swatch swatch;
  final bool chosen;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: swatch.fill, shape: BoxShape.circle),
    child: chosen ? Icon(Icons.check, size: 20, color: swatch.ink) : null,
  );
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.what,
    required this.blockedBy,
    required this.blockedByNoun,
  });

  final String what;
  final List<String> blockedBy;
  final String blockedByNoun;

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
                Text('Remove it from these $blockedByNoun first:'),
                const SizedBox(height: 8),
                for (final entry in blockedBy) Text('• $entry'),
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
