/// The entry dialog every vocabulary edits through — name, aliases, colour,
/// tags — each part left out where its vocabulary carries none
/// (docs/ui-design.md#vocabulary-editing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import '../../palette.dart';
import '../../toggling.dart';
import '../chips/tag_choices.dart';
import '../forms/field_issues.dart';
import 'dialog_frame.dart';

/// What the entry dialog settles: the name, the spellings the entry also
/// answers to (ADR 10) and the tags it wears — either empty where the
/// vocabulary has none of them.
typedef VocabularyEntry = ({
  String name,
  List<String> aliases,
  List<String> tags,
});

/// Get ingredient name, aliases and tags, or null if cancelled.
Future<VocabularyEntry?> promptForIngredient(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(VocabularyEntry entry) validate,
  required List<Tag> tags,
  List<String> aliases = const [],
  List<String> chosen = const [],
  String initial = '',
}) async => (await promptEntry(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  aliases: aliases.join(', '),
  color: null,
  tags: tags,
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
}) async => switch (await promptEntry(
  context,
  title: title,
  hintText: hintText,
  validate: validate,
  initial: initial,
  aliases: null,
  color: color,
  tags: const [],
  chosen: const [],
)) {
  (entry: final entry, color: final TagColor color) => Tag(
    entry.name,
    color: color,
  ),
  _ => null,
};

/// Get a name and nothing else, or null if cancelled — the entry dialog with
/// every part only a vocabulary needs left out, so a bar is named the way an
/// ingredient is (`bars_screen.dart`). Blank is the one rule: bar names are
/// labels and two may be alike (FR-BAR-1).
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String hintText,
  String initial = '',
}) async => (await promptEntry(
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
  tags: const [],
  chosen: const [],
))?.entry.name.trim();

/// The dialog every vocabulary entry is settled through, [promptForName]
/// among them — every part only a vocabulary needs left out, so a bar is
/// named the way an ingredient is.
Future<({VocabularyEntry entry, TagColor? color})?> promptEntry(
  BuildContext context, {
  required String title,
  required String hintText,
  required List<ValidationIssue> Function(VocabularyEntry entry) validate,
  required String initial,
  required String? aliases,
  required TagColor? color,
  required List<Tag> tags,
  required List<String> chosen,
}) => showDialog(
  context: context,
  builder: (context) => _EntryDialog(
    title: title,
    hintText: hintText,
    validate: validate,
    initial: initial,
    aliases: aliases,
    color: color,
    tags: tags,
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
    required this.tags,
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
  final List<Tag> tags;
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
      tags: [for (final tag in wornInOrder(widget.tags, _tags)) tag.name],
    );
    final issues = widget.validate(entry);
    final save = entry.name.isEmpty || issues.isNotEmpty
        ? null
        : () => Navigator.of(context).pop((entry: entry, color: _color));
    return DialogFrame(
      title: widget.title,
      // Full width so swatches/chips left-align with field.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      content: [
        _ContentFields(
          nameController: _name,
          hintText: widget.hintText,
          entry: entry,
          issues: issues,
          save: save,
          aliasesController: widget.aliases == null ? null : _aliases,
          color: _color,
          onPickColor: (picked) => setState(() => _color = picked),
          tags: widget.tags,
          chosenTags: _tags,
          onToggleTag: _toggle,
        ),
      ],
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

/// The fields the dialog offers over [entry] — the name always, the rest where
/// this vocabulary carries them.
class _ContentFields extends StatelessWidget {
  const _ContentFields({
    required this.nameController,
    required this.hintText,
    required this.entry,
    required this.issues,
    required this.save,
    required this.aliasesController,
    required this.color,
    required this.onPickColor,
    required this.tags,
    required this.chosenTags,
    required this.onToggleTag,
  });

  final TextEditingController nameController;
  final String hintText;
  final VocabularyEntry entry;
  final List<ValidationIssue> issues;
  final VoidCallback? save;

  /// The spellings field's own controller, null where this vocabulary carries
  /// no aliases.
  final TextEditingController? aliasesController;

  final TagColor? color;
  final void Function(TagColor color) onPickColor;
  final List<Tag> tags;
  final Set<String> chosenTags;
  final void Function(String tag) onToggleTag;

  @override
  Widget build(BuildContext context) {
    final save = this.save;
    final aliasesController = this.aliasesController;
    final color = this.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: fieldError(entry.name, issuesUnder(issues)),
          ),
          onSubmitted: save == null ? null : (_) => save(),
        ),
        // Closer than the sections below: both fields are what the entry is
        // called, not two things to settle.
        if (aliasesController != null) ...[
          const SizedBox(height: 8),
          TextField(
            controller: aliasesController,
            decoration: InputDecoration(
              hintText: 'Also known as (comma-separated)',
              errorText: fieldError(
                aliasesController.text,
                issuesUnder(issues, 'aliases'),
              ),
            ),
            onSubmitted: save == null ? null : (_) => save(),
          ),
        ],
        if (color != null) ...[
          const SizedBox(height: 20),
          _Swatches(selected: color, onPick: onPickColor),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          TagChoices(tags: tags, chosen: chosenTags, onToggle: onToggleTag),
        ],
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
              child: _Swatch(
                swatch: tagColors(color, brightness),
                chosen: color == selected,
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.swatch, required this.chosen});

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
