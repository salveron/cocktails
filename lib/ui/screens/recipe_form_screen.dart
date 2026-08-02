import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/vocabulary_dialogs.dart';
import '../widgets/model_view.dart';
import '../widgets/tag_choices.dart';
import '../widgets/vocabulary_list.dart';

/// One pushed page for creating and editing a recipe (FR-REC-1..5/8): the
/// name, the ingredient lines typed in the file's own grammar, the tag picker,
/// the notes. Pops the saved name once saved. Designed in
/// docs/ui-design.md#recipe-form.
class RecipeFormScreen extends ConsumerStatefulWidget {
  const RecipeFormScreen({
    required this.units,
    this.original,
    this.initialName = '',
    super.key,
  });

  /// What a line may be measured in (ADR 09) — handed over rather than read,
  /// since the fields are filled before the first build.
  final List<Unit> units;

  /// The recipe being edited, or null when creating one.
  final Recipe? original;

  /// What the name field opens on — the query where a search found nothing.
  final String initialName;

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  late final _name = TextEditingController(
    text: widget.original?.name ?? widget.initialName,
  );
  late final _notes = TextEditingController(text: widget.original?.notes ?? '');

  /// Bottom line always empty to grow the list; emptied lines dropped on save.
  /// The vocabulary a line is written against comes from the model, so the
  /// fields open in the spelling the file holds (ADR 09).
  late final _lines = [
    for (final line in widget.original?.lines ?? const <RecipeLine>[])
      _lineController(formatRecipeLine(line, widget.units)),
    _lineController(''),
  ];

  /// Controllers of fields the list has taken back. Their `TextField` outlives
  /// them by a build, so disposing one where it is dropped would be a
  /// use-after-dispose; the form disposes them all when it closes.
  final _dropped = <TextEditingController>[];

  late final _tags = {...?widget.original?.tags};

  /// Save-time validation issues by field; cleared when field is edited.
  final _saveProblems = <int, String>{};

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    for (final line in [..._lines, ..._dropped]) {
      line.dispose();
    }
    super.dispose();
  }

  TextEditingController _lineController(String text) {
    final controller = TextEditingController(text: text);
    controller.addListener(() => _lineEdited(controller));
    return controller;
  }

  /// Grows a field below the last one typed into, and takes the spare back
  /// when that line is erased again — one field stands empty, never two, and
  /// never the one the cursor is in (docs/ui-design.md#recipe-form).
  void _lineEdited(TextEditingController controller) => setState(() {
    _saveProblems.remove(_lines.indexOf(controller));
    if (!_blank(_lines.last)) {
      _lines.add(_lineController(''));
    } else if (_lines.length > 1 && _blank(_lines[_lines.length - 2])) {
      _dropped.add(_lines.removeLast());
    }
  });

  /// Whether anything changed since opening; asks on back if dirty.
  bool get _dirty {
    final original = widget.original;
    return _name.text != (original?.name ?? widget.initialName) ||
        _notes.text != (original?.notes ?? '') ||
        !setEquals(_tags, {...?original?.tags}) ||
        !listEquals(
          [
            for (final line in _lines)
              if (!_blank(line)) line.text,
          ],
          [
            for (final line in original?.lines ?? const <RecipeLine>[])
              formatRecipeLine(line, widget.units),
          ],
        );
  }

  /// Names to avoid on rename (excluding current name).
  Set<String> _otherNames(Model model) =>
      otherNames(model.recipeNames, widget.original?.name);

  /// Name alone — kept apart by the empty path a name issue carries, so what
  /// the half-typed rest of the form is still missing waits for Save.
  List<ValidationIssue> _nameIssues(Model model) => [
    for (final issue in validateRecipe(
      Recipe(_name.text),
      knownIngredients: const {},
      knownTags: const {},
      knownUnits: const {},
      otherRecipeNames: _otherNames(model),
    ))
      if (issue.path.isEmpty) issue,
  ];

  /// Parse result per line (null if empty/valid); computed once per build.
  List<String?> get _syntaxProblems => [
    for (final line in _lines)
      if (_blank(line))
        null
      else
        tryParseRecipeLine(line.text, widget.units).problem,
  ];

  /// Parsed recipe and fieldOf map for aligning issues with fields. Lines are
  /// kept as typed: "gin" against "Gin" and an alias against the bottle it
  /// names both settle on the way to the model (ADR 08, ADR 10), so the form
  /// judges what it sees and stores what the vocabulary calls it.
  ({Recipe recipe, List<int> fieldOf}) _entered(List<Tag> vocabulary) {
    final lines = <RecipeLine>[];
    final fieldOf = <int>[];
    for (var field = 0; field < _lines.length; field++) {
      if (_blank(_lines[field])) continue;
      lines.add(parseRecipeLine(_lines[field].text, widget.units));
      fieldOf.add(field);
    }
    return (
      recipe: Recipe(
        _name.text,
        tags: [for (final tag in wornInOrder(vocabulary, _tags)) tag.name],
        lines: lines,
        notes: _notes.text.trim(),
        made: widget.original?.made,
      ),
      fieldOf: fieldOf,
    );
  }

  Future<void> _save(Model model, List<Tag> vocabulary) async {
    final entered = _entered(vocabulary);
    final issues = validateRecipe(
      entered.recipe,
      knownIngredients: model.ingredientSpellings(),
      knownTags: model.tagNames(TagKind.recipe),
      knownUnits: model.unitSpellings,
      otherRecipeNames: _otherNames(model),
    );
    final blocked = issues.any(
      (issue) => issue.kind != ValidationIssueKind.unknownIngredient,
    );
    if (blocked) return _reportProblems(issues, entered.fieldOf);
    if (issues.isEmpty) return _commit(entered.recipe, const []);
    final missing = _missing(entered.recipe, issues);
    if (!await _offerToAdd(missing)) {
      if (mounted) _reportProblems(issues, entered.fieldOf);
      return;
    }
    if (!mounted) return;
    await _commit(entered.recipe, [
      for (final name in missing) Ingredient(name),
    ]);
  }

  /// Unknown ingredient names in line order (deduplicated).
  List<String> _missing(Recipe recipe, List<ValidationIssue> issues) => {
    for (final issue in issues)
      if (issue.path case ['lines', final int line])
        recipe.lines[line].ingredient,
  }.toList();

  /// Line issues under their field; unplaceable issues in snackbar.
  void _reportProblems(List<ValidationIssue> issues, List<int> fieldOf) {
    setState(() {
      _saveProblems.clear();
      // Reversed: keep first issue per field (validation order).
      for (final issue in issues.reversed) {
        if (issue.path case ['lines', final int line]) {
          _saveProblems[fieldOf[line]] = issue.message;
        }
      }
    });
    final unplaceable = issues.where((issue) => !_isLineIssue(issue)).toList();
    if (unplaceable.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unplaceable.first.message)));
    }
  }

  static bool _isLineIssue(ValidationIssue issue) => switch (issue.path) {
    ['lines', int()] => true,
    _ => false,
  };

  Future<bool> _offerToAdd(List<String> names) => confirmDialog(
    context,
    title: 'Add missing ingredients?',
    message: 'These are not in your ingredients yet:',
    bullets: names,
    footer: 'Saving adds them, out of stock.',
    cancel: 'Cancel',
    confirm: 'Add and save',
  );

  /// Atomic edit: new bottles + recipe + handling old name.
  Future<void> _commit(Recipe recipe, List<Ingredient> adding) async {
    await ref
        .read(modelProvider.notifier)
        .upsertRecipe(
          recipe,
          addingIngredients: adding,
          replacing: widget.original?.name,
        );
    if (mounted) Navigator.of(context).pop(recipe.name);
  }

  Future<void> _confirmDiscard() async {
    final discard = await confirmDialog(
      context,
      title: 'Discard this recipe?',
      message: 'Your edits will be lost.',
      cancel: 'Keep editing',
      confirm: 'Discard',
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ModelView((model) {
    final vocabulary = sortedByName(model.recipeTags);
    final original = widget.original;
    final nameIssues = _nameIssues(model);
    final syntax = _syntaxProblems;
    final canSave =
        nameIssues.isEmpty && syntax.every((problem) => problem == null);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            original == null ? 'New recipe' : 'Edit "${original.name}"',
          ),
          actions: [
            TextButton(
              onPressed: canSave
                  ? () => unawaited(_save(model, vocabulary))
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              autofocus: original == null,
              decoration: InputDecoration(
                hintText: 'Recipe name',
                errorText: fieldError(_name.text, nameIssues),
              ),
            ),
            const _SectionLabel('Ingredients'),
            for (var field = 0; field < _lines.length; field++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _lines[field],
                  decoration: InputDecoration(
                    hintText: '1.5 parts gin (base)',
                    errorText: syntax[field] ?? _saveProblems[field],
                  ),
                ),
              ),
            if (vocabulary.isNotEmpty) ...[
              const _SectionLabel('Tags'),
              TagChoices(
                vocabulary: vocabulary,
                chosen: _tags,
                onToggle: (tag) => setState(() => _tags.toggle(tag)),
              ),
            ],
            const _SectionLabel('Notes'),
            TextField(
              controller: _notes,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'Preparation, glassware, garnish…',
              ),
            ),
          ],
        ),
      ),
    );
  });
}

bool _blank(TextEditingController field) => field.text.trim().isEmpty;

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
