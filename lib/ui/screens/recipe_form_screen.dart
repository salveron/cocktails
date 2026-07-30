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
  const RecipeFormScreen({this.original, this.initialName = '', super.key});

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

  /// One controller per line field, the bottom one always empty so the list
  /// grows under the typing; a field emptied out is dropped on save.
  late final _lines = [
    for (final line in widget.original?.lines ?? const <RecipeLine>[])
      _lineController(formatRecipeLine(line)),
    _lineController(''),
  ];

  late final _tags = {...?widget.original?.tags};

  /// What only the save could see — a zero amount, an unknown ingredient after
  /// a declined offer — by field index; editing a field clears its own.
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
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  TextEditingController _lineController(String text) {
    final controller = TextEditingController(text: text);
    controller.addListener(() => _lineEdited(controller));
    return controller;
  }

  void _lineEdited(TextEditingController controller) => setState(() {
    _saveProblems.remove(_lines.indexOf(controller));
    if (_lines.last.text.trim().isNotEmpty) {
      _lines.add(_lineController(''));
    }
  });

  /// Whether anything differs from what the form opened on — what decides if
  /// backing out needs to ask.
  bool get _dirty {
    final original = widget.original;
    return _name.text != (original?.name ?? widget.initialName) ||
        _notes.text != (original?.notes ?? '') ||
        !setEquals(_tags, {...?original?.tags}) ||
        !listEquals(
          [
            for (final line in _lines)
              if (line.text.trim().isNotEmpty) line.text,
          ],
          [
            for (final line in original?.lines ?? const <RecipeLine>[])
              formatRecipeLine(line),
          ],
        );
  }

  /// Every name a rename must not collide with — the recipe being edited left
  /// out, so keeping its own name is not a duplicate.
  Set<String> _otherNames(Model model) => {
    for (final recipe in model.recipes)
      if (recipe.name != widget.original?.name) recipe.name,
  };

  /// The name judged alone, on the rules the save will apply — the reference
  /// sets are empty because a name can misuse neither.
  List<ValidationIssue> _nameIssues(Model model) => validateRecipe(
    Recipe(_name.text),
    knownIngredients: const {},
    knownTags: const {},
    otherRecipeNames: _otherNames(model),
  );

  /// What syntax makes of each field, in field order — null where a field is
  /// empty or parses. Computed once per build and read by both the fields and
  /// the Save button, so a keystroke parses the lines one time.
  List<String?> get _syntaxProblems => [
    for (final line in _lines)
      if (line.text.trim().isEmpty)
        null
      else
        tryParseRecipeLine(line.text).problem,
  ];

  /// What the fields come to, plus which field each recipe line came from —
  /// the map that lands a `lines[i]` issue under the right field when empty
  /// fields sit in between.
  ({Recipe recipe, List<int> fieldOf}) _entered(List<Tag> vocabulary) {
    final lines = <RecipeLine>[];
    final fieldOf = <int>[];
    for (var field = 0; field < _lines.length; field++) {
      final text = _lines[field].text;
      if (text.trim().isEmpty) continue;
      lines.add(parseRecipeLine(text));
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
      knownIngredients: {
        for (final ingredient in model.ingredients) ingredient.name,
      },
      knownTags: {for (final tag in model.recipeTags) tag.name},
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

  /// The unknown names in line order, each once however many lines want it.
  List<String> _missing(Recipe recipe, List<ValidationIssue> issues) => {
    for (final issue in issues)
      if (issue.path case ['lines', final int line])
        recipe.lines[line].ingredient,
  }.toList();

  /// A line issue goes under its own field; anything no field can carry is
  /// said out loud instead, because a refused save that shows nothing is a
  /// Save button that looks broken.
  void _reportProblems(List<ValidationIssue> issues, List<int> fieldOf) {
    setState(() {
      _saveProblems.clear();
      // Reversed so a line collecting several issues keeps the first — the
      // order the validation reports them in.
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

  Future<bool> _offerToAdd(List<String> names) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Add missing ingredients?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('These are not in your ingredients yet:'),
              const SizedBox(height: 8),
              for (final name in names) Text('• $name'),
              const SizedBox(height: 8),
              const Text('Saving adds them, out of stock.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add and save'),
            ),
          ],
        ),
      ) ??
      false;

  /// One edit for the whole entry — the bottles it introduced, the name a
  /// rename leaves behind, the recipe itself.
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
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this recipe?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ModelView((model) {
    final vocabulary = [...model.recipeTags]
      ..sort((a, b) => byName(a.name, b.name));
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
                    hintText: '1.5 part gin (base)',
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
              minLines: 3,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}
