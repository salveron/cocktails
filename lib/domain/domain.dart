/// The domain layer's public surface — see docs/components.md.
library;

export 'src/availability.dart';
export 'src/collection.dart' hide enumFromToken;
export 'src/collection_edits.dart';
export 'src/discovery.dart';
export 'src/line_format.dart' hide reservedSuffixes, measureText;
export 'src/names.dart' show nameKey, nameKeys, compareNames, NameComparison;
export 'src/optimizer.dart';
export 'src/scaling.dart';
export 'src/shelf.dart';
export 'src/shelf_edits.dart';
export 'src/shelf_validation.dart';
export 'src/validation.dart' hide checkName, addProblems, Problem;
