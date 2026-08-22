/// The one list every vocabulary is drawn as — the ingredients and both tag
/// tabs alike (docs/ui-design.md#vocabulary-editing).
library;

import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'empty_state.dart';
import 'search_field.dart';
import 'tag_choices.dart';

String counted(int count, String noun) =>
    '$count $noun${count == 1 ? '' : 's'}';

/// The orders a list can be read in — a label each, and where it ranks an
/// entry — first the one the list opens in (docs/ui-design.md#searchable-lists).
/// Ranks come off the domain's own enums, whose declaration order is already
/// the traffic light and the palette.
typedef ListOrders<T> = Map<String, int Function(T entry)>;

const alphabetical = {'Name': _alike};

int _alike(Object? entry) => 0;

extension ToggleMembership<T> on Set<T> {
  void toggle(T value) {
    if (!remove(value)) add(value);
  }
}

/// Controls to narrow list: row widget, test function, human description, and
/// [picks] — what is chosen, spelled out, which is what tells one narrowing
/// from another where the sentence a reader is shown cannot.
typedef ListFilter<T> = ({
  Widget row,
  bool Function(T entry) test,
  String? narrowing,
  List<String> picks,
});

/// The button over a list that draws one of the rows on show — the recipes'
/// random pick (FR-DIS-5). It answers with the name to put on screen, or null
/// where it drew nothing, so a screen never learns where a row stands or how
/// the list scrolls to it (ADR 13).
///
/// [icon] is the drawn glyph rather than an `IconData`, since one off a font
/// whose glyphs are not square is drawn by its own widget (ADR 14) — so the
/// screen picking the glyph is the only place that font is named.
typedef ListDraw<T> = ({
  Widget icon,
  String tooltip,
  String? Function(List<T> onShow) draw,
});

/// The tag row a list narrows by — the ingredients and the recipes alike
/// (FR-ING-3, FR-DIS-3): chips that double as the legend for the dots on the
/// rows, and an entry kept only where it wears every one picked. A vocabulary
/// with nothing in it has no row and narrows nothing.
///
/// [picked] is read against [vocabulary] through `wornInOrder` rather than
/// trusted, so a tag deleted or renamed elsewhere stops narrowing rather than
/// emptying the list, while one renamed only in its case goes on narrowing (ADR
/// 08). That is the one home for reading picks against a vocabulary — the
/// shopping card marks its recipes with the picks they answer off the same
/// rule, so nothing is ever dotted by a pick that has stopped narrowing.
///
/// The test folds both sides, because they come from different places: [chosen]
/// carries the vocabulary's spelling, [tagsOf] the entry's own. A file the app
/// exported and a hand then recased — which `validateCollection` accepts, tag
/// references being resolved by the fold — would otherwise drop that entry off
/// its own chip.
///
/// [leading] is a narrowing the screen builds itself — the recipes' base spirit
/// (ADR 12). Its row stands first among the chips, in the one scroller, and its
/// reason joins the tags' in the one message; a vocabulary with nothing in it
/// still draws it.
ListFilter<T>? tagFilter<T>({
  required List<Tag> vocabulary,
  required Set<String> picked,
  required void Function(String tag) onToggle,
  required List<String> Function(T entry) tagsOf,
  ListFilter<T>? leading,
}) {
  if (vocabulary.isEmpty && leading == null) return null;
  final chosen = {for (final tag in wornInOrder(vocabulary, picked)) tag.name};
  final wanted = nameKeys(chosen);
  final reasons = [
    ?leading?.narrowing,
    if (chosen.isNotEmpty) 'every tag picked',
  ];
  return (
    row: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TagChoices(
        vocabulary: vocabulary,
        chosen: chosen,
        onToggle: onToggle,
        scrolling: true,
        leading: leading?.row,
      ),
    ),
    test: (entry) =>
        (leading?.test(entry) ?? true) &&
        (wanted.isEmpty || nameKeys(tagsOf(entry)).containsAll(wanted)),
    narrowing: reasons.isEmpty ? null : reasons.join(' and '),
    picks: [...?leading?.picks, ...chosen],
  );
}

/// Single vocab row with optional body; ripple clipped to card corners.
class VocabularyRow extends StatelessWidget {
  const VocabularyRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.body,
    this.onTap,
    this.margin = listMargin,
    super.key,
  });

  /// What a list insets its rows by, and what a form standing them among its
  /// own fields overrides — a form pads its whole page already, so a row
  /// keeping this would sit narrower than every field above it.
  static const listMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  final Widget title;
  final Widget? subtitle;
  final Widget? body;

  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets margin;

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
      margin: margin,
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

/// A [VocabularyRow] that opens in place: [subtitle] shown only while
/// collapsed unless [hideSubtitleWhenOpen] says otherwise (bars_screen keeps
/// its standing line either way), [body] only while [open]. Built regardless
/// of [open] — a body no reader can see costs nothing unlaid-out.
class ExpandingRow extends StatelessWidget {
  const ExpandingRow({
    required this.open,
    required this.title,
    this.subtitle,
    this.hideSubtitleWhenOpen = true,
    this.trailing,
    this.body,
    this.onToggle,
    this.margin = VocabularyRow.listMargin,
    super.key,
  });

  final bool open;
  final Widget title;
  final String? subtitle;
  final bool hideSubtitleWhenOpen;
  final Widget? trailing;
  final Widget? body;
  final VoidCallback? onToggle;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return VocabularyRow(
      margin: margin,
      title: title,
      subtitle: subtitle == null || (open && hideSubtitleWhenOpen)
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      body: open ? body : null,
      onTap: onToggle,
    );
  }
}

typedef Bullet = ({String name, Widget? trailing});

/// One stretch of bullets under a heading, the heading being null wherever the
/// run stands alone and needs none. [onTap] is where the run's names are kept —
/// one destination for the run, a run being the names of a single kind (ADR 19).
typedef BulletRun = ({
  String? label,
  List<Bullet> bullets,
  void Function(String name)? onTap,
});

BulletRun bulletRun(Iterable<String> names, {String? label}) => (
  label: label,
  bullets: [for (final name in names) (name: name, trailing: null)],
  onTap: null,
);

/// Every name a [VocabularyRow]'s body counts, bulleted under the run it falls
/// in — an arriving file's vocabularies (ADR 07) and a basket's two halves
/// alike. An empty run is left out rather than standing as a heading over
/// nothing.
class BulletRuns extends StatelessWidget {
  const BulletRuns(this.runs, {super.key});

  final List<BulletRun> runs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final run in runs.where((run) => run.bullets.isNotEmpty)) ...[
        if (run.label case final label?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        for (final bullet in run.bullets) _bullet(run, bullet),
      ],
    ],
  );

  Widget _bullet(BulletRun run, Bullet bullet) {
    final line = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Flexible(child: Text('• ${bullet.name}')),
          if (bullet.trailing case final mark?)
            Padding(padding: const EdgeInsets.only(left: 6), child: mark),
        ],
      ),
    );
    final onTap = run.onTap;
    return onTap == null
        ? line
        : InkWell(onTap: () => onTap(bullet.name), child: line);
  }
}

class RowMenu extends StatelessWidget {
  const RowMenu(this.actions, {super.key});

  final Map<String, VoidCallback> actions;

  /// Nothing at all where nothing is offered, so a guest bar's rows lose the ⋮
  /// rather than gaining one that opens onto an empty menu (FR-BAR-4). Here
  /// rather than in each caller: a row builds the actions its bar allows and
  /// says nothing about whether any survived.
  @override
  Widget build(BuildContext context) => actions.isEmpty
      ? const SizedBox.shrink()
      : PopupMenuButton<VoidCallback>(
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
  final ListDraw<T>? draw;

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
  State<VocabularyList<T>> createState() => _VocabularyListState<T>();
}

class _VocabularyListState<T> extends State<VocabularyList<T>> {
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
  void didUpdateWidget(covariant VocabularyList<T> oldWidget) {
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
    return Scaffold(
      body: widget.entries.isEmpty
          ? _refreshable(widget.empty)
          : _searchable(add, _shown),
      floatingActionButton: _buttons(add, _shown),
    );
  }

  /// [child] under the pull that refreshes, where one is offered. Wrapped
  /// around what scrolls rather than around the search standing over it, that
  /// being where the reader pulls. A body with nothing to scroll is given
  /// something: an empty bar is exactly where the gesture is the only way to
  /// ask a source at all, so it must answer there too.
  Widget _refreshable(Widget child, {bool scrolls = false}) {
    final onRefresh = widget.onRefresh;
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

  /// What stands over the list: the draw above the add, the two alike in size
  /// so neither reads as the lesser reach. The draw keeps away while there is
  /// nothing on show to draw from.
  Widget? _buttons(Future<bool> Function(String query)? add, List<T> onShow) {
    final draw = widget.draw;
    if (add == null && draw == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (draw != null && onShow.isNotEmpty) ...[
          FloatingActionButton(
            heroTag: null,
            onPressed: () => _draw(draw, onShow),
            tooltip: draw.tooltip,
            child: draw.icon,
          ),
          const SizedBox(height: 12),
        ],
        if (add != null)
          FloatingActionButton(
            // Avoid hero tag collision (multiple FABs coexist).
            heroTag: null,
            onPressed: () => unawaited(_add(add, '')),
            tooltip: 'Add ${widget.noun}',
            child: const Icon(Icons.add),
          ),
      ],
    );
  }

  /// Draws one of the rows on show, leaving it to [_reach] to put on screen —
  /// the one place a name becomes an index, and the only thing here that knows
  /// the list scrolls at all (ADR 13).
  void _draw(ListDraw<T> draw, List<T> onShow) {
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

  Widget _searchable(
    Future<bool> Function(String query)? add,
    List<T> matches,
  ) {
    final filter = widget.filter;
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
              ? _refreshable(
                  _NoMatch(
                    query: query,
                    narrowing: filter?.narrowing,
                    noun: widget.noun,
                    onAdd: add == null
                        ? null
                        : () => unawaited(_add(add, query)),
                  ),
                )
              : _refreshable(
                  scrolls: true,
                  ScrollablePositionedList.builder(
                    itemScrollController: _scroller,
                    itemPositionsListener: _positions,
                    // Overscroll for the pull to start in, however few rows
                    // stand under it.
                    physics: widget.onRefresh == null
                        ? null
                        : const AlwaysScrollableScrollPhysics(),
                    // Padding so the last row clears whatever stands over it.
                    padding: EdgeInsets.only(
                      bottom: widget.draw == null ? 88 : 156,
                    ),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final name = widget.nameOf(matches[index]);
                      final row = widget.rowOf(matches[index]);
                      // Keyed outermost either way, so gaining the wash moves no
                      // row and drops none of what one is standing on.
                      return KeyedSubtree(
                        key: ValueKey(name),
                        child: name != _washing
                            ? row
                            : _Wash(
                                key: ValueKey(_washes),
                                onDone: () => setState(() => _washing = null),
                                child: row,
                              ),
                      );
                    },
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
      final rank = widget.orders[_order] ?? _alike;
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

/// The drawn row saying which one it is, once the scroll has stopped moving
/// (FR-DIS-5): its fill starts at [ColorScheme.secondaryContainer] and settles
/// back to where every other row rests. Colour alone — a row changing height
/// would fire the very measurement the reveal waits on (ADR 13) — and the fill
/// is overridden at the one token [VocabularyRow] reads it from, so the card
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
