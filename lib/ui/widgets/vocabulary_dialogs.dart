/// The two dialogs vocabulary editing needs — the entry and the deletion —
/// shared by the ingredient and tag screens
/// (docs/ui-design.md#vocabulary-editing), and beside them the one reading of
/// the [ValidationIssue] path contract (ADR 05) every form puts under a field.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../palette.dart';
import 'tag_choices.dart';
import 'vocabulary_list.dart';

/// Show first issue or nothing if empty (untouched field not an error).
String? fieldError(String text, List<ValidationIssue> issues) =>
    text.isEmpty || issues.isEmpty ? null : issues.first.message;

/// The issues one field owns: [key] is the entry key leading to it, left out
/// for the name, whose issues carry no path at all.
List<ValidationIssue> issuesUnder(
  List<ValidationIssue> issues, [
  String? key,
]) => [
  for (final issue in issues)
    if (key == null
        ? issue.path.isEmpty
        : issue.path.isNotEmpty && issue.path.first == key)
      issue,
];

/// The message each field shows, keyed as [fieldOf] names it: the first issue
/// naming a field wins, since the rules are reported in the order they are
/// meant to be read. An issue [fieldOf] places nowhere is left out — its
/// caller has its own way of reporting one.
Map<K, String> firstIssuePerField<K extends Object>(
  List<ValidationIssue> issues,
  K? Function(ValidationIssue issue) fieldOf,
) {
  final problems = <K, String>{};
  for (final issue in issues) {
    final field = fieldOf(issue);
    if (field != null) problems.putIfAbsent(field, () => issue.message);
  }
  return problems;
}

/// What the entry dialog settles: the name, the spellings the entry also
/// answers to (ADR 10) and the tags it wears — either empty where the
/// vocabulary has none of them.
typedef VocabularyEntry = ({
  String name,
  List<String> aliases,
  List<String> tags,
});

/// Get a name and nothing else, or null if cancelled — the entry dialog with
/// every part only a vocabulary needs left out, so a bar is named the way an
/// ingredient is (`bars_screen.dart`). Blank is the one rule: bar names are
/// labels and two may be alike (FR-BAR-1).
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String hintText,
  String initial = '',
}) async => (await _prompt(
  context,
  title: title,
  hintText: hintText,
  validate: (entry) => [
    if (entry.name.trim().isEmpty)
      ValidationIssue(
        const [],
        ValidationIssueKind.emptyName,
        'A name of spaces is no name',
      ),
  ],
  initial: initial,
  aliases: null,
  color: null,
  vocabulary: const [],
  chosen: const [],
))?.entry.name.trim();

/// Get ingredient name, aliases and tags, or null if cancelled.
Future<VocabularyEntry?> promptForIngredient(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(VocabularyEntry entry) validate,
  required List<Tag> vocabulary,
  List<String> aliases = const [],
  List<String> chosen = const [],
  String initial = '',
}) async => (await _prompt(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  aliases: aliases.join(', '),
  color: null,
  vocabulary: vocabulary,
  chosen: chosen,
))?.entry;

/// Get tag name and color from single dialog, or null if cancelled.
Future<Tag?> promptForTag(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(VocabularyEntry entry) validate,
  required TagColor color,
  String initial = '',
}) async => switch (await _prompt(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  aliases: null,
  color: color,
  vocabulary: const [],
  chosen: const [],
)) {
  (entry: final entry, color: final TagColor color) => Tag(
    entry.name,
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

/// Ask before dropping edits; only what is being dropped differs, so the rest
/// of the wording is settled here.
Future<bool> confirmDiscard(BuildContext context, String title) =>
    confirmDialog(
      context,
      title: title,
      message: 'Your edits will be lost.',
      cancel: 'Keep editing',
      confirm: 'Discard',
    );

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

typedef _Answer = ({VocabularyEntry entry, TagColor? color});

Future<_Answer?> _prompt(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(VocabularyEntry entry) validate,
  required String initial,
  required String? aliases,
  required TagColor? color,
  required List<Tag> vocabulary,
  required List<String> chosen,
}) => showDialog<_Answer>(
  context: context,
  builder: (context) => _EntryDialog(
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
    aliases: aliases,
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
    required this.aliases,
    required this.color,
    required this.vocabulary,
    required this.chosen,
  });

  final String title;
  final String hintText;
  final List<ValidationIssue> Function(VocabularyEntry entry) validate;
  final String initial;

  /// The spellings already answered to, as the field reads them (null if this
  /// vocabulary has no aliases).
  final String? aliases;

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
  late final _aliases = TextEditingController(text: widget.aliases ?? '');
  late TagColor? _color = widget.color;
  late final Set<String> _tags = {...widget.chosen};

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _aliases.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  void _toggle(String tag) => setState(() => _tags.toggle(tag));

  /// What the one comma-separated field says (ADR 10) — trimmed, and without
  /// the blank a separator being typed leaves behind.
  List<String> get _aliasNames => [
    for (final spelling in _aliases.text.split(','))
      if (spelling.trim() case final trimmed when trimmed.isNotEmpty) trimmed,
  ];

  @override
  Widget build(BuildContext context) {
    final entry = (
      name: _name.text,
      aliases: _aliasNames,
      tags: [for (final tag in wornInOrder(widget.vocabulary, _tags)) tag.name],
    );
    final issues = widget.validate(entry);
    final save = entry.name.isEmpty || issues.isNotEmpty
        ? null
        : () => Navigator.of(context).pop((entry: entry, color: _color));
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
              errorText: fieldError(entry.name, issuesUnder(issues)),
            ),
            onSubmitted: save == null ? null : (_) => save(),
          ),
          // Closer than the sections below: both fields are what the entry is
          // called, not two things to settle.
          if (widget.aliases != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _aliases,
              decoration: InputDecoration(
                hintText: 'Also known as (comma-separated)',
                errorText: fieldError(
                  _aliases.text,
                  issuesUnder(issues, 'aliases'),
                ),
              ),
              onSubmitted: save == null ? null : (_) => save(),
            ),
          ],
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
