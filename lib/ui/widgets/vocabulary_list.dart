/// The one list every vocabulary is drawn as — the inventory and both tag tabs
/// alike (docs/ui-design.md#vocabulary-editing).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'search_field.dart';

/// The one order a vocabulary is read in: A→Z, case ignored.
int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// What narrows a list beyond its name: the [row] of controls under the search,
/// the [test] an entry must pass, and [narrowing] — what those controls
/// currently come to, worded to follow "matches", or null while none is set.
typedef ListFilter<T> = ({
  Widget row,
  bool Function(T entry) test,
  String? narrowing,
});

/// One row on the tinted ground every vocabulary shares: separation by mass
/// rather than by a rule between rows. The clip keeps the tap ripple inside the
/// corners.
class VocabularyRow extends StatelessWidget {
  const VocabularyRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.body,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;

  /// What the card carries below its lines — a recipe card expanded in place.
  final Widget? body;

  final Widget? trailing;

  /// Whatever the row's tap means on this screen — stock on the inventory, the
  /// edit dialog on a tag tab, expansion on the recipe list.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final tile = ListTile(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
    return Card.filled(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: body == null
          ? tile
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: body,
                ),
              ],
            ),
    );
  }
}

/// The per-row ⋮: whatever the row's own tap is not, labelled and in order. It
/// carries the callbacks themselves, so no screen writes a menu-action enum
/// that exists only to be switched straight back over.
class RowMenu extends StatelessWidget {
  const RowMenu(this.actions, {super.key});

  final Map<String, VoidCallback> actions;

  @override
  Widget build(BuildContext context) => PopupMenuButton<VoidCallback>(
    tooltip: 'More',
    onSelected: (action) => action(),
    itemBuilder: (context) => [
      for (final action in actions.entries)
        PopupMenuItem(value: action.value, child: Text(action.key)),
    ],
  );
}

/// The pinned search, the A→Z sort, the three faces and the add button, over
/// rows the screen describes. A screen supplies what a row shows and what its
/// tap does; everything around that is here, once.
class VocabularyList<T> extends StatefulWidget {
  const VocabularyList({
    required this.entries,
    required this.nameOf,
    required this.rowOf,
    required this.noun,
    required this.plural,
    required this.empty,
    this.onAdd,
    this.filter,
    super.key,
  });

  final List<T> entries;
  final String Function(T entry) nameOf;
  final VocabularyRow Function(T entry) rowOf;

  /// What narrows the list besides its search, for a screen that has such a
  /// thing — null for one that has not.
  final ListFilter<T>? filter;

  /// Adds an entry, [query] prefilling its name where the search found nothing.
  /// True when one was added — a cancelled add must not clear the search. Null
  /// for a screen with no way to add yet, which drops the button and the
  /// "nothing matches" offer with it.
  final Future<bool> Function(String query)? onAdd;

  /// What one entry is called, singular and plural: the search hint, the add
  /// tooltip and the "nothing matches" line are worded from these.
  final String noun;
  final String plural;

  /// The face of a vocabulary with nothing in it yet.
  final EmptyState empty;

  @override
  State<VocabularyList<T>> createState() => _VocabularyListState<T>();
}

class _VocabularyListState<T> extends State<VocabularyList<T>> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The list brings its own [Scaffold]: the destinations share the shell's
  /// one, which has no room for a per-screen button.
  @override
  Widget build(BuildContext context) {
    final add = widget.onAdd;
    return Scaffold(
      body: widget.entries.isEmpty ? widget.empty : _searchable(add),
      floatingActionButton: add == null
          ? null
          : FloatingActionButton(
              onPressed: () => unawaited(_add(add, '')),
              tooltip: 'Add ${widget.noun}',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _searchable(Future<bool> Function(String query)? add) {
    final filter = widget.filter;
    final matches =
        widget.entries
            .where(
              (entry) =>
                  matchesQuery(widget.nameOf(entry), _search.text) &&
                  (filter?.test(entry) ?? true),
            )
            .toList()
          ..sort((a, b) => byName(widget.nameOf(a), widget.nameOf(b)));
    final query = _search.text.trim();
    return Column(
      // The search and whatever narrows below it run the list's full width.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchField(controller: _search, hintText: 'Search ${widget.plural}'),
        if (filter != null) filter.row,
        Expanded(
          child: matches.isEmpty
              ? _NoMatch(
                  query: query,
                  narrowing: filter?.narrowing,
                  noun: widget.noun,
                  onAdd: add == null ? null : () => unawaited(_add(add, query)),
                )
              : ListView.builder(
                  // Room for the last row to clear the button above it.
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: matches.length,
                  itemBuilder: (context, index) => KeyedSubtree(
                    key: ValueKey(widget.nameOf(matches[index])),
                    child: widget.rowOf(matches[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// Clears the search once something was added, so the new entry cannot land
  /// outside the query and leave the screen looking as if nothing happened.
  Future<void> _add(
    Future<bool> Function(String query) add,
    String query,
  ) async {
    if (await add(query) && mounted) _search.clear();
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({
    required this.query,
    required this.narrowing,
    required this.noun,
    required this.onAdd,
  });

  final String query;
  final String? narrowing;
  final String noun;
  final VoidCallback? onAdd;

  /// Whatever narrowed the list is named, and both when both did: an empty
  /// list that blames only half of it sends the reader hunting for the rest.
  String get _reason {
    final narrowing = this.narrowing;
    final causes = [
      if (query.isNotEmpty) 'is called "$query"',
      if (narrowing != null) 'matches $narrowing',
    ];
    return 'No $noun here ${causes.join(' and ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final onAdd = this.onAdd;
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: 'Nothing matches',
      message: _reason,
      action: query.isEmpty || onAdd == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('Add "$query"'),
            ),
    );
  }
}
