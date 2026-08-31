/// One bar: its record, what it holds summed up, and its own coherence — a
/// record is what a bar costs while it is not on show
/// ([ADR 20](../../../../docs/adr/20-the-app-holds-many-bars.md)).
library;

import '../collection/collection.dart';
import '../collection/unit.dart';
import '../names.dart';
import '../shopping/shopping_settings.dart';
import '../tokens.dart';
import 'sharing.dart';

/// What this device is to a bar: its owner, or a guest reading another's
/// (FR-BAR-3).
enum BarMode implements Tokened {
  owner('owner'),
  guest('guest');

  @override
  final String token;
  const BarMode(this.token);

  static BarMode? fromToken(String text) => enumFromToken(values, text);
}

/// What a bar's file carries (ADR-21): the collection, and the name and
/// reading unit whoever establishes a bar from it starts out with.
typedef BarContent = ({String name, FixedUnit display, Collection collection});

/// Everything about one bar but its contents.
final class Bar {
  /// Minted on this device, unique on the shelf, never written to a bar's
  /// file. Compared exactly — an id is opaque, not a name (ADR-08's fold).
  final String id;

  /// A label — two bars may carry one (FR-BAR-1).
  final String name;
  final BarMode mode;

  /// The reader's pick, outliving every refresh (FR-SET-1, ADR-21).
  final FixedUnit display;

  /// The owner's, and kept here for the same reason (FR-SET-2, ADR-24); null
  /// on a guest, who neither asks the optimizer nor is asked to (ADR 21, ADR
  /// 24 amended).
  final ShoppingSettings? shopping;

  /// An owner's, one per way the bar is shared (FR-BAR-6).
  final List<Offer> offers;

  /// A guest's, with [refreshed] the last time it answered.
  final BarSource? source;
  final DateTime? refreshed;

  /// An owner's: when its contents last changed on this device. A guest's
  /// change only when its source answers, which [refreshed] already dates.
  final DateTime? updated;

  /// What the bar holds, kept beside the record so a list of bars costs no
  /// collection ([ADR 20](../../../../docs/adr/20-the-app-holds-many-bars.md)).
  /// Null where nothing has summarised it yet — an index written before the
  /// summary existed — which is the one state a reader repairs by summarising.
  final Map<Holding, int>? summary;

  Bar({
    required this.id,
    required this.name,
    required this.mode,
    this.display = FixedUnit.part,
    ShoppingSettings? shopping,
    List<Offer> offers = const [],
    this.source,
    this.refreshed,
    this.updated,
    Map<Holding, int>? summary,
  }) : shopping =
           shopping ??
           (mode == BarMode.owner ? const ShoppingSettings() : null),
       offers = List.unmodifiable(offers),
       summary = summary == null ? null : Map.unmodifiable(summary);

  bool get isOwned => mode == BarMode.owner;

  /// Whether this bar is shared by [via] right now (FR-BAR-6) — one offer per
  /// transport, so this is the whole of the question.
  bool offeredBy(Transport via) => offers.any((offer) => offer.via == via);

  /// The one rebuild behind [copyWith], [refreshedAt] and [summarised]: each
  /// restates only the field it means to change, id and mode never among
  /// them — a bar is the same bar, and whose it is arrives with it.
  Bar _copy({
    String? name,
    FixedUnit? display,
    ShoppingSettings? shopping,
    List<Offer>? offers,
    DateTime? refreshed,
    DateTime? updated,
    Map<Holding, int>? summary,
  }) => Bar(
    id: id,
    name: name ?? this.name,
    mode: mode,
    display: display ?? this.display,
    shopping: shopping ?? this.shopping,
    offers: offers ?? this.offers,
    source: source,
    refreshed: refreshed ?? this.refreshed,
    updated: updated ?? this.updated,
    summary: summary ?? this.summary,
  );

  /// What a copy may change, null meaning "keep". Neither stamp moves either
  /// — both date contents, and a copy that renames a bar has not touched them.
  Bar copyWith({
    String? name,
    FixedUnit? display,
    ShoppingSettings? shopping,
    List<Offer>? offers,
  }) => _copy(name: name, display: display, shopping: shopping, offers: offers);

  /// FR-BAR-5: the owner's contents as they just arrived, and when the source
  /// answered. The one writer of [refreshed], so a stamp cannot be dropped by a
  /// copy that meant to keep it. [name] and [display] are the reader's and are
  /// physically unreachable from here, so no refresh can lose either (ADR-21).
  Bar refreshedAt(Collection collection, DateTime at) =>
      _copy(refreshed: at, summary: summaryOf(collection));

  /// What the bar holds, counted afresh. The one writer of [updated] and —
  /// with [refreshedAt] — of [summary]. [at] is absent only where the
  /// contents did not just change: a first count is not an edit, so it dates
  /// nothing (absent means "keep", as everywhere else this rebuild reads).
  Bar summarised(Collection collection, {DateTime? at}) =>
      _copy(summary: summaryOf(collection), updated: at);

  @override
  bool operator ==(Object other) =>
      other is Bar &&
      other.id == id &&
      other.name == name &&
      other.mode == mode &&
      other.display == display &&
      other.shopping == shopping &&
      _sameOffers(other.offers, offers) &&
      other.source == source &&
      other.refreshed == refreshed &&
      other.updated == updated &&
      _sameSummary(other.summary, summary);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    mode,
    display,
    shopping,
    _offersHash(offers),
    source,
    refreshed,
    updated,
    _summaryHash(summary),
  );

  @override
  String toString() => 'Bar($id, $name, ${mode.token})';
}

/// The four kinds a collection is summed up by, recipes first: a reader tells
/// one collection from another by what it makes long before by the vocabulary
/// serving it. One home for the kinds, their order and what each is called, so
/// a bar card and an arriving file read alike.
enum Holding {
  recipe('recipe'),
  ingredient('ingredient'),
  tag('tag'),
  unit('unit');

  /// What a bar's summary is written under (ADR 21). Declared rather than the
  /// identifier, so renaming a kind cannot quietly rewrite the index's format —
  /// and independent of [noun], which is the reader's word and free to change.
  final String token;
  const Holding(this.token);

  String get noun => name;
}

/// How many of each [Holding], which is all a bar list may know of a bar that
/// is not on show ([ADR 20](../../../../docs/adr/20-the-app-holds-many-bars.md))
/// — four numbers rather than a second collection.
Map<Holding, int> summaryOf(Collection collection) => {
  Holding.recipe: collection.recipes.length,
  Holding.ingredient: collection.ingredients.length,
  // The one kind spanning two vocabularies, counted as the reader meets it:
  // one word for both, as `tags_screen.dart` lists them (ADR 07).
  Holding.tag: collection.recipeTags.length + collection.ingredientTags.length,
  Holding.unit: collection.units.length,
};

/// The mode decides which half of a record a bar may carry (FR-BAR-3/6). One
/// list; `Shelf`'s constructor throws the first entry and
/// shelf_validation.dart's `_checkRecord` reports every one, so a rule or its
/// wording changes once. [duplicate] is the only fact `_checkRecord` needs
/// back to place a [ValidationIssueKind] without this file naming one.
List<({List<Object> path, String message, bool duplicate})> coherenceProblems(
  Bar bar,
) => bar.isOwned ? _ownedProblems(bar) : _guestProblems(bar);

typedef _CoherenceProblem = ({
  List<Object> path,
  String message,
  bool duplicate,
});

List<_CoherenceProblem> _ownedProblems(Bar bar) {
  final problems = <_CoherenceProblem>[];
  if (bar.source != null) {
    problems.add((
      path: const ['source'],
      message: 'An owned bar refreshes from no source: "${bar.name}"',
      duplicate: false,
    ));
  }
  if (bar.refreshed != null) {
    problems.add((
      path: const ['refreshed'],
      message: 'An owned bar has nothing to refresh: "${bar.name}"',
      duplicate: false,
    ));
  }
  final vias = <Transport>{};
  for (var o = 0; o < bar.offers.length; o++) {
    final via = bar.offers[o].via;
    if (!vias.add(via)) {
      problems.add((
        path: ['offers', o],
        message: 'Bar offered twice by ${via.token}: "${bar.name}"',
        duplicate: true,
      ));
    }
  }
  return problems;
}

List<_CoherenceProblem> _guestProblems(Bar bar) {
  final problems = <_CoherenceProblem>[];
  if (bar.source == null) {
    problems.add((
      path: const ['source'],
      message: 'A guest bar needs the source it refreshes from: "${bar.name}"',
      duplicate: false,
    ));
  }
  for (var o = 0; o < bar.offers.length; o++) {
    problems.add((
      path: ['offers', o],
      message: 'A guest bar is not this device\'s to share: "${bar.name}"',
      duplicate: false,
    ));
  }
  if (bar.updated != null) {
    problems.add((
      path: const ['updated'],
      message: 'A guest bar changes only when it refreshes: "${bar.name}"',
      duplicate: false,
    ));
  }
  if (bar.shopping != null) {
    problems.add((
      path: const ['shopping'],
      message: 'A guest bar has no optimizer of its own: "${bar.name}"',
      duplicate: false,
    ));
  }
  return problems;
}

/// Offers compare part by part: a record holds its guest list by reference, so
/// two equal offers built apart would otherwise never read as equal.
bool _sameOffers(List<Offer> a, List<Offer> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].via != b[i].via || !listEquals(a[i].guests, b[i].guests)) {
      return false;
    }
  }
  return true;
}

int _offersHash(List<Offer> offers) => Object.hashAll([
  for (final offer in offers)
    Object.hash(offer.via, Object.hashAll(offer.guests)),
]);

/// A summary compares kind by kind, [Holding] being closed: two maps built
/// apart would otherwise never read as equal, and an unsummarised bar is
/// unequal to one counted as empty rather than the same thing said twice.
bool _sameSummary(Map<Holding, int>? a, Map<Holding, int>? b) {
  if (a == null || b == null) return a == null && b == null;
  return Holding.values.every((holding) => a[holding] == b[holding]);
}

int? _summaryHash(Map<Holding, int>? summary) => summary == null
    ? null
    : Object.hashAll([for (final holding in Holding.values) summary[holding]]);
