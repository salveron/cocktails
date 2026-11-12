/// Sharing vocabulary the domain owns, so `ui/` never reads past it (ADR-22).
library;

import '../tokens.dart';

/// Transports (FR-BAR-7/8); `cloud` is declared ahead of its adapter (ADR-22).
enum Transport implements Tokened {
  file('file'),
  lan('lan'),
  cloud('cloud');

  @override
  final String token;
  const Transport(this.token);

  static Transport? fromToken(String text) => enumFromToken(values, text);
}

/// Why a source did not answer (FR-BAR-5). Wording stays the UI's.
enum UnreachableReason { offline, notFound, withdrawn }

/// One way a bar is shared (FR-BAR-6); guests only if the transport names them.
typedef Offer = ({Transport via, List<String> guests});

/// A bar a browse found (FR-BAR-8); `name` is what its owner calls it.
typedef Found = ({BarSource source, String name});

/// Where a guest bar refreshes from (FR-BAR-5). [at] is opaque above data/.
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
