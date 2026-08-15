/// The shelf and the bars on it: the root above the collection
/// ([ADR 20](../../../docs/adr/20-the-app-holds-many-bars.md)). A record is
/// what a bar costs while it is not on show; the open bar's collection is the
/// only one resident, which is what makes "nothing crosses" (FR-BAR-1) a fact
/// rather than a rule. Coherence between a record's parts is Shelf's to keep,
/// so validation.dart can read an untrusted index into bars and report on it.
library;

import 'collection.dart';
import 'names.dart';

/// What this device is to a bar: its owner, or a guest reading another's
/// (FR-BAR-3).
enum BarMode {
  owner('owner'),
  guest('guest');

  final String token;
  const BarMode(this.token);

  static BarMode? fromToken(String text) =>
      enumFromToken(values, text, (v) => v.token);
}

/// A way a bar travels (FR-BAR-7/8/9). `cloud` is declared ahead of its adapter
/// so the index's format need not move when one lands (ADR-22).
enum Transport {
  file('file'),
  lan('lan'),
  cloud('cloud');

  final String token;
  const Transport(this.token);

  static Transport? fromToken(String text) =>
      enumFromToken(values, text, (v) => v.token);
}

/// One way an owner shares a bar, naming its guests where the transport can
/// name them and empty where it cannot (FR-BAR-6).
typedef Offer = ({Transport via, List<String> guests});

/// What a bar's file carries (ADR-21): the owner's name for it, the reading
/// unit whoever establishes it starts from, and the collection. Mode, source,
/// refresh time and id are the device's and never travel.
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
    List<Offer> offers = const [],
    this.source,
    this.refreshed,
    this.updated,
    Map<Holding, int>? holds,
  }) : offers = List.unmodifiable(offers),
       holds = holds == null ? null : Map.unmodifiable(holds);

  bool get isOwned => mode == BarMode.owner;

  /// What a copy may change, and nothing else: null means "keep", so a field
  /// that can be absent would read as unclearable here. Id and mode are not a
  /// copy's to move either — a bar is the same bar, and whose it is arrives
  /// with it. Neither stamp is a copy's to move: both date contents, and a
  /// copy that renames a bar has not touched them.
  Bar copyWith({String? name, FixedUnit? display, List<Offer>? offers}) => Bar(
    id: id,
    name: name ?? this.name,
    mode: mode,
    display: display ?? this.display,
    offers: offers ?? this.offers,
    source: source,
    refreshed: refreshed,
    updated: updated,
    holds: holds,
  );

  /// FR-BAR-5: the owner's name and contents as they just arrived, and when the
  /// source answered. The one writer of [refreshed], so a stamp cannot be
  /// dropped by a copy that meant to keep it.
  Bar refreshedAt(String name, Collection collection, DateTime at) => Bar(
    id: id,
    name: name,
    mode: mode,
    display: display,
    offers: offers,
    source: source,
    refreshed: at,
    holds: holdingsOf(collection),
  );

  /// What the bar holds, counted afresh. The one writer of [updated] and —
  /// with [refreshedAt] — of [holds], so a summary is never a step behind the
  /// contents it counts. [at] is the moment the contents became these, and is
  /// absent only where they did not just change: a bar being summarised for
  /// the first time is being counted, not edited, and inventing a stamp for it
  /// would date an edit nobody made.
  Bar summarised(Collection collection, {DateTime? at}) => Bar(
    id: id,
    name: name,
    mode: mode,
    display: display,
    offers: offers,
    source: source,
    refreshed: refreshed,
    updated: at ?? updated,
    holds: holdingsOf(collection),
  );

  @override
  bool operator ==(Object other) =>
      other is Bar &&
      other.id == id &&
      other.name == name &&
      other.mode == mode &&
      other.display == display &&
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
/// refreshes from nothing (FR-BAR-3/6).
void _requireCoherent(Bar bar) {
  if (bar.isOwned) {
    if (bar.source != null || bar.refreshed != null) {
      throw ArgumentError('An owned bar refreshes from nothing: "${bar.name}"');
    }
    final vias = <Transport>{};
    for (final offer in bar.offers) {
      if (!vias.add(offer.via)) {
        throw ArgumentError(
          'Bar "${bar.name}" is offered twice by ${offer.via.token}',
        );
      }
    }
  } else {
    if (bar.source == null) {
      throw ArgumentError(
        'A guest bar carries the source it refreshes from: "${bar.name}"',
      );
    }
    if (bar.offers.isNotEmpty) {
      throw ArgumentError(
        'A guest bar is not this device\'s to share: '
        '"${bar.name}"',
      );
    }
    if (bar.updated != null) {
      throw ArgumentError(
        'A guest bar changes only when it refreshes: "${bar.name}"',
      );
    }
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
