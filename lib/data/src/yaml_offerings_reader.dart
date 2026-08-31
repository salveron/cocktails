/// What a device says it offers, read off the wire rather than off disk
/// ([ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)).
library;

import 'package:yaml/yaml.dart';

import 'yaml_primitives.dart';
import 'yaml_writer.dart';

/// Every bar [yaml] offers, by id, or null where it is not a list this app
/// reads — malformed, of another `lan_format`, or missing what an entry needs.
/// A stranger wrote it and there is no reader to report an issue to, so it
/// answers yes or no; the version is gated first, turning a guest away at
/// discovery rather than part way through.
Map<String, Offering>? readOfferings(String yaml) {
  final YamlNode root;
  try {
    root = loadYamlNode(yaml);
  } on Exception {
    return null;
  }
  if (root is! YamlMap) return null;
  if (root.nodes['lan_format']?.value != lanFormatVersion) return null;
  final bars = root.nodes['bars'];
  if (bars is! YamlList) return null;
  final offerings = <String, Offering>{};
  for (final node in bars.nodes) {
    if (node is! YamlMap) return null;
    final id = asString(node['id']);
    final name = asString(node['name']);
    final path = asString(node['path']);
    if (id == null || name == null || path == null) return null;
    offerings[id] = (id: id, name: name, path: path);
  }
  return offerings;
}
