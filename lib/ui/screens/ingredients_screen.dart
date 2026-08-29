import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../destinations.dart';
import '../toggling.dart';
import '../widgets/cards/entry_card.dart';
import '../widgets/chips/color_marks.dart';
import '../widgets/chips/tag_choices.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/entry_dialog.dart';
import '../widgets/lists/entry_list.dart';
import '../widgets/lists/list_terms.dart';
import '../widgets/notices/empty_state.dart';

/// Every ingredient and what is left of it — searchable by name and by tag, one
/// tap per stock change (FR-ING-1/2/3) — and the vocabulary itself: add, edit,
/// delete (FR-VOC-1). It also serves what another screen asks for, an ingredient
/// being named on both the others (FR-DIS-9). Designed in
/// docs/ui-design.md#ingredients-screen.
class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen>
    with RevealServing<IngredientsScreen> {
  final _picked = <String>{};

  void _toggle(String tag) => setState(() => _picked.toggle(tag));

  @override
  Destination get revealDestination => Destination.ingredients;

  @override
  void prepareReveal(String name) => _picked.clear();

  @override
  Widget build(BuildContext context) {
    ref.listen(revealProvider, (_, request) => serveReveal(request));
    final collection = ref.watch(collectionProvider);
    // Null on a guest bar, and the whole of the rule: every control that would
    // write is built from it, so none can be offered where there is nothing to
    // write with (FR-BAR-4, ADR 23).
    final writer = ref.watch(barWriterProvider);
    final tags = ref.watch(ingredientTagsProvider);
    return EntryCardList<Ingredient>(
      entries: collection.ingredients,
      nameOf: (ingredient) => ingredient.name,
      spellingsOf: (ingredient) => ingredient.spellings,
      rowOf: (ingredient) => _IngredientCard(
        tags: tags,
        ingredient: ingredient,
        onTap: writer == null
            ? null
            : () => unawaited(
                writer.setStock(ingredient.name, ingredient.stock.next),
              ),
        actions: writer == null
            ? const {}
            : {
                'Edit': () => unawaited(
                  _editIngredient(writer, collection, tags, ingredient),
                ),
                'Delete': () =>
                    unawaited(_delete(writer, collection, ingredient)),
              },
      ),
      onAdd: writer == null
          ? null
          : (query) => _add(writer, collection, tags, query),
      reveal: revealing,
      onRefresh: refreshOf(ref, ref.watch(openBarProvider)),
      noun: 'ingredient',
      plural: 'ingredients',
      orders: {
        'Stock': (ingredient) => ingredient.stock.index,
        ...alphabetical,
      },
      filter: tagFilter(
        tags: tags,
        picked: _picked,
        onToggle: _toggle,
        tagsOf: (ingredient) => ingredient.tags,
      ),
      empty: const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No ingredients yet',
        message:
            'Every ingredient the recipes here use is listed, with what is '
            'in stock.',
      ),
    );
  }

  /// Returns true after adding; clears picked tags along with search.
  Future<bool> _add(
    BarWriter writer,
    Collection collection,
    List<Tag> tags,
    String query,
  ) async {
    final added = await promptForIngredient(
      context,
      title: 'New ingredient',
      hintText: 'Ingredient name',
      validate: _entryRule(collection),
      tags: tags,
      initial: query,
    );
    if (added == null || !mounted) return false;
    await writer.upsertIngredient(
      Ingredient(added.name, aliases: added.aliases, tags: added.tags),
    );
    if (mounted) setState(_picked.clear);
    return true;
  }

  /// Atomic upsert: name, aliases and tags edited together; stock unchanged.
  Future<void> _editIngredient(
    BarWriter writer,
    Collection collection,
    List<Tag> tags,
    Ingredient ingredient,
  ) async {
    final edited = await promptForIngredient(
      context,
      title: 'Edit "${ingredient.name}"',
      hintText: 'Ingredient name',
      validate: _entryRule(collection, except: ingredient.name),
      tags: tags,
      aliases: ingredient.aliases,
      chosen: ingredient.tags,
      initial: ingredient.name,
    );
    if (edited == null || !mounted) return;
    await writer.upsertIngredient(
      ingredient.copyWith(
        name: edited.name,
        aliases: edited.aliases,
        tags: edited.tags,
      ),
      replacing: ingredient.name,
    );
  }

  Future<void> _delete(
    BarWriter writer,
    Collection collection,
    Ingredient ingredient,
  ) async {
    final confirmed = await confirmDelete(
      context,
      what: ingredient.name,
      blockedBy: collection.recipesUsingIngredient(ingredient.name),
      blockedByNoun: 'recipes',
    );
    if (!confirmed || !mounted) return;
    await writer.removeIngredient(ingredient.name);
  }
}

/// Row tap toggles stock (in → low → out → in); vocab actions use ⋮. On a
/// guest bar the stock is the owner's reading of their own shelf, so the row
/// keeps its chip and loses both — a tap that changed it would be the reader
/// judging one bar by another (FR-BAR-4). [onTap] and [actions] arrive built
/// from the screen's own writer, empty or null where it has none.
class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    required this.tags,
    required this.ingredient,
    required this.onTap,
    required this.actions,
  });

  final List<Tag> tags;
  final Ingredient ingredient;
  final VoidCallback? onTap;
  final Map<String, VoidCallback> actions;

  @override
  Widget build(BuildContext context) => EntryCard(
    title: DottedName(ingredient.name, tags: tags, worn: ingredient.tags),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [StockChip(ingredient.stock), RowMenu(actions)],
    ),
    onTap: onTap,
  );
}

/// The vocabulary's own rules over the entry as the dialog has it — every
/// spelling but [except]'s to collide with, so a rename never hits itself.
List<ValidationIssue> Function(VocabularyEntry) _entryRule(
  Collection collection, {
  String? except,
}) =>
    (entry) => validateIngredient(
      Ingredient(entry.name, aliases: entry.aliases, tags: entry.tags),
      knownIngredientTags: collection.tagNames(TagKind.ingredient),
      otherIngredientNames: collection.ingredientSpellings(except: except),
    );
