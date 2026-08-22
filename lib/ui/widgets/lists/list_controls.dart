/// A searchable list's chrome: the search field and the sort it opens, the
/// filter's own row, and the two buttons that stand over the list — everything
/// but the list itself, which is `entry_list.dart`'s (ADR 13).
library;

import 'package:flutter/material.dart';

import '../notices/empty_state.dart';
import 'list_terms.dart';

/// The search field, the sort chips it opens, the filter's own row, and
/// [list] — the rows on show, or what stands in for them where there are
/// none.
class SearchableList<T> extends StatelessWidget {
  const SearchableList({
    required this.search,
    required this.plural,
    required this.picking,
    required this.onTogglePicking,
    required this.orders,
    required this.order,
    required this.backwards,
    required this.onPick,
    required this.filter,
    required this.list,
    super.key,
  });

  final TextEditingController search;
  final String plural;
  final bool picking;
  final VoidCallback onTogglePicking;
  final ListOrders<T> orders;
  final String order;
  final bool backwards;
  final void Function(String label) onPick;
  final ListFilter<T>? filter;

  /// The rows on show — built by the caller, which is the one place a list
  /// knows it scrolls (ADR 13).
  final Widget list;

  @override
  Widget build(BuildContext context) {
    final filter = this.filter;
    return Column(
      // Full width: search and filter controls.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchField(
          controller: search,
          hintText: 'Search $plural',
          trailing: IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            isSelected: picking,
            onPressed: onTogglePicking,
          ),
        ),
        if (picking)
          _OrderChips(
            labels: orders.keys,
            order: order,
            backwards: backwards,
            onPick: onPick,
          ),
        if (filter != null) filter.row,
        Expanded(child: list),
      ],
    );
  }
}

/// Search field with clear button (caller owns controller/rebuild). [trailing]
/// rides beside the field, for what acts on the list rather than on the text.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear',
                      onPressed: controller.clear,
                    ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// The orders offered, the one in force wearing which way it is read.
class _OrderChips extends StatelessWidget {
  const _OrderChips({
    required this.labels,
    required this.order,
    required this.backwards,
    required this.onPick,
  });

  final Iterable<String> labels;
  final String order;
  final bool backwards;
  final void Function(String label) onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: [
          for (final label in labels)
            FilterChip(
              label: Text(label),
              avatar: label != order
                  ? null
                  : Icon(
                      backwards ? Icons.arrow_upward : Icons.arrow_downward,
                      semanticLabel: backwards ? 'backwards' : 'forwards',
                    ),
              selected: label == order,
              showCheckmark: false,
              onSelected: (_) => onPick(label),
            ),
        ],
      ),
    ),
  );
}

/// What stands over the list: the draw above the add, the two alike in size
/// so neither reads as the lesser reach. The draw keeps away while there is
/// nothing on show to draw from.
class ListButtons<T> extends StatelessWidget {
  const ListButtons({
    required this.draw,
    required this.canDraw,
    required this.noun,
    required this.onDraw,
    required this.onAdd,
    super.key,
  });

  final RandomDraw<T>? draw;
  final bool canDraw;
  final String noun;
  final VoidCallback? onDraw;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final draw = this.draw;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (draw != null && canDraw) ...[
          FloatingActionButton(
            heroTag: null,
            onPressed: onDraw,
            tooltip: draw.tooltip,
            child: draw.icon,
          ),
          const SizedBox(height: 12),
        ],
        if (onAdd != null)
          FloatingActionButton(
            // Avoid hero tag collision (multiple FABs coexist).
            heroTag: null,
            onPressed: onAdd,
            tooltip: 'Add $noun',
            child: const Icon(Icons.add),
          ),
      ],
    );
  }
}

/// What stands in [list] where the search, the filter, or both have narrowed
/// it to nothing — never shown for a vocabulary with nothing in it at all,
/// which is the caller's own `empty` to say. Offers to add what was typed
/// only where a search is part of what emptied it; a filter alone leaves
/// nowhere to go, since what it narrows by is not what [onAdd] would add.
class NoMatch extends StatelessWidget {
  const NoMatch({
    required this.query,
    required this.narrowing,
    required this.noun,
    required this.onAdd,
    super.key,
  });

  final String query;
  final String? narrowing;
  final String noun;
  final VoidCallback? onAdd;

  /// Reason message: blames search and/or filter. "Answers to" rather than "is
  /// called": a query reaches an entry's other spellings too, and on the
  /// recipes the ingredients it is built from (FR-VOC-6, FR-DIS-2).
  String get _reason {
    final narrowing = this.narrowing;
    final causes = [
      if (query.isNotEmpty) 'answers to "$query"',
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
