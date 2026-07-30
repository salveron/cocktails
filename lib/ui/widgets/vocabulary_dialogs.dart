/// The two dialogs vocabulary editing needs — the entry and the deletion —
/// shared by the ingredient and tag screens
/// (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';
import 'tag_choices.dart';
import 'vocabulary_list.dart';

/// Show first issue or nothing if empty (untouched field not an error).
String? fieldError(String text, List<ValidationIssue> issues) =>
    text.isEmpty || issues.isEmpty ? null : issues.first.message;

/// [names] without [except], which is what every `validate…` call wants: the
/// names an entry must not collide with, its own left out so a rename never
/// collides with the name it is leaving.
Set<String> otherNames(Set<String> names, String? except) => {
  for (final name in names)
    if (name != except) name,
};

/// Get ingredient name and tags, or null if cancelled.
Future<({String name, List<String> tags})?> promptForIngredient(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  required List<Tag> vocabulary,
  List<String> chosen = const [],
  String initial = '',
}) async {
  final answer = await _prompt(
    context,
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
    color: null,
    vocabulary: vocabulary,
    chosen: chosen,
  );
  return answer == null ? null : (name: answer.name, tags: answer.tags);
}

/// Get tag name and color from single dialog, or null if cancelled.
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
  vocabulary: const [],
  chosen: const [],
)) {
  (name: final String name, color: final TagColor color, tags: _) => Tag(
    name,
    color: color,
  ),
  _ => null,
};

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
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (bullets.isNotEmpty) const SizedBox(height: 8),
            for (final entry in bullets) Text('• $entry'),
            if (footer != null) ...[const SizedBox(height: 8), Text(footer)],
          ],
        ),
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

/// Ask to delete; true only if free and confirmed. A blocked entry names what
/// stands in the way and offers nothing to confirm, so it answers false.
Future<bool> confirmDelete(
  BuildContext context, {
  required String what,
  required List<String> blockedBy,
  required String blockedByNoun,
}) => blockedBy.isEmpty
    ? confirmDialog(
        context,
        title: 'Delete "$what"?',
        message: 'Nothing references it. This cannot be undone.',
        cancel: 'Cancel',
        confirm: 'Delete',
      )
    : confirmDialog(
        context,
        title: 'Cannot delete "$what"',
        message: 'Remove it from these $blockedByNoun first:',
        bullets: blockedBy,
        cancel: 'Close',
      );

typedef _Entry = ({String name, TagColor? color, List<String> tags});

Future<_Entry?> _prompt(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(String name) validate,
  required String initial,
  required TagColor? color,
  required List<Tag> vocabulary,
  required List<String> chosen,
}) => showDialog<_Entry>(
  context: context,
  builder: (context) => _EntryDialog(
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
    color: color,
    vocabulary: vocabulary,
    chosen: chosen,
  ),
);

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({
    required this.title,
    required this.hintText,
    required this.validate,
    required this.initial,
    required this.color,
    required this.vocabulary,
    required this.chosen,
  });

  final String title;
  final String hintText;
  final List<ValidationIssue> Function(String name) validate;
  final String initial;

  /// Opening color (null if no color for this vocabulary).
  final TagColor? color;

  /// Tags on offer and already worn (empty if vocabulary carries none).
  final List<Tag> vocabulary;
  final List<String> chosen;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final _name = TextEditingController(text: widget.initial);
  late TagColor? _color = widget.color;
  late final Set<String> _tags = {...widget.chosen};

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

  void _toggle(String tag) => setState(() => _tags.toggle(tag));

  @override
  Widget build(BuildContext context) {
    final name = _name.text;
    final issues = widget.validate(name);
    final save = name.isEmpty || issues.isNotEmpty
        ? null
        : () => Navigator.of(context).pop((
            name: name,
            color: _color,
            tags: [
              for (final tag in wornInOrder(widget.vocabulary, _tags)) tag.name,
            ],
          ));
    final color = _color;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        // Full width so swatches/chips left-align with field.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: fieldError(name, issues),
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
          if (widget.vocabulary.isNotEmpty) ...[
            const SizedBox(height: 20),
            TagChoices(
              vocabulary: widget.vocabulary,
              chosen: _tags,
              onToggle: _toggle,
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

/// All colors at once (six fit on screen); checkmark uses swatch's own ink.
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
