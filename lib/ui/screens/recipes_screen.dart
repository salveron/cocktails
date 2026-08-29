import 'dart:async';
import 'dart:math';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../destinations.dart';
import '../toggling.dart';
import '../widgets/cards/recipe_card.dart';
import '../widgets/chips/base_spirit.dart';
import '../widgets/chips/tag_choices.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/scale_dialog.dart';
import '../widgets/lists/entry_list.dart';
import '../widgets/lists/list_terms.dart';
import '../widgets/notices/empty_state.dart';
import '../widgets/notices/snackbar.dart';
import 'recipe_form_screen.dart';

/// Every recipe as a card that expands in place — the compact two lines, or
/// the full view: tags, lines, notes (FR-DIS-2) — and the recipes themselves:
/// add and edit through the pushed form, delete behind the ⋮ (FR-REC-1).
/// Designed in docs/ui-design.md#recipes-screen.
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen>
    with RevealServing<RecipesScreen> {
  /// Expansion state here, not per-card (list disposes what scrolls).
  final _expanded = <String>{};

  /// How an open card is reading its amounts (FR-REC-7), absent while it reads
  /// them as written — a way of looking at one card, which does not outlive it.
  final _views = <String, AmountView>{};

  /// The tags narrowing the list (FR-DIS-3) — screen state like the order and
  /// the search, so nothing about a way of looking reaches the file.
  final _picked = <String>{};

  /// The base spirit narrowing it beside them, absent while it narrows nothing.
  BasePick? _base;

  /// What the last roll landed on, so the next one moves off it (FR-DIS-5).
  String? _rolled;

  final _random = Random();

  void _toggle(String name) => setState(() {
    _expanded.toggle(name);
    if (!_expanded.contains(name)) _views.remove(name);
  });

  /// Opens [name] and shuts everything else — a roll and a jump are each one
  /// answer rather than a pile of them (FR-DIS-5, FR-DIS-9). Every card shutting
  /// takes its reading with it.
  void _openAlone(String name) {
    _views.clear();
    _expanded
      ..clear()
      ..add(name);
  }

  @override
  Destination get revealDestination => Destination.recipes;

  @override
  void prepareReveal(String name) {
    _picked.clear();
    _base = null;
    _openAlone(name);
  }

  @override
  Widget build(BuildContext context) {
    final availability = ref.watch(availabilityProvider);
    ref.listen(revealProvider, (_, request) => serveReveal(request));
    final collection = ref.watch(collectionProvider);
    final tags = ref.watch(recipeTagsProvider);
    // Null on a guest bar; every control that writes is built from it, so the
    // reading half of the screen goes on untouched (FR-BAR-4, ADR 23).
    final writer = ref.watch(barWriterProvider);
    final open = ref.watch(openBarProvider);
    // The reading every card opens under, until one is scaled. Watched here
    // rather than inside rowOf, which the list calls from its itemBuilder: a
    // watch there is one whichever rows got built happen to register, not one
    // this build declares.
    final resting = restingView(open?.display ?? FixedUnit.part);
    return EntryCardList<Recipe>(
      entries: collection.recipes,
      nameOf: (recipe) => recipe.name,
      spellingsOf: (recipe) => recipeSpellings(collection, recipe),
      rowOf: (recipe) =>
          _rowOf(collection, tags, recipe, availability, resting, writer),
      onAdd: writer == null ? null : (query) => _add(collection.units, query),
      reveal: revealing,
      onRefresh: refreshOf(ref, open),
      noun: 'recipe',
      plural: 'recipes',
      filter: _filterFor(collection, tags),
      // The button's face; the draw does the drawing and the opening
      // (FR-DIS-5). Inlined at its one call site, taking the Font Awesome
      // import with it — still one file, as ADR 14 requires.
      draw: (
        icon: const FaIcon(FontAwesomeIcons.dice),
        tooltip: 'Random pick',
        draw: (onShow) => _roll(onShow, availability),
      ),
      orders: {
        // A recipe the pass has yet to judge ranks with the missing ones,
        // where a card drawing no chip belongs.
        'Availability': (recipe) =>
            (availability[recipe.name] ?? Availability.missing).index,
        ...alphabetical,
      },
      empty: const EmptyState(
        icon: Icons.local_bar_outlined,
        title: 'No recipes yet',
        message:
            'Recipes added here appear in this list, marked with what can be '
            'made from the ingredients in stock.',
      ),
    );
  }

  Widget _rowOf(
    Collection collection,
    List<Tag> tags,
    Recipe recipe,
    Map<String, Availability> availability,
    AmountView resting,
    BarWriter? writer,
  ) {
    final expanded = _expanded.contains(recipe.name);
    return RecipeCard(
      collection: collection,
      tags: tags,
      recipe: recipe,
      availability: availability[recipe.name],
      resting: resting,
      view: _views[recipe.name] ?? resting,
      expanded: expanded,
      onToggle: () => _toggle(recipe.name),
      onReach: (ingredient) => _goToIngredient(ref, collection, ingredient),
      actions: {
        if (expanded)
          'Scale & convert': () => unawaited(_scale(recipe, resting)),
        if (writer != null)
          'Edit': () => unawaited(_editRecipe(collection.units, recipe)),
        if (writer != null) 'Delete': () => unawaited(_delete(writer, recipe)),
      },
    );
  }

  ListFilter<Recipe>? _filterFor(Collection collection, List<Tag> tags) =>
      tagFilter(
        tags: tags,
        picked: _picked,
        onToggle: (tag) => setState(() => _picked.toggle(tag)),
        tagsOf: (recipe) => recipe.tags,
        leading: baseFilter(
          collection,
          base: _base,
          onPick: (pick) => setState(() => _base = pick),
        ),
      );

  /// Draws one of the recipes on show that the bar can make now and opens it
  /// alone (FR-DIS-5), answering with its name so the list can put it on screen
  /// (ADR 13). The draw is over what is on show, so the search, the tag picks
  /// and the base pick all already hold; a second roll moves off the one
  /// standing. Everything else shuts, a roll being one answer rather than a
  /// pile of them. Nothing to draw from says so instead of doing nothing.
  ///
  /// [availability] arrives from `build`'s own watch rather than a second read
  /// here, so a roll never judges a card by an answer fresher than the chip it
  /// is drawn beside.
  String? _roll(List<Recipe> onShow, Map<String, Availability> availability) {
    final drawn = randomCanMake(
      onShow,
      availability,
      _random,
      besides: _rolled,
    );
    if (drawn == null) {
      say(ScaffoldMessenger.of(context), 'Nothing here can be made right now.');
      return null;
    }
    setState(() {
      _openAlone(drawn.name);
      _rolled = drawn.name;
    });
    return drawn.name;
  }

  /// The form, and every narrowing let go along with the search once it saves:
  /// a recipe wearing none of the picked tags, or built on another spirit,
  /// would otherwise land out of sight.
  Future<bool> _add(List<Unit> units, String query) async {
    final saved = await RecipeFormScreen.push(
      context,
      units: units,
      initialName: query,
    );
    if (saved != null && mounted) {
      setState(() {
        _picked.clear();
        _base = null;
      });
    }
    return saved != null;
  }

  /// On rename, move expansion state from old name to new name.
  Future<void> _editRecipe(List<Unit> units, Recipe recipe) async {
    final saved = await RecipeFormScreen.push(
      context,
      units: units,
      original: recipe,
    );
    if (saved == null || saved == recipe.name || !mounted) return;
    setState(() {
      if (_expanded.remove(recipe.name)) _expanded.add(saved);
      if (_rolled == recipe.name) _rolled = saved;
      _views.remove(recipe.name);
    });
  }

  /// Reads the open card at another factor, in another unit, or both — for as
  /// long as it stays open (FR-REC-7). Nothing about the recipe changes, so
  /// the way back is [resting], the reading every other card is under.
  Future<void> _scale(Recipe recipe, AmountView resting) async {
    final chosen = await promptForScale(
      context,
      recipe: recipe.name,
      view: _views[recipe.name] ?? resting,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (chosen == resting) {
        _views.remove(recipe.name);
      } else {
        _views[recipe.name] = chosen;
      }
    });
  }

  /// Delete: never blocked since nothing references recipes.
  Future<void> _delete(BarWriter writer, Recipe recipe) async {
    final confirmed = await askToDelete(context, what: recipe.name);
    if (!confirmed || !mounted) return;
    await writer.removeRecipe(recipe.name);
    if (mounted) {
      setState(() {
        _expanded.remove(recipe.name);
        _views.remove(recipe.name);
      });
    }
  }
}

/// Sends the reader to the ingredient a line names, on the Ingredients screen
/// (FR-DIS-9). Under the ingredient's own name: a line may spell it any way
/// the vocabulary answers to (ADR 10), and a list finds its rows under theirs.
void _goToIngredient(WidgetRef ref, Collection collection, String ingredient) =>
    ref
        .read(revealProvider.notifier)
        .ask(Destination.ingredients, collection.spellingOf(ingredient));
