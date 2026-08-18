/// The shelf and the bars on it: the root above the collection
/// ([ADR 20](../../../docs/adr/20-the-app-holds-many-bars.md)). A record is
/// what a bar costs while it is not on show; the open bar's collection is the
/// only one resident, which is what makes "nothing crosses" (FR-BAR-1) a fact
/// rather than a rule. Coherence between a record's parts is Shelf's to keep,
/// so validation.dart can read an untrusted index into bars and report on it.
library;

import 'collection.dart';
import 'names.dart';
import 'optimizer.dart';

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

/// A way a bar travels (FR-BAR-7/8/9). `cloud` is declared ahead of its adapter
/// so the index's format need not move when one lands (ADR-22).
enum Transport implements Tokened {
  file('file'),
  lan('lan'),
  cloud('cloud');

  @override
  final String token;
  const Transport(this.token);

  static Transport? fromToken(String text) => enumFromToken(values, text);
}

/// Why a source did not answer (FR-BAR-5). Closed, so an adapter maps its own
/// errors onto it and the wording stays the UI's (ADR-22) — which is why it
/// sits here rather than beside the channel raising it: `ui/` reads the domain.
enum UnreachableReason { offline, notFound, withdrawn }

/// One way an owner shares a bar, naming its guests where the transport can
/// name them and empty where it cannot (FR-BAR-6).
typedef Offer = ({Transport via, List<String> guests});

/// What a bar's file carries (ADR-21): the collection, and the name and reading
/// unit whoever establishes a bar from it starts out with — both theirs from
/// then on, so neither returns on a refresh. Mode, source, refresh time and id
/// are the device's and never travel.
typedef BarPayload = ({String name, FixedUnit display, Collection collection});

/// Where a guest bar refreshes from (FR-BAR-5). [at] is the transport's own
/// address, opaque above data/; [from] is what to call it where a source reads.
final class BarSource {
  final Transport via;
  final String at;
  final String from;

  const BarSource({required this.via, required this.at, required this.from});

  @override
  bool operator ==(Object other) =>
      other is BarSource &&
      other.via == via &&
      other.at == at &&
      other.from == from;

  @override
  int get hashCode => Object.hash(via, at, from);

  @override
  String toString() => 'BarSource(${via.token}, from: $from)';
}

/// Everything about one bar but its contents.
final class Bar {
  /// Minted on this device, unique on the shelf, never written to a bar's file.
  /// Compared exactly: an id is opaque rather than a name, so ADR-08's fold is
  /// not its rule.
  final String id;

  /// A label — two bars may carry one (FR-BAR-1).
  final String name;
  final BarMode mode;

  /// The reader's pick, outliving every refresh (FR-SET-1, ADR-21).
  final FixedUnit display;

  /// The reader's too, and kept here for the same reason (FR-SET-2, ADR-24).
  final Shopping shopping;

  /// An owner's, one per way the bar is shared (FR-BAR-6).
  final List<Offer> offers;

  /// A guest's, with [refreshed] the last time it answered.
  final BarSource? source;
  final DateTime? refreshed;

  /// An owner's: when its contents last changed on this device. A guest's
  /// change only when its source answers, which [refreshed] already dates.
  final DateTime? updated;

  /// What the bar holds, kept beside the record so a list of bars costs no
  /// collection ([ADR 20](../../../docs/adr/20-the-app-holds-many-bars.md)).
  /// Null where nothing has summarised it yet — an index written before the
  /// summary existed — which is the one state a reader repairs by summarising.
  final Map<Holding, int>? holds;

  Bar({
    required this.id,
    required this.name,
    required this.mode,
    this.display = FixedUnit.part,
    this.shopping = const Shopping(),
    List<Offer> offers = const [],
    this.source,
    this.refreshed,
    this.updated,
    Map<Holding, int>? holds,
  }) : offers = List.unmodifiable(offers),
       holds = holds == null ? null : Map.unmodifiable(holds);

  bool get isOwned => mode == BarMode.owner;

  /// The one rebuild behind [copyWith], [refreshedAt] and [summarised]: each
  /// restates only the field it means to change, id and mode never among
  /// them — a bar is the same bar, and whose it is arrives with it.
  Bar _copy({
    String? name,
    FixedUnit? display,
    Shopping? shopping,
    List<Offer>? offers,
    DateTime? refreshed,
    DateTime? updated,
    Map<Holding, int>? holds,
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
    holds: holds ?? this.holds,
  );

  /// What a copy may change, and nothing else: null means "keep", so a field
  /// that can be absent would read as unclearable here. Neither stamp is a
  /// copy's to move either: both date contents, and a copy that renames a bar
  /// has not touched them.
  Bar copyWith({
    String? name,
    FixedUnit? display,
    Shopping? shopping,
    List<Offer>? offers,
  }) => _copy(name: name, display: display, shopping: shopping, offers: offers);

  /// FR-BAR-5: the owner's contents as they just arrived, and when the source
  /// answered. The one writer of [refreshed], so a stamp cannot be dropped by a
  /// copy that meant to keep it. [name] and [display] are the reader's and are
  /// physically unreachable from here, so no refresh can lose either (ADR-21).
  Bar refreshedAt(Collection collection, DateTime at) =>
      _copy(refreshed: at, holds: holdingsOf(collection));

  /// What the bar holds, counted afresh. The one writer of [updated] and —
  /// with [refreshedAt] — of [holds], so a summary is never a step behind the
  /// contents it counts. [at] is the moment the contents became these, and is
  /// absent only where they did not just change: a bar being summarised for
  /// the first time is being counted, not edited, and inventing a stamp for it
  /// would date an edit nobody made — so absent here means "keep", same as
  /// everywhere else this rebuild is read from.
  Bar summarised(Collection collection, {DateTime? at}) =>
      _copy(holds: holdingsOf(collection), updated: at);

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
      _sameHoldings(other.holds, holds);

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
    _holdingsHash(holds),
  );

  @override
  String toString() => 'Bar($id, $name, ${mode.token})';
}

/// Every bar the device holds, which one is open, and that one's collection.
final class Shelf {
  final List<Bar> bars;

  /// The bar on show; null on a first run and once the last bar is deleted.
  final String? openId;

  /// The open bar's, and an empty collection while none is open — a state no
  /// screen can read, the shell offering no destination without a bar.
  final Collection collection;

  Shelf({List<Bar> bars = const [], this.openId, Collection? collection})
    : bars = List.unmodifiable(bars),
      collection = collection ?? Collection() {
    final seen = <String>{};
    for (final bar in this.bars) {
      if (!seen.add(bar.id)) {
        throw ArgumentError('Duplicate bar id: "${bar.id}"');
      }
      _requireCoherent(bar);
    }
    if (openId != null && !seen.contains(openId)) {
      throw ArgumentError('Open bar is not on the shelf: "$openId"');
    }
  }

  Bar? get open {
    final id = openId;
    return id == null ? null : barWithId(id);
  }

  Bar? barWithId(String id) => _barsById[id];

  /// What a copy may change, and nothing else: null means "keep". Closing the
  /// shelf — [openId] cleared, [collection] reset — is [Shelf]'s own default
  /// state rather than a copy's to reach; `withoutBar` builds that directly.
  Shelf copyWith({List<Bar>? bars, String? openId, Collection? collection}) =>
      Shelf(
        bars: bars ?? this.bars,
        openId: openId ?? this.openId,
        collection: collection ?? this.collection,
      );

  late final Map<String, Bar> _barsById = {for (final bar in bars) bar.id: bar};

  @override
  bool operator ==(Object other) =>
      other is Shelf &&
      listEquals(other.bars, bars) &&
      other.openId == openId &&
      other.collection == collection;

  @override
  int get hashCode => Object.hash(Object.hashAll(bars), openId, collection);

  @override
  String toString() => 'Shelf(${bars.length} bars, open: $openId)';
}

/// The mode decides which half of a record a bar may carry: a guest refreshes
/// from a source and has nothing of its own to give away, an owner shares and
/// refreshes from nothing (FR-BAR-3/6). One list; [_requireCoherent] throws
/// the first entry, and validation.dart's `_checkRecord` reports every one —
/// so a rule, or its wording, changes in one place rather than two.
/// [duplicate] is the only fact `_checkRecord` needs back to place a
/// [ValidationIssueKind] without this file naming one.
List<({List<Object> path, String message, bool duplicate})> coherenceProblems(
  Bar bar,
) {
  final problems = <({List<Object> path, String message, bool duplicate})>[];
  if (bar.isOwned) {
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
  } else {
    if (bar.source == null) {
      problems.add((
        path: const ['source'],
        message:
            'A guest bar needs the source it refreshes from: "${bar.name}"',
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
  }
  return problems;
}

void _requireCoherent(Bar bar) {
  final problems = coherenceProblems(bar);
  if (problems.isNotEmpty) {
    throw ArgumentError(problems.first.message);
  }
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
bool _sameHoldings(Map<Holding, int>? a, Map<Holding, int>? b) {
  if (a == null || b == null) return a == null && b == null;
  return Holding.values.every((holding) => a[holding] == b[holding]);
}

int? _holdingsHash(Map<Holding, int>? holds) => holds == null
    ? null
    : Object.hashAll([for (final holding in Holding.values) holds[holding]]);
