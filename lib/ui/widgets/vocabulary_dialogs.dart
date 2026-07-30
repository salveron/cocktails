/// The two dialogs vocabulary editing needs — the entry and the deletion —
/// shared by the ingredient and tag screens
/// (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';
import 'tag_choices.dart';
import 'vocabulary_list.dart';

/// What a validated field shows under itself: the first issue's message, or
/// nothing at all while the field is still empty — an untouched field is not a
/// mistake yet, it only keeps Save out of reach. The recipe form applies the
/// same rule, from here, so the two cannot drift apart.
String? fieldError(String text, List<ValidationIssue> issues) =>
    text.isEmpty || issues.isEmpty ? null : issues.first.message;

/// Asks for an ingredient's name and the tags it wears, or null when the user
/// backs out. [validate] is the vocabulary's own rule set, so this dialog holds
/// no name rules and cannot drift from the ones the codec applies. [vocabulary]
/// is every ingredient tag on offer — empty leaves the field alone in the
/// dialog — and [chosen] the ones already worn (FR-INV-3).
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

/// The same dialog with the palette under the field, so a tag's name and its
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
  vocabulary: const [],
  chosen: const [],
)) {
  (name: final String name, color: final TagColor color, tags: _) => Tag(
    name,
    color: color,
  ),
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

  /// The colour to open on, or null for a vocabulary that wears none.
  final TagColor? color;

  /// The tags on offer, and the ones already worn. Empty for a vocabulary
  /// whose entries carry none.
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
        // Every section runs the field's full width, so the swatches and the
        // chips start where the field starts instead of floating in the middle.
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
