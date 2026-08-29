/// YAML tree → the parts of the shelf index; shape errors become issues at
/// data-format paths.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:yaml/yaml.dart';

import 'yaml_primitives.dart';

final class ShelfParts {
  final List<Bar> bars;
  final String? openId;
  final List<ValidationIssue> issues;

  ShelfParts({required this.bars, this.openId, required this.issues});
}

/// The index's records, built whatever they say: coherence between a record's
/// parts is `validateShelf`'s to report, and a `Bar` that refused to exist
/// could only be crashed on rather than told about (ADR 20).
ShelfParts readShelfParts(YamlMap root) {
  final issues = <ValidationIssue>[];
  checkKeys(root, const {'format', 'open', 'bars'}, const [], issues);
  // The key is written whether or not a bar is open, so a bare `open:` — a
  // YAML null — is a shelf with none on show rather than a malformed value.
  final open = root.nodes['open'];
  return ShelfParts(
    openId: open == null || open.value == null
        ? null
        : readText(root, 'open', const [], issues),
    bars: readEntries(root, 'bars', issues, _readBar),
    issues: issues,
  );
}

const _barKeys = {
  'id',
  'name',
  'mode',
  'display',
  'offers',
  'refreshed',
  'updated',
  'holds',
  'source',
  'shopping',
};

Bar? _readBar(YamlNode node, List<Object> path, List<ValidationIssue> issues) {
  final map = readMapping(node, path, issues, 'Bar entry', _barKeys);
  if (map == null) return null;
  final id = readText(map, 'id', path, issues, required: true);
  final name = readText(map, 'name', path, issues, required: true);
  final mode = readToken(
    map,
    'mode',
    path,
    issues,
    fromToken: BarMode.fromToken,
    values: BarMode.values,
    required: true,
  );
  final display = readDisplay(map, path, issues);
  final offers = _readOffers(map, path, issues);
  final refreshed = _readStamp(map, 'refreshed', path, issues);
  final updated = _readStamp(map, 'updated', path, issues);
  final source = _readSource(map.nodes['source'], [...path, 'source'], issues);
  final shopping = _readShopping(map.nodes['shopping'], [
    ...path,
    'shopping',
  ], issues);
  final summary = _readHolds(map.nodes['holds'], [...path, 'holds'], issues);
  if (id == null || name == null || mode == null) return null;
  return Bar(
    id: id,
    name: name,
    mode: mode,
    display: display,
    shopping: shopping,
    offers: offers,
    source: source,
    refreshed: refreshed,
    updated: updated,
    summary: summary,
  );
}

List<Offer> _readOffers(
  YamlMap node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final offers = <Offer>[];
  forEachEntry(node, 'offers', path, issues, (entryNode, entryPath) {
    final offer = _readOffer(entryNode, entryPath, issues);
    if (offer != null) offers.add(offer);
  });
  return offers;
}

/// What the optimizer is asked, key by key over the defaults (FR-SET-2, ADR
/// 24): a record written before any of it could be set carries none of them and
/// reads as the answer the app gave then. Null where the key is absent
/// altogether — an owner's own default and a guest's null are [Bar]'s to
/// supply, mode being what tells them apart (ADR 21, ADR 24). Whether the
/// numbers make sense, and whether a guest may carry one at all, is
/// `validateShelf`'s, this being the one place they are merely read.
ShoppingSettings? _readShopping(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  const standing = ShoppingSettings();
  const keys = {
    ShoppingSettings.aimToken,
    ShoppingSettings.budgetToken,
    ShoppingSettings.lowToken,
    ShoppingSettings.mostToken,
    ShoppingSettings.optionalToken,
  };
  final map = readMapping(node, path, issues, 'shopping', keys);
  if (map == null) return null;
  bool flag(String key, bool standing) =>
      readBool(map, key, path, issues) ?? standing;
  int count(String key, int standing) =>
      readInt(map, key, path, issues) ?? standing;
  return ShoppingSettings(
    aiming: flag(ShoppingSettings.aimToken, standing.aiming),
    budget: count(ShoppingSettings.budgetToken, standing.budget),
    restocking: flag(ShoppingSettings.lowToken, standing.restocking),
    keptPerSize: count(ShoppingSettings.mostToken, standing.keptPerSize),
    buyingOptional: flag(
      ShoppingSettings.optionalToken,
      standing.buyingOptional,
    ),
  );
}

DateTime? _readStamp(
  YamlMap node,
  String key,
  List<Object> path,
  List<ValidationIssue> issues,
) => readValue<DateTime>(
  node,
  key,
  path,
  issues,
  parse: (value) => DateTime.tryParse(asString(value) ?? '')?.toUtc(),
  requirement: '$key must be a UTC timestamp',
);

/// The summary, or null where it is not wholly there. It counts what a bar's
/// own file holds, so a half-read one is dropped rather than patched with
/// zeroes that would read as a bar holding nothing; the reader summarises the
/// file afresh instead (ADR 20).
Map<Holding, int>? _readHolds(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final map = readMapping(node, path, issues, 'holds', {
    for (final h in Holding.values) h.token,
  });
  if (map == null) return null;
  final holds = <Holding, int>{};
  for (final holding in Holding.values) {
    final count = readInt(map, holding.token, path, issues, atLeast: 0);
    if (count == null) return null;
    holds[holding] = count;
  }
  return holds;
}

Offer? _readOffer(
  YamlNode node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final map = readMapping(node, path, issues, 'Offer entry', const {
    'via',
    'guests',
  });
  if (map == null) return null;
  final via = _readTransport(map, path, issues);
  return via == null
      ? null
      : (via: via, guests: readNames(map, 'guests', path, issues, 'Guest'));
}

BarSource? _readSource(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  final map = readMapping(node, path, issues, 'source', const {
    'via',
    'at',
    'from',
  });
  if (map == null) return null;
  final via = _readTransport(map, path, issues);
  final at = readText(map, 'at', path, issues, required: true);
  final from = readText(map, 'from', path, issues, required: true);
  return via == null || at == null || from == null
      ? null
      : BarSource(via: via, at: at, from: from);
}

Transport? _readTransport(
  YamlMap node,
  List<Object> path,
  List<ValidationIssue> issues,
) => readToken(
  node,
  'via',
  path,
  issues,
  fromToken: Transport.fromToken,
  values: Transport.values,
  required: true,
);
