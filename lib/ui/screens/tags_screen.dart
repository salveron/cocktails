import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';

/// Both tag vocabularies, a tab each — add, rename with propagation, colour,
/// and reference-blocked delete (FR-VOC-1/3/4). Designed in
/// docs/ui-design.md#tags-screen.
class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: _Vocabulary.values.length,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        bottom: TabBar(
          tabs: [
            for (final vocabulary in _Vocabulary.values)
              Tab(text: vocabulary.tab),
          ],
        ),
      ),
      body: ModelView(
        (model) => TabBarView(
          children: [
            for (final vocabulary in _Vocabulary.values)
              _TagTab(vocabulary, model),
          ],
        ),
      ),
    ),
  );
}

/// Everything that tells the two vocabularies apart: what they are called, what
/// blocks a delete, and which of the controller's per-vocabulary mutations they
/// call. The list, the dialogs and the row are the same on both sides
/// (FR-VOC-4). Each `switch` is exhaustive, so a third vocabulary would have to
/// answer here before it compiled.
enum _Vocabulary {
  recipe(
    tab: 'Recipe',
    noun: 'recipe tag',
    plural: 'recipe tags',
    hint: 'Recipe tag name',
    blockedByNoun: 'recipes',
    blurb:
        'A tag groups recipes that belong together — sour, classic, tiki '
        '— and wears a colour of its own.',
  ),
  ingredient(
    tab: 'Ingredient',
    noun: 'ingredient tag',
    plural: 'ingredient tags',
    hint: 'Ingredient tag name',
    blockedByNoun: 'ingredients',
    blurb:
        'A tag groups bottles that belong together — citrus, syrup, '
        'homemade — and wears a colour of its own.',
  );

  const _Vocabulary({
    required this.tab,
    required this.noun,
    required this.plural,
    required this.hint,
    required this.blockedByNoun,
    required this.blurb,
  });

  final String tab;
  final String noun;
  final String plural;
  final String hint;
  final String blockedByNoun;
  final String blurb;

  List<Tag> tagsIn(Model model) => switch (this) {
    _Vocabulary.recipe => model.recipeTags,
    _Vocabulary.ingredient => model.ingredientTags,
  };

  List<String> usersOf(Model model, String name) => switch (this) {
    _Vocabulary.recipe => model.recipesUsingTag(name),
    _Vocabulary.ingredient => model.ingredientsUsingTag(name),
  };

  Future<void> upsert(ModelController controller, Tag tag) => switch (this) {
    _Vocabulary.recipe => controller.upsertRecipeTag(tag),
    _Vocabulary.ingredient => controller.upsertIngredientTag(tag),
  };

  Future<void> rename(ModelController controller, String from, String to) =>
      switch (this) {
        _Vocabulary.recipe => controller.renameRecipeTag(from, to),
        _Vocabulary.ingredient => controller.renameIngredientTag(from, to),
      };

  Future<void> remove(ModelController controller, String name) =>
      switch (this) {
        _Vocabulary.recipe => controller.removeRecipeTag(name),
        _Vocabulary.ingredient => controller.removeIngredientTag(name),
      };
}

class _TagTab extends ConsumerWidget {
  const _TagTab(this.vocabulary, this.model);

  final _Vocabulary vocabulary;
  final Model model;

  @override
  Widget build(BuildContext context, WidgetRef ref) => VocabularyList<Tag>(
    entries: vocabulary.tagsIn(model),
    nameOf: (tag) => tag.name,
    rowOf: (tag) => VocabularyRow(
      // A ListTile stretches its title, and a stretched chip is a band.
      title: Align(alignment: Alignment.centerLeft, child: TagChip(tag)),
      trailing: RowMenu({
        'Edit': () => unawaited(_edit(context, ref, tag)),
        'Delete': () => unawaited(_delete(context, ref, tag)),
      }),
      onTap: () => unawaited(_edit(context, ref, tag)),
    ),
    onAdd: (query) => _add(context, ref, query),
    noun: vocabulary.noun,
    plural: vocabulary.plural,
    empty: EmptyState(
      icon: Icons.label_outline,
      title: 'No ${vocabulary.plural} yet',
      message: vocabulary.blurb,
    ),
  );

  /// True once a tag was added, which is what clears the search.
  Future<bool> _add(BuildContext context, WidgetRef ref, String query) async {
    final color = _unspentColor(vocabulary.tagsIn(model));
    final tag = await promptForTag(
      context,
      title: 'New ${vocabulary.noun}',
      hintText: vocabulary.hint,
      validate: _nameRule(color),
      color: color,
      initial: query,
    );
    if (tag == null || !context.mounted) return false;
    await vocabulary.upsert(ref.read(modelProvider.notifier), tag);
    return true;
  }

  /// Name and colour come back together, so both are offered to the model and
  /// the one that did not change derives an identical model the controller
  /// never saves.
  Future<void> _edit(BuildContext context, WidgetRef ref, Tag tag) async {
    final edited = await promptForTag(
      context,
      title: 'Edit "${tag.name}"',
      hintText: vocabulary.hint,
      validate: _nameRule(tag.color, except: tag.name),
      color: tag.color,
      initial: tag.name,
    );
    if (edited == null || !context.mounted) return;
    final controller = ref.read(modelProvider.notifier);
    await vocabulary.rename(controller, tag.name, edited.name);
    if (!context.mounted) return;
    await vocabulary.upsert(controller, edited);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirmed = await confirmDelete(
      context,
      what: tag.name,
      blockedBy: vocabulary.usersOf(model, tag.name),
      blockedByNoun: vocabulary.blockedByNoun,
    );
    if (!confirmed || !context.mounted) return;
    await vocabulary.remove(ref.read(modelProvider.notifier), tag.name);
  }

  /// The vocabulary's rules bound to the model, with [except] left out so a
  /// rename never collides with the name being renamed. [color] only completes
  /// the [Tag] the rule set takes — no name rule reads it.
  List<ValidationIssue> Function(String) _nameRule(
    TagColor color, {
    String? except,
  }) =>
      (name) => validateTag(
        Tag(name, color: color),
        otherTagNames: {
          for (final tag in vocabulary.tagsIn(model))
            if (tag.name != except) tag.name,
        },
      );
}

/// The first palette colour this vocabulary has not spent, so a new tag comes
/// out distinct from its neighbours without anyone being asked. Once every
/// colour is in use the palette simply starts over.
TagColor _unspentColor(List<Tag> tags) {
  final spent = {for (final tag in tags) tag.color};
  return TagColor.values.firstWhere(
    (color) => !spent.contains(color),
    orElse: () => TagColor.values.first,
  );
}
