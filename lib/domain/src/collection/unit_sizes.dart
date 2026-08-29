/// What a part and an ounce are worth (FR-SET-1, ADR 21) — held in ml, the
/// anchor, so a ratio between any two is derived rather than stored (ADR 17).
library;

import 'unit.dart';

final class UnitSizes {
  final double partMl;
  final double ozMl;

  const UnitSizes({this.partMl = 30, this.ozMl = 29.5735});

  /// How many ml one [unit] is.
  double mlPer(FixedUnit unit) => switch (unit) {
    FixedUnit.part => partMl,
    FixedUnit.ml => 1,
    FixedUnit.oz => ozMl,
  };

  /// How many [to] one [from] is — the amounts screen's rows and a converted
  /// measure alike.
  double ratio(FixedUnit from, FixedUnit to) => mlPer(from) / mlPer(to);

  /// These sizes with one [from] made worth [n] of [to] — [ratio] written
  /// back, moving [to]'s size so redefining the part leaves the ounce alone.
  UnitSizes withRatio(FixedUnit from, FixedUnit to, double n) =>
      to == FixedUnit.ml ? _sized(from, n) : _sized(to, mlPer(from) / n);

  /// ml is the anchor — its size is 1 by definition, so there is none to set.
  UnitSizes _sized(FixedUnit unit, double ml) => switch (unit) {
    FixedUnit.part => copyWith(partMl: ml),
    FixedUnit.ml => this,
    FixedUnit.oz => copyWith(ozMl: ml),
  };

  UnitSizes copyWith({double? partMl, double? ozMl}) =>
      UnitSizes(partMl: partMl ?? this.partMl, ozMl: ozMl ?? this.ozMl);

  @override
  bool operator ==(Object other) =>
      other is UnitSizes && other.partMl == partMl && other.ozMl == ozMl;

  @override
  int get hashCode => Object.hash(partMl, ozMl);

  @override
  String toString() => 'UnitSizes($partMl ml/part, $ozMl ml/oz)';
}
