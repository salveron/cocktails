/// The fixed units and the vocabulary a line's own is chosen from (ADR-09).
library;

import '../names.dart';
import '../tokens.dart';
import 'amount.dart';

/// The fixed units (FR-VOC-5): no rename, no delete, and the only ones a
/// measure converts between — `Bar.display` names the one they all read in
/// ([ADR 17](../../../../docs/adr/17-the-fixed-units-interconvert.md)).
enum FixedUnit implements Tokened {
  part(partUnit),
  ml(mlUnit),
  oz(ozUnit);

  @override
  final String token;
  const FixedUnit(this.token);

  static FixedUnit? fromToken(String text) => enumFromToken(values, text);

  /// The fixed unit [name] spells, or null where it is one of the reader's own.
  static FixedUnit? named(String name) {
    for (final unit in values) {
      if (unit.token.sameName(name)) return unit;
    }
    return null;
  }
}

/// One measure a line can be written in (ADR-09).
/// [plural] empty means plural reads the same as name.
final class Unit {
  final String name;
  final String plural;

  const Unit(this.name, {this.plural = ''});

  /// The plural as it reads; name itself where none was written.
  String get pluralName => plural.isEmpty ? name : plural;

  /// How [amount] is spelled: singular for one, plural otherwise.
  String spelling(Amount amount) =>
      amount == const Amount(1) ? name : pluralName;

  /// Whether [token] is one of its spellings, any case (ADR-08).
  bool answersTo(String token) =>
      name.sameName(token) || pluralName.sameName(token);

  @override
  bool operator ==(Object other) =>
      other is Unit && other.name == name && other.plural == plural;

  @override
  int get hashCode => Object.hash(name, plural);

  @override
  String toString() =>
      'Unit($name${plural.isEmpty ? '' : ', plural: $plural'})';
}

/// Default units; also used when a file names none.
const defaultUnits = [
  Unit(partUnit, plural: 'parts'),
  Unit(mlUnit),
  Unit(ozUnit),
  Unit('dash', plural: 'dashes'),
  Unit('barspoon', plural: 'barspoons'),
  Unit('drop', plural: 'drops'),
  Unit('piece', plural: 'pieces'),
];

/// The names [FixedUnit] is anchored to: an omitted unit is a part (FR-REC-2),
/// and the ratios convert between the three (FR-SET-1).
const partUnit = 'part';
const mlUnit = 'ml';
const ozUnit = 'oz';

bool isReservedUnit(String name) => FixedUnit.named(name) != null;

extension UnitLookup on List<Unit> {
  /// The unit [token] names; exact spellings answer first.
  Unit? unitNamed(String token) {
    for (final spelling in [
      token,
      if (token.endsWith('s')) token.substring(0, token.length - 1),
      if (token.endsWith('es')) token.substring(0, token.length - 2),
    ]) {
      for (final unit in this) {
        if (unit.answersTo(spelling)) return unit;
      }
    }
    return null;
  }

  /// Every spelling the vocabulary answers to, in order.
  List<String> get spellings => [
    for (final unit in this) ...[
      unit.name,
      if (!unit.pluralName.sameName(unit.name)) unit.pluralName,
    ],
  ];
}
