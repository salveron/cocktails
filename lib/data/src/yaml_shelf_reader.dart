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
  if (node is! YamlMap) {
    report(issues, path, 'Bar entry must be a mapping', node);
    return null;
  }
  checkKeys(node, _barKeys, path, issues);
  final id = readText(node, 'id', path, issues, required: true);
  final name = readText(node, 'name', path, issues, required: true);
  final mode = readToken(
    node,
    'mode',
    path,
    issues,
    fromToken: BarMode.fromToken,
    values: BarMode.values,
    required: true,
  );
  final display = readDisplay(node, path, issues);
  final offers = _readOffers(node, path, issues);
  final refreshed = _readStamp(node, 'refreshed', path, issues);
  final updated = _readStamp(node, 'updated', path, issues);
  final source = _readSource(node.nodes['source'], [...path, 'source'], issues);
  final shopping = _readShopping(node.nodes['shopping'], [
    ...path,
    'shopping',
  ], issues);
  final summary = _readHolds(node.nodes['holds'], [...path, 'holds'], issues);
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
/// reads as the answer the app gave then. Whether the numbers make sense is
/// `validateShelf`'s, this being the one place they are merely read.
ShoppingSettings _readShopping(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  const standing = ShoppingSettings();
  if (node == null) return standing;
  if (node is! YamlMap) {
    report(issues, path, 'shopping must be a mapping', node);
    return standing;
  }
  const keys = {'aim', 'budget', 'low', 'most', 'optional'};
  checkKeys(node, keys, path, issues);
  bool flag(String key, bool standing) =>
      readBool(node, key, path, issues) ?? standing;
  int count(String key, int standing) =>
      readInt(node, key, path, issues) ?? standing;
  return ShoppingSettings(
    aiming: flag('aim', standing.aiming),
    budget: count('budget', standing.budget),
    restocking: flag('low', standing.restocking),
    keptPerSize: count('most', standing.keptPerSize),
    buyingOptional: flag('optional', standing.buyingOptional),
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
  if (node == null) return null;
  if (node is! YamlMap) {
    report(issues, path, 'holds must be a mapping', node);
    return null;
  }
  checkKeys(node, {for (final h in Holding.values) h.token}, path, issues);
  final holds = <Holding, int>{};
  for (final holding in Holding.values) {
    final count = readInt(node, holding.token, path, issues, atLeast: 0);
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
  if (node is! YamlMap) {
    report(issues, path, 'Offer entry must be a mapping', node);
    return null;
  }
  checkKeys(node, const {'via', 'guests'}, path, issues);
  final via = _readTransport(node, path, issues);
  return via == null
      ? null
      : (via: via, guests: readNames(node, 'guests', path, issues, 'Guest'));
}

BarSource? _readSource(
  YamlNode? node,
  List<Object> path,
  List<ValidationIssue> issues,
) {
  if (node == null) return null;
  if (node is! YamlMap) {
    report(issues, path, 'source must be a mapping', node);
    return null;
  }
  checkKeys(node, const {'via', 'at', 'from'}, path, issues);
  final via = _readTransport(node, path, issues);
  final at = readText(node, 'at', path, issues, required: true);
  final from = readText(node, 'from', path, issues, required: true);
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
