/// The one list every vocabulary is drawn as — the inventory and both tag tabs
/// alike (docs/ui-design.md#vocabulary-editing).
library;

import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'search_field.dart';

/// The tie-break under every order: A→Z, case ignored.
int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// The orders a list can be read in — a label each, and where it ranks an
/// entry — first the one the list opens in (docs/ui-design.md#searchable-lists).
/// Ranks come off the domain's own enums, whose declaration order is already
/// the traffic light and the palette.
typedef ListOrders<T> = Map<String, int Function(T entry)>;

/// The order every list offers: entries rank alike, so the tie-break is the
/// whole of it.
const alphabetical = {'Name': _alike};

int _alike(Object? entry) => 0;

/// [tags] in that order — the order chips are offered in and dots are drawn
/// in, so two entries wearing the same tags read the same on every screen.
List<Tag> sortedByName(List<Tag> tags) =>
    [...tags]..sort((a, b) => byName(a.name, b.name));

extension ToggleMembership<T> on Set<T> {
  /// Toggle membership (add if absent, remove if present).
  void toggle(T value) {
    if (!remove(value)) add(value);
  }
}

/// Controls to narrow list: row widget, test function, human description.
typedef ListFilter<T> = ({
  Widget row,
  bool Function(T entry) test,
  String? narrowing,
});

/// Single vocab row with optional body; ripple clipped to card corners.
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

  /// Optional content below title/subtitle (e.g., expanded recipe).
  final Widget? body;

  final Widget? trailing;

  /// Row tap action (screen-specific meaning).
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

/// Per-row menu (⋮); carries callbacks directly (no enum boilerplate).
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

/// Shared list template: search, sort, filter, empty state, add button.
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
    this.orders = alphabetical,
    super.key,
  });

  final List<T> entries;
  final String Function(T entry) nameOf;
  final VocabularyRow Function(T entry) rowOf;

  /// What this list can be read by, over and above its name.
  final ListOrders<T> orders;

  /// Optional narrowing control (null if not applicable).
  final ListFilter<T>? filter;

  /// Add callback; query prefills name; returns true if added (don't clear search).
  final Future<bool> Function(String query)? onAdd;

  /// Entry name (singular/plural) for hints and messages.
  final String noun;
  final String plural;

  /// Empty state widget.
  final EmptyState empty;

  @override
  State<VocabularyList<T>> createState() => _VocabularyListState<T>();
}

class _VocabularyListState<T> extends State<VocabularyList<T>> {
  final _search = TextEditingController();

  /// The order picked, and whether it is read backwards. Backwards reverses the
  /// whole list, tie-break included, so Z→A falls out of the A→Z order the way
  /// "missing first" falls out of availability — one flip, no second rule.
  late String _order = widget.orders.keys.first;
  bool _backwards = false;

  /// Whether the orders are on show. The one in force stands either way.
  bool _picking = false;

  /// The names in the order the rows last stood in, and what put them there.
  /// A row never moves under the finger editing it, so a placement stands until
  /// the rows on show change or another order is picked.
  List<String> _placed = const [];
  (String, bool)? _placedUnder;

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

  /// Own Scaffold needed (shell's doesn't fit per-screen button).
  @override
  Widget build(BuildContext context) {
    final add = widget.onAdd;
    return Scaffold(
      body: widget.entries.isEmpty ? widget.empty : _searchable(add),
      floatingActionButton: add == null
          ? null
          : FloatingActionButton(
              // Avoid hero tag collision (multiple FABs coexist).
              heroTag: null,
              onPressed: () => unawaited(_add(add, '')),
              tooltip: 'Add ${widget.noun}',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _searchable(Future<bool> Function(String query)? add) {
    final filter = widget.filter;
    final matches = _place(
      widget.entries
          .where(
            (entry) =>
                matchesQuery(widget.nameOf(entry), _search.text) &&
                (filter?.test(entry) ?? true),
          )
          .toList(),
    );
    final query = _search.text.trim();
    return Column(
      // Full width: search and filter controls.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchField(
          controller: _search,
          hintText: 'Search ${widget.plural}',
          trailing: IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            isSelected: _picking,
            onPressed: () => setState(() => _picking = !_picking),
          ),
        ),
        if (_picking) _orders(),
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
                  // Padding so last row clears FAB.
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

  /// The orders offered, the one in force wearing which way it is read.
  Widget _orders() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          for (final label in widget.orders.keys)
            FilterChip(
              label: Text(label),
              avatar: label != _order
                  ? null
                  : Icon(
                      _backwards ? Icons.arrow_upward : Icons.arrow_downward,
                      semanticLabel: _backwards ? 'backwards' : 'forwards',
                    ),
              selected: label == _order,
              showCheckmark: false,
              onSelected: (_) => setState(() => _pick(label)),
            ),
        ],
      ),
    ),
  );

  /// Picking the order in force turns it around; picking another starts it the
  /// way round it is written.
  void _pick(String label) {
    _backwards = label == _order && !_backwards;
    _order = label;
  }

  /// [matches] where the last placement put them, or freshly placed where that
  /// placement no longer answers — the rows on show have changed, or another
  /// order has been picked. Assigning through a build records where the rows
  /// already stood; it settles nothing new, and asks for no frame.
  List<T> _place(List<T> matches) {
    final names = {for (final entry in matches) widget.nameOf(entry)};
    final under = (_order, _backwards);
    // Names are unique within a vocabulary, so this is set equality.
    if (_placedUnder != under ||
        names.length != _placed.length ||
        !names.containsAll(_placed)) {
      final rank = widget.orders[_order] ?? _alike;
      final placed = [...matches]
        ..sort((a, b) {
          final byRank = rank(a).compareTo(rank(b));
          return byRank != 0
              ? byRank
              : byName(widget.nameOf(a), widget.nameOf(b));
        });
      _placed = [
        for (final entry in _backwards ? placed.reversed : placed)
          widget.nameOf(entry),
      ];
      _placedUnder = under;
    }
    final entries = {for (final entry in matches) widget.nameOf(entry): entry};
    return [for (final name in _placed) ?entries[name]];
  }

  /// Clear search after adding so new entry appears.
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

  /// Reason message: blames search and/or filter.
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
