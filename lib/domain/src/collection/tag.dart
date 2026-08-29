/// A tag in either vocabulary, and the rule a picked set narrows by (ADR-07).
library;

import '../names.dart';
import '../tokens.dart';

/// Tag color palette; green/amber/red reserved by stock and availability (ADR-07).
/// Every tag has a color; declaration order is the picker's order.
enum TagColor implements Tokened {
  teal('teal'),
  indigo('indigo'),
  plum('plum'),
  rose('rose'),
  sand('sand'),
  slate('slate');

  @override
  final String token;
  const TagColor(this.token);

  static TagColor? fromToken(String text) => enumFromToken(values, text);
}

/// Which vocabulary a tag belongs to; peers of one shape (ADR-07).
enum TagKind { recipe, ingredient }

/// A tag in either vocabulary; color is required (ADR-07).
final class Tag {
  final String name;
  final TagColor color;

  const Tag(this.name, {required this.color});

  Tag copyWith({String? name, TagColor? color}) =>
      Tag(name ?? this.name, color: color ?? this.color);

  @override
  bool operator ==(Object other) =>
      other is Tag && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'Tag($name, color: ${color.token})';
}

/// Tags [worn] names, in [vocabulary] order — matched through `nameKey` (ADR
/// 08), so a name recased in either survives, and one dropped from the
/// vocabulary simply no longer matches rather than the caller failing on it.
List<Tag> wornInOrder(List<Tag> vocabulary, Iterable<String> worn) {
  final names = nameKeys(worn);
  return [
    for (final tag in vocabulary)
      if (names.contains(nameKey(tag.name))) tag,
  ];
}
