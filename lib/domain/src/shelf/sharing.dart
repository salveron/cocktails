/// How an owner shares a bar, why a guest's source might not answer, and what a
/// browse turns up — all here rather than beside the channel, `ui/` reading the
/// domain and no further down (ADR-22).
library;

import '../tokens.dart';

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
/// errors onto it and the wording stays the UI's.
enum UnreachableReason { offline, notFound, withdrawn }

/// One way an owner shares a bar, naming its guests where the transport can
/// name them and empty where it cannot (FR-BAR-6).
typedef Offer = ({Transport via, List<String> guests});

/// One bar a browse turned up (FR-BAR-8): where to keep it from, and what its
/// owner calls it — the device offering it being [BarSource.from]'s to say.
typedef Found = ({BarSource source, String name});

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
