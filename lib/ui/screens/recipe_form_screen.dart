import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/editor_form.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/tag_choices.dart';
import '../widgets/vocabulary_list.dart';

/// One pushed page for creating and editing a recipe (FR-REC-1..5/8): the
/// name, the ingredient lines typed in the file's own grammar, the tag picker,
/// the notes. Pops the saved name once saved. Designed in
/// docs/ui-design.md#recipe-form.
///
/// Owned bars only: a guest offers neither the add button nor the Edit that
/// reach here, which is what lets the Save take the writer as non-null
/// (FR-BAR-4).
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

  /// The vocabulary a line is written against comes from the collection, so the
  /// fields open in the spelling the file holds (ADR 09).
  late final _lines = GrowingRows<TextEditingController>(
    blankRow: _lineController,
    isBlank: (line) => line.isBlank,
    disposeRow: (line) => line.dispose(),
    initial: [
      for (final line in widget.original?.lines ?? const <RecipeLine>[])
        _lineController(formatRecipeLine(line, widget.units)),
    ],
  );

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
    _lines.dispose();
    super.dispose();
  }

  TextEditingController _lineController([String text = '']) {
    final controller = TextEditingController(text: text);
    controller.addListener(() => _lineEdited(controller));
    return controller;
  }

  /// An edited line drops the problem its last save left under it, and the
  /// list settles around it (docs/ui-design.md#recipe-form).
  void _lineEdited(TextEditingController controller) => setState(() {
    _saveProblems.remove(_lines.rows.indexOf(controller));
    _lines.settle();
  });

  /// Whether anything changed since opening; asks on back if dirty.
  bool get _dirty {
    final original = widget.original;
    return _name.text != (original?.name ?? widget.initialName) ||
        _notes.text != (original?.notes ?? '') ||
        !setEquals(_tags, {...?original?.tags}) ||
        !listEquals(
          [for (final line in _lines.entered) line.text],
          [
            for (final line in original?.lines ?? const <RecipeLine>[])
              formatRecipeLine(line, widget.units),
          ],
        );
  }

  /// Names to avoid on rename (excluding current name).
  Set<String> _otherNames(Collection collection) =>
      otherNames(collection.recipeNames, widget.original?.name);

  /// Name alone — kept apart by the empty path a name issue carries, so what
  /// the half-typed rest of the form is still missing waits for Save.
  List<ValidationIssue> _nameIssues(Collection collection) => issuesUnder(
    validateRecipe(
      Recipe(_name.text),
      knownIngredients: const {},
      knownTags: const {},
      knownUnits: const {},
      otherRecipeNames: _otherNames(collection),
    ),
  );

  /// Parse result per line (null if empty/valid); computed once per build.
  List<String?> get _syntaxProblems => [
    for (final line in _lines.rows)
      if (line.isBlank)
        null
      else
        tryParseRecipeLine(line.text, widget.units).problem,
  ];

  /// Parsed recipe and fieldOf map for aligning issues with fields. Lines are
  /// kept as typed: "gin" against "Gin" and an alias against the bottle it
  /// names both settle on the way to the collection (ADR 08, ADR 10), so the
  /// form judges what it sees and stores what the vocabulary calls it.
  ({Recipe recipe, List<int> fieldOf}) _entered(List<Tag> vocabulary) {
    final lines = <RecipeLine>[];
    final fieldOf = <int>[];
    for (var field = 0; field < _lines.rows.length; field++) {
      final line = _lines.rows[field];
      if (line.isBlank) continue;
      lines.add(parseRecipeLine(line.text, widget.units));
      fieldOf.add(field);
    }
    return (
      recipe: Recipe(
        _name.text,
        tags: [for (final tag in wornInOrder(vocabulary, _tags)) tag.name],
        lines: lines,
        notes: _notes.text.trim(),
      ),
      fieldOf: fieldOf,
    );
  }

  Future<void> _save(Collection collection, List<Tag> vocabulary) async {
    final entered = _entered(vocabulary);
    final issues = validateRecipe(
      entered.recipe,
      knownIngredients: collection.ingredientSpellings(),
      knownTags: collection.tagNames(TagKind.recipe),
      knownUnits: collection.unitSpellings,
      otherRecipeNames: _otherNames(collection),
    );
    final blocked = issues.any(
      (issue) => issue.kind != ValidationIssueKind.unknownIngredient,
    );
    if (blocked) return _reportProblems(issues, entered.fieldOf);
    if (issues.isEmpty) return _commit(entered.recipe, const []);
    final missing = _missing(collection, entered.recipe);
    if (!await _offerToAdd(missing)) {
      if (mounted) _reportProblems(issues, entered.fieldOf);
      return;
    }
    if (!mounted) return;
    await _commit(entered.recipe, [
      for (final name in missing) Ingredient(name),
    ]);
  }

  /// Names no bottle answers to, in line order (deduplicated). Asked of the
  /// vocabulary rather than read back out of the issues: a line may name
  /// several bottles (ADR 11) and its issues all share one path, so which of
  /// them is missing is a question about the collection, not about the report.
  static List<String> _missing(Collection collection, Recipe recipe) => {
    for (final line in recipe.lines)
      for (final ingredient in line.ingredients)
        if (collection.ingredientNamed(ingredient) == null) ingredient,
  }.toList();

  /// Line issues under their field; unplaceable issues in snackbar.
  void _reportProblems(List<ValidationIssue> issues, List<int> fieldOf) {
    setState(() {
      _saveProblems
        ..clear()
        ..addAll(
          firstIssuePerField(issues, (issue) => _fieldOf(issue, fieldOf)),
        );
    });
    final unplaceable = [
      for (final issue in issues)
        if (_fieldOf(issue, fieldOf) == null) issue,
    ];
    if (unplaceable.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(unplaceable.first.message)));
    }
  }

  /// The line field [issue] belongs under, or null where it names the recipe
  /// as a whole and only the snackbar can carry it.
  static int? _fieldOf(ValidationIssue issue, List<int> fieldOf) =>
      switch (issue.path) {
        ['lines', final int line] => fieldOf[line],
        _ => null,
      };

  Future<bool> _offerToAdd(List<String> names) => confirmDialog(
    context,
    title: 'Add missing ingredients?',
    message: 'These are not in the ingredients yet:',
    bullets: names,
    footer: 'Saving adds them, out of stock.',
    cancel: 'Cancel',
    confirm: 'Add and save',
  );

  /// Atomic edit: new bottles + recipe + handling old name.
  Future<void> _commit(Recipe recipe, List<Ingredient> adding) async {
    await ref
        .read(barWriterProvider)!
        .upsertRecipe(
          recipe,
          addingIngredients: adding,
          replacing: widget.original?.name,
        );
    if (mounted) Navigator.of(context).pop(recipe.name);
  }

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    final vocabulary = sortedByName(collection.recipeTags);
    final original = widget.original;
    final nameIssues = _nameIssues(collection);
    final syntax = _syntaxProblems;
    final canSave =
        nameIssues.isEmpty && syntax.every((problem) => problem == null);
    return EditorScaffold(
      title: original == null ? 'New recipe' : 'Edit "${original.name}"',
      dirty: _dirty,
      discardTitle: 'Discard this recipe?',
      onSave: canSave ? () => unawaited(_save(collection, vocabulary)) : null,
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
        for (var field = 0; field < _lines.rows.length; field++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _lines.rows[field],
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
    );
  }
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
