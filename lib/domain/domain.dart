/// The domain layer's public surface — see docs/components.md.
library;

export 'src/availability.dart';
export 'src/discovery.dart';
export 'src/collection.dart' hide enumFromToken;
export 'src/collection_edits.dart';
export 'src/optimizer.dart';
export 'src/line_format.dart' hide reservedSuffixes, formatMeasure;
export 'src/names.dart' show nameKey, nameKeys, compareNames, NameComparison;
export 'src/scaling.dart';
export 'src/shelf.dart';
export 'src/shelf_edits.dart';
export 'src/validation.dart';
