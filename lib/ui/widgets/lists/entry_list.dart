/// The one list every vocabulary is drawn as — the ingredients and both tag
/// tabs alike (docs/ui-design.md#vocabulary-editing). The one file that knows
/// a list scrolls (ADR 13); its chrome is `list_controls.dart`'s.
library;

import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../notices/empty_state.dart';
import 'list_controls.dart';
import 'list_terms.dart';

/// Substring match under the fold every name comparison keeps, so what a
/// search reaches and what a name is are the one rule (ADR 08).
bool matchesQuery(String text, String query) =>
    nameKey(text).contains(nameKey(query.trim()));

/// The pull a guest bar's lists answer (FR-BAR-5), null on an owned bar which
/// has no source. `RefreshFailure` meets what it comes to.
Future<void> Function()? refreshOf(WidgetRef ref, Bar? open) {
  if (open == null || open.isOwned) return null;
  return () => ref.read(shelfProvider.notifier).refresh(open.id);
}

/// Shared list template: search, sort, filter, empty state, add button.
class EntryCardList<T> extends StatefulWidget {
  const EntryCardList({
    required this.entries,
    required this.nameOf,
    required this.rowOf,
    required this.noun,
    required this.plural,
    required this.empty,
    this.onAdd,
    this.filter,
    this.draw,
    this.reveal,
    this.onRefresh,
    this.orders = alphabetical,
    this.spellingsOf,
    super.key,
  });

  /// The swipe that asks the bar's source for it again (FR-BAR-5) — a guest
  /// bar's lists and nowhere else, which is why the shell carries no refresh
  /// control (docs/ui-design.md#bars). Null where there is no source to ask.
  final Future<void> Function()? onRefresh;

  final List<T> entries;
  final String Function(T entry) nameOf;
  final Widget Function(T entry) rowOf;

  /// Every spelling the search matches an entry by — the name alone where a
  /// screen names none. An ingredient answers to its aliases too (ADR 10), and
  /// is still found under the one name its row reads under.
  final List<String> Function(T entry)? spellingsOf;

  final ListOrders<T> orders;

  final ListFilter<T>? filter;
  final RandomDraw<T>? draw;

  /// A row another destination asked this list to put on screen (ADR 19),
  /// carried on the one build answering a request and null on every other, so
  /// the same row asked for twice is revealed twice. It feeds the `_reveal` a
  /// draw fills.
  final String? reveal;

  /// Add callback; query prefills name; returns true if added (don't clear search).
  final Future<bool> Function(String query)? onAdd;

  final String noun;
  final String plural;
  final EmptyState empty;

  @override
  State<EntryCardList<T>> createState() => _EntryCardListState<T>();
}

class _EntryCardListState<T> extends State<EntryCardList<T>> {
  final _search = TextEditingController();

  /// How a drawn row is reached, the rows being built as they are scrolled to
  /// and so out of reach of anything asking for a built one (ADR 13).
  final _scroller = ItemScrollController();

  /// Where the rows stand, and the one named waiting to be reached.
  final _positions = ItemPositionsListener.create();
  String? _reveal;

  /// Whether the reader has narrowed since the list last settled: the search,
  /// the order, or the filter's own picks moving, read off at exactly those
  /// three — the collection changing under them (a rename, an entry gone)
  /// never counts, so it leaves them where they were reading (ADR 19).
  bool _home = false;

  /// The trimmed search as judged last for [_home] — the listener [_typed]
  /// answers to fires on a bare cursor move too, so this is what tells that
  /// apart from the text actually changing.
  String _lastSearch = '';

  /// The row a draw landed on, washing to say which it is, and how many draws
  /// have landed — the count starting the wash over where one lands on the row
  /// another just left washing.
  String? _washing;
  int _washes = 0;

  /// The order picked, and whether it is read backwards. Backwards reverses the
  /// whole list, tie-break included, so Z→A falls out of the A→Z order the way
  /// "missing first" falls out of availability — one flip, no second rule.
  late String _order = widget.orders.keys.first;
  bool _backwards = false;

  bool _picking = false;

  /// The names in the order the rows last stood in, and what put them there.
  /// A row never moves under the finger editing it, so a placement stands until
  /// the rows on show change or another order is picked.
  List<String> _placed = const [];
  (String, bool)? _placedUnder;

  /// [_placed], entries attached — what `build` draws. Kept current from
  /// [_reposition] wherever an input that could move it actually does; `build`
  /// only ever reads it back, never recomputes it.
  List<T> _shown = const [];

  @override
  void initState() {
    super.initState();
    _search.addListener(_typed);
    _positions.itemPositions.addListener(_reach);
    _reposition();
  }

  void _typed() => setState(() {
    final text = _search.text.trim();
    if (text != _lastSearch) _home = true;
    _lastSearch = text;
    _reposition();
  });

  /// Every narrowing this list owns goes before the row is revealed (ADR 19).
  /// The search is cleared without announcing itself: the listener it would
  /// otherwise ring is off for it, [_reposition] answering for the clear
  /// itself once below.
  @override
  void didUpdateWidget(covariant EntryCardList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.filter?.picks, widget.filter?.picks)) {
      _home = true;
    }
    if (widget.reveal case final name?) {
      _reveal = name;
      _home = true;
      _order = widget.orders.keys.first;
      _backwards = false;
      _lastSearch = '';
      _search
        ..removeListener(_typed)
        ..clear()
        ..addListener(_typed);
    }
    _reposition();
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_reach);
    _search.dispose();
    super.dispose();
  }

  /// Own Scaffold needed (shell's doesn't fit per-screen button).
  @override
  Widget build(BuildContext context) {
    final add = widget.onAdd;
    final draw = widget.draw;
    return Scaffold(
      body: widget.entries.isEmpty
          ? _Refreshable(onRefresh: widget.onRefresh, child: widget.empty)
          : SearchableList<T>(
              search: _search,
              plural: widget.plural,
              picking: _picking,
              onTogglePicking: () => setState(() => _picking = !_picking),
              orders: widget.orders,
              order: _order,
              backwards: _backwards,
              onPick: (label) => setState(() => _pick(label)),
              filter: widget.filter,
              list: _MatchesArea<T>(
                matches: _shown,
                query: _search.text.trim(),
                narrowing: widget.filter?.narrowing,
                noun: widget.noun,
                onAddQuery: add == null
                    ? null
                    : (query) => unawaited(_add(add, query)),
                nameOf: widget.nameOf,
                rowOf: widget.rowOf,
                washing: _washing,
                washes: _washes,
                onWashDone: () => setState(() => _washing = null),
                scroller: _scroller,
                positions: _positions,
                onRefresh: widget.onRefresh,
                hasDraw: draw != null,
              ),
            ),
      floatingActionButton: add == null && draw == null
          ? null
          : ListButtons<T>(
              draw: draw,
              canDraw: _shown.isNotEmpty,
              noun: widget.noun,
              onDraw: draw == null ? null : () => _draw(draw, _shown),
              onAdd: add == null ? null : () => unawaited(_add(add, '')),
            ),
    );
  }

  /// The rows on show, unordered: what the search reaches and the filter
  /// keeps.
  List<T> _filtered() {
    final filter = widget.filter;
    return widget.entries
        .where(
          (entry) =>
              (widget.spellingsOf?.call(entry) ?? [widget.nameOf(entry)]).any(
                (spelling) => matchesQuery(spelling, _search.text),
              ) &&
              (filter?.test(entry) ?? true),
        )
        .toList();
  }

  /// Draws one of the rows on show, leaving it to [_reach] to put on screen —
  /// the one place a name becomes an index, and the only thing here that knows
  /// the list scrolls at all (ADR 13).
  void _draw(RandomDraw<T> draw, List<T> onShow) {
    _reveal = draw.draw(onShow);
  }

  /// Puts the list where it is next to stand, once it has measured itself: the
  /// top, where a narrowing has made a different list of it, or the row that
  /// was named. Home first, and the two do now wait together — a jump clears
  /// the narrowings and names a row in the one act (ADR 19), where a draw is
  /// made over rows already on show. Home returns early, so the reveal is
  /// served on the measurement that follows; going home re-anchors the package
  /// on row one besides (ADR 13), which is what leaves a narrowed list reading
  /// from its start rather than wherever the wider one stood.
  ///
  /// The named row, then. A draw is asked for while the rows still stand as they
  /// did: the screen opens the one named and shuts whatever stood open, and a
  /// row already in view is reached in pixels rather than by index — so
  /// scrolling any earlier aims at where the row *was*, and a tall card
  /// shutting above it carries the row off the top. The measurement arriving is
  /// the signal that it is safe. The wash waits for the scroll in turn, having
  /// nothing to say while the row it names is still moving.
  void _reach() {
    if (_home) {
      _home = false;
      if (_scroller.isAttached) _scroller.jumpTo(index: 0);
      return;
    }
    final drawn = _reveal;
    if (drawn == null) return;
    _reveal = null;
    final index = _placed.indexOf(drawn);
    if (index < 0 || !_scroller.isAttached) return;
    unawaited(
      _scroller.scrollTo(index: index, duration: Durations.medium2).then((_) {
        if (!mounted) return;
        setState(() {
          _washing = drawn;
          _washes++;
        });
      }),
    );
  }

  /// Picking the order in force turns it around; picking another starts it the
  /// way round it is written — always a narrowing of its own (ADR 19).
  void _pick(String label) {
    _backwards = label == _order && !_backwards;
    _order = label;
    _home = true;
    _reposition();
  }

  /// Keeps [_shown] answering to what belongs on show, in the order it last
  /// stood: [_placed] is freshly sorted only where the rows on show have
  /// changed or another order has been picked, so a row never moves under the
  /// finger editing it. Called wherever an input that could move either
  /// actually does — never as a side effect of `build`, which only reads the
  /// result back.
  void _reposition() {
    final matches = widget.entries.isEmpty ? <T>[] : _filtered();
    final names = {for (final entry in matches) widget.nameOf(entry)};
    final under = (_order, _backwards);
    // Names are unique within a vocabulary, so this is set equality.
    if (_placedUnder != under ||
        names.length != _placed.length ||
        !names.containsAll(_placed)) {
      final rank = widget.orders[_order] ?? alike;
      final placed = [...matches]
        ..sort((a, b) {
          final byRank = rank(a).compareTo(rank(b));
          return byRank != 0
              ? byRank
              : compareNames(widget.nameOf(a), widget.nameOf(b));
        });
      _placed = [
        for (final entry in _backwards ? placed.reversed : placed)
          widget.nameOf(entry),
      ];
      _placedUnder = under;
    }
    final entries = {for (final entry in matches) widget.nameOf(entry): entry};
    _shown = [for (final name in _placed) ?entries[name]];
  }

  /// Clear search after adding so new entry appears.
  Future<void> _add(
    Future<bool> Function(String query) add,
    String query,
  ) async {
    if (await add(query) && mounted) _search.clear();
  }
}

/// [child] under the pull that refreshes, where one is offered. Wrapped
/// around what scrolls rather than around the search standing over it, that
/// being where the reader pulls. A body with nothing to scroll is given
/// something: an empty bar is exactly where the gesture is the only way to
/// ask a source at all, so it must answer there too.
class _Refreshable extends StatelessWidget {
  const _Refreshable({
    required this.onRefresh,
    required this.child,
    this.scrolls = false,
  });

  final Future<void> Function()? onRefresh;
  final Widget child;
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final onRefresh = this.onRefresh;
    if (onRefresh == null) return child;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: scrolls
          ? child
          : LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: child,
                ),
              ),
            ),
    );
  }
}

/// The rows on show, or what stands in for them where there are none.
class _MatchesArea<T> extends StatelessWidget {
  const _MatchesArea({
    required this.matches,
    required this.query,
    required this.narrowing,
    required this.noun,
    required this.onAddQuery,
    required this.nameOf,
    required this.rowOf,
    required this.washing,
    required this.washes,
    required this.onWashDone,
    required this.scroller,
    required this.positions,
    required this.onRefresh,
    required this.hasDraw,
  });

  final List<T> matches;
  final String query;
  final String? narrowing;
  final String noun;
  final void Function(String query)? onAddQuery;
  final String Function(T entry) nameOf;
  final Widget Function(T entry) rowOf;
  final String? washing;
  final int washes;
  final VoidCallback onWashDone;
  final ItemScrollController scroller;
  final ItemPositionsListener positions;
  final Future<void> Function()? onRefresh;
  final bool hasDraw;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return _Refreshable(
        onRefresh: onRefresh,
        child: NoMatch(
          query: query,
          narrowing: narrowing,
          noun: noun,
          onAdd: onAddQuery == null ? null : () => onAddQuery!(query),
        ),
      );
    }
    return _Refreshable(
      onRefresh: onRefresh,
      scrolls: true,
      child: ScrollablePositionedList.builder(
        itemScrollController: scroller,
        itemPositionsListener: positions,
        // Overscroll for the pull to start in, however few rows stand
        // under it.
        physics: onRefresh == null
            ? null
            : const AlwaysScrollableScrollPhysics(),
        // Padding so the last row clears whatever stands over it.
        padding: EdgeInsets.only(bottom: hasDraw ? 156 : 88),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final name = nameOf(matches[index]);
          final row = rowOf(matches[index]);
          // Keyed outermost either way, so gaining the wash moves no row
          // and drops none of what one is standing on.
          return KeyedSubtree(
            key: ValueKey(name),
            child: name != washing
                ? row
                : _Wash(key: ValueKey(washes), onDone: onWashDone, child: row),
          );
        },
      ),
    );
  }
}

/// The drawn row saying which one it is, once the scroll has stopped moving
/// (FR-DIS-5): its fill starts at [ColorScheme.secondaryContainer] and settles
/// back to where every other row rests. Colour alone — a row changing height
/// would fire the very measurement the reveal waits on (ADR 13) — and the fill
/// is overridden at the one token `EntryCard` reads it from, so the card
/// keeps its shape, its margins and its ripple in the one place they are said.
///
/// [onDone] lets the wash go once it is spent: a row scrolled out of the list
/// and back would otherwise be built afresh and wash again, having said nothing
/// new.
class _Wash extends StatelessWidget {
  const _Wash({required this.onDone, required this.child, super.key});

  final VoidCallback onDone;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 1.0, end: 0.0),
    duration: Durations.extralong1,
    curve: Curves.easeOut,
    onEnd: onDone,
    builder: (context, wash, child) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Theme(
        data: theme.copyWith(
          colorScheme: colors.copyWith(
            surfaceContainer: Color.lerp(
              colors.surfaceContainer,
              colors.secondaryContainer,
              wash,
            ),
          ),
        ),
        child: child!,
      );
    },
    child: child,
  );
}
