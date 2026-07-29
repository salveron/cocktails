/// The one list every vocabulary is drawn as — the inventory and both tag tabs
/// alike (docs/ui-design.md#vocabulary-editing).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'search_field.dart';

/// One row on the tinted ground every vocabulary shares: separation by mass
/// rather than by a rule between rows. The clip keeps the tap ripple inside the
/// corners.
class VocabularyRow extends StatelessWidget {
  const VocabularyRow({
    required this.title,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Widget title;
  final Widget? trailing;

  /// Whatever the row's tap means on this screen — stock on the inventory, the
  /// edit dialog on a tag tab.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card.filled(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    color: Theme.of(context).colorScheme.surfaceContainer,
    clipBehavior: Clip.antiAlias,
    child: ListTile(title: title, trailing: trailing, onTap: onTap),
  );
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
    required this.onAdd,
    required this.noun,
    required this.plural,
    required this.empty,
    super.key,
  });

  final List<T> entries;
  final String Function(T entry) nameOf;
  final VocabularyRow Function(T entry) rowOf;

  /// Adds an entry, [query] prefilling its name where the search found nothing.
  /// True when one was added — a cancelled add must not clear the search.
  final Future<bool> Function(String query) onAdd;

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
  Widget build(BuildContext context) => Scaffold(
    body: widget.entries.isEmpty ? widget.empty : _searchable(),
    floatingActionButton: FloatingActionButton(
      onPressed: () => unawaited(_add('')),
      tooltip: 'Add ${widget.noun}',
      child: const Icon(Icons.add),
    ),
  );

  Widget _searchable() {
    final matches =
        widget.entries
            .where((entry) => matchesQuery(widget.nameOf(entry), _search.text))
            .toList()
          ..sort(
            (a, b) => widget
                .nameOf(a)
                .toLowerCase()
                .compareTo(widget.nameOf(b).toLowerCase()),
          );
    final query = _search.text.trim();
    return Column(
      children: [
        SearchField(controller: _search, hintText: 'Search ${widget.plural}'),
        Expanded(
          child: matches.isEmpty
              ? _NoMatch(
                  query: query,
                  noun: widget.noun,
                  onAdd: () => unawaited(_add(query)),
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
  Future<void> _add(String query) async {
    if (await widget.onAdd(query) && mounted) _search.clear();
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({
    required this.query,
    required this.noun,
    required this.onAdd,
  });

  final String query;
  final String noun;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.search_off_outlined,
    title: 'Nothing matches',
    message: 'No $noun here is called "$query".',
    action: FilledButton.tonalIcon(
      onPressed: onAdd,
      icon: const Icon(Icons.add),
      label: Text('Add "$query"'),
    ),
  );
}
