// Enforces docs/components.md "Boundary rules" (docs/adr/04-module-boundaries.md):
// reads the dependency directives under lib/ and fails on any violation, and
// pins the dependency list in docs/architecture.md to pubspec.yaml. Needs
// nothing beyond dart:io and the test harness (an explicit ADR 04 decision).
//
// `export` is checked alongside `import`, and more strictly: under the barrel
// pattern a barrel publishes its own layer's contract, so re-exporting another
// layer — even one this layer may legally import — would hand that layer's
// surface to everyone downstream and open a transitive route around the rules.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _layers = ['domain', 'data', 'state', 'ui'];

/// Layers a file in [key] may depend on, of the app's own layers.
const _allowedLayerDeps = {
  'domain': <String>{},
  'data': {'domain'},
  'state': {'domain', 'data'},
  'ui': {'domain', 'state'},
};

typedef _Directive = ({String kind, String target});

/// The layer folder a lib-relative path belongs to, or null for files
/// outside every layer (lib/main.dart).
String? _layerOf(String libPath) {
  for (final layer in _layers) {
    if (libPath.startsWith('$layer/')) return layer;
  }
  return null;
}

/// Every `import` and `export` directive in [source], ignoring commented-out
/// lines and any `show`/`hide` combinator. Line-based, so a directive wrapped
/// across lines is missed — `dart format` never produces one, and CI runs the
/// formatter check.
List<_Directive> _directivesOf(String source) {
  final pattern = RegExp(r'''^(import|export)\s+['"]([^'"]+)['"]''');
  final directives = <_Directive>[];
  for (final line in source.split('\n')) {
    final match = pattern.firstMatch(line.trimLeft());
    if (match != null) {
      directives.add((kind: match.group(1)!, target: match.group(2)!));
    }
  }
  return directives;
}

/// Resolves a relative import [target] against the importing file's own
/// lib-relative path.
String _resolveRelative(String fromLibPath, String target) {
  final fromDir = fromLibPath.contains('/')
      ? fromLibPath.substring(0, fromLibPath.lastIndexOf('/'))
      : '';
  final parts = [...fromDir.split('/'), ...target.split('/')];
  final resolved = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (resolved.isNotEmpty) resolved.removeLast();
    } else {
      resolved.add(part);
    }
  }
  return resolved.join('/');
}

/// The lib-relative path a directive [target] resolves to, or null when it is
/// external (`package:`/`dart:` outside this app's own package).
String? _targetLibPath(String fromLibPath, String target) {
  if (target.startsWith('package:cocktails/')) {
    return target.substring('package:cocktails/'.length);
  }
  if (target.contains(':')) return null;
  return _resolveRelative(fromLibPath, target);
}

/// Every boundary violation [libPath] commits through [directives], each
/// message naming the offending file and directive target.
List<String> _violations(String libPath, List<_Directive> directives) {
  final fileLayer = _layerOf(libPath);
  final violations = <String>[];

  for (final directive in directives) {
    final target = directive.target;
    if (fileLayer == 'domain' &&
        (target.startsWith('package:flutter/') ||
            target == 'dart:io' ||
            target.startsWith('dart:ui'))) {
      violations.add('$libPath depends on $target: domain must stay pure Dart');
      continue;
    }

    final targetPath = _targetLibPath(libPath, target);
    if (targetPath == null) continue;
    final targetLayer = _layerOf(targetPath);
    if (targetLayer == null) continue;

    if (targetLayer == fileLayer) {
      if (targetPath.contains('/src/') &&
          target.startsWith('package:cocktails/')) {
        violations.add(
          '$libPath depends on $target: same-layer src must be relative',
        );
      }
      continue;
    }

    if (directive.kind == 'export') {
      violations.add(
        '$libPath re-exports $target: a barrel publishes its own layer only',
      );
      continue;
    }

    // lib/main.dart is outside every layer: the composition root may reach
    // any layer, but only its public files — ui/ has no barrel, so its
    // leaves are imported directly (docs/components.md module map).
    if (fileLayer == null) {
      if (targetPath.contains('/src/')) {
        violations.add(
          '$libPath depends on $target: $targetLayer/src/ is layer-private',
        );
      }
      continue;
    }

    if (!_allowedLayerDeps[fileLayer]!.contains(targetLayer)) {
      violations.add(
        '$libPath depends on $target: $fileLayer must not depend on '
        '$targetLayer',
      );
      continue;
    }

    if (targetPath != '$targetLayer/$targetLayer.dart') {
      violations.add(
        '$libPath depends on $target: only the $targetLayer barrel is public, '
        'not $targetPath',
      );
    }
  }

  return violations;
}

/// ADR 23: `editCollection` is the one route that writes a collection without
/// asking whose it is — the domain's throw is all that stands behind it. Every
/// mutation `ui/` makes goes through `barWriterProvider`, which is null on a
/// guest bar, so a screen naming the raw route has found a way round the check
/// that hides its own control. The rest of the notifier is fair game: export,
/// import and the reading unit are the controller's on purpose (FR-BAR-3,
/// FR-DAT-1/3), so the older "off the notifier entirely" rule cannot hold.
const _rawWriteRoute = 'editCollection';

List<String> _writeRouteViolations(String libPath, String source) => [
  if (_layerOf(libPath) == 'ui' && source.contains(_rawWriteRoute))
    '$libPath names $_rawWriteRoute: a screen writes through '
        'barWriterProvider, which a guest bar has none of',
];

List<_Directive> _imports(List<String> targets) => [
  for (final target in targets) (kind: 'import', target: target),
];

List<_Directive> _exports(List<String> targets) => [
  for (final target in targets) (kind: 'export', target: target),
];

/// Runtime dependency names in a pubspec [source], `flutter` excluded: the SDK
/// is the platform the app runs on, not a package taken for it.
Set<String> _pubspecDependencies(String source) {
  final entry = RegExp(r'^  ([a-z][a-z0-9_]*):');
  final names = <String>{};
  var inBlock = false;
  for (final line in source.split('\n')) {
    if (!inBlock) {
      inBlock = line.startsWith('dependencies:');
      continue;
    }
    if (line.trim().isEmpty) continue;
    if (!line.startsWith(' ')) break;
    final match = entry.firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names..remove('flutter');
}

/// Package names the "Minimal dependencies" bullet of an architecture [source]
/// names. The whole bullet counts, not only its leading list: the two packages
/// its later sentences name are runtime dependencies just as much, and that
/// bullet is the only home the rationale for taking them has.
Set<String> _documentedDependencies(String source) {
  final lines = source.split('\n');
  final start = lines.indexWhere(
    (l) => l.startsWith('- Minimal dependencies:'),
  );
  if (start < 0) return {};
  final bullet = [lines[start]];
  for (final line in lines.skip(start + 1)) {
    if (line.trim().isEmpty || !line.startsWith(' ')) break;
    bullet.add(line);
  }
  return RegExp(
    r'`([a-z][a-z0-9_]*)`',
  ).allMatches(bullet.join('\n')).map((m) => m.group(1)!).toSet();
}

void main() {
  group('lib/ layer boundaries', () {
    test('every file under lib/ honors docs/components.md boundary rules', () {
      final violations = <String>[];
      var scanned = 0;
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final libPath = entity.path.substring(entity.path.indexOf('lib/') + 4);
        scanned++;
        violations.addAll(
          _violations(libPath, _directivesOf(entity.readAsStringSync())),
        );
      }
      // Guards against a green sweep that walked nothing (wrong cwd).
      expect(scanned, greaterThan(4), reason: 'scanned only $scanned files');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('no screen writes a collection round the writer (ADR 23)', () {
      final violations = <String>[];
      var scanned = 0;
      for (final entity in Directory('lib/ui').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final libPath = entity.path.substring(entity.path.indexOf('lib/') + 4);
        scanned++;
        violations.addAll(
          _writeRouteViolations(libPath, entity.readAsStringSync()),
        );
      }
      expect(scanned, greaterThan(4), reason: 'scanned only $scanned files');
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('the domain barrel keeps layer-private names unexported', () {
      final barrel = File('lib/domain/domain.dart').readAsStringSync();
      final exported = _directivesOf(barrel).map((d) => d.target);
      expect(exported, isNot(contains('src/names.dart')));
      expect(barrel, contains('hide reservedSuffixes'));
      expect(barrel, contains('hide enumFromToken'));
    });

    // lib/main.dart sits outside every layer (docs/components.md module
    // map): it is exempt from the layer-to-layer dependency rules below
    // (the composition root legitimately reaches every layer and
    // package:flutter), but it must still never reach into a layer's src/.
    test('main.dart may import any layer surface and Flutter, never a src', () {
      expect(
        _violations(
          'main.dart',
          _imports([
            'package:flutter/material.dart',
            'package:cocktails/domain/domain.dart',
            'package:cocktails/data/data.dart',
            'package:cocktails/state/state.dart',
            'package:cocktails/ui/app.dart',
          ]),
        ),
        isEmpty,
      );
      expect(
        _violations(
          'main.dart',
          _imports(['package:cocktails/state/src/shelf_controller.dart']),
        ),
        isNotEmpty,
      );
    });
  });

  // docs/architecture.md names the dependencies, pubspec.yaml is where they
  // are: the doc said `file_picker` for a whole milestone while the manifest
  // depended on `file_selector`, with nothing reading both to notice.
  group('docs/architecture.md dependency list', () {
    test('names exactly the runtime dependencies of pubspec.yaml', () {
      final declared = _pubspecDependencies(
        File('pubspec.yaml').readAsStringSync(),
      );
      final documented = _documentedDependencies(
        File('docs/architecture.md').readAsStringSync(),
      );
      // Guards against a green run over a bullet that was renamed away.
      expect(
        documented,
        isNotEmpty,
        reason: 'no "Minimal dependencies" bullet',
      );

      final violations = [
        for (final name in declared.difference(documented))
          'docs/architecture.md omits $name, a pubspec.yaml dependency',
        for (final name in documented.difference(declared))
          'docs/architecture.md names $name, not a pubspec.yaml dependency',
      ];
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  // The suite above is proven non-vacuous here: it is exercised against
  // constructed fake inputs, not by breaking real code.
  group('boundary matcher sanity checks (fake inputs)', () {
    test('valid dependencies for every real layer do not violate', () {
      expect(
        _violations(
          'domain/src/collection.dart',
          _imports(['names.dart', 'dart:math']),
        ),
        isEmpty,
      );
      expect(
        _violations('domain/domain.dart', _exports(['src/collection.dart'])),
        isEmpty,
      );
      expect(
        _violations(
          'data/src/yaml_codec.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:yaml/yaml.dart',
          ]),
        ),
        isEmpty,
      );
      expect(
        _violations(
          'state/src/shelf_controller.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:cocktails/data/data.dart',
          ]),
        ),
        isEmpty,
      );
      expect(
        _violations(
          'ui/screens/ingredients_screen.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:cocktails/state/state.dart',
            'package:flutter/material.dart',
          ]),
        ),
        isEmpty,
      );
    });

    test('domain importing Flutter or dart:io/dart:ui is caught', () {
      expect(
        _violations(
          'domain/src/collection.dart',
          _imports(['package:flutter/material.dart']),
        ),
        isNotEmpty,
      );
      expect(
        _violations('domain/src/collection.dart', _imports(['dart:io'])),
        isNotEmpty,
      );
      expect(
        _violations('domain/src/collection.dart', _imports(['dart:ui'])),
        isNotEmpty,
      );
    });

    test('domain importing another layer is caught', () {
      expect(
        _violations(
          'domain/src/collection.dart',
          _imports(['package:cocktails/data/data.dart']),
        ),
        isNotEmpty,
      );
    });

    test('data importing state or ui is caught', () {
      expect(
        _violations(
          'data/src/bar_store.dart',
          _imports(['package:cocktails/state/state.dart']),
        ),
        isNotEmpty,
      );
    });

    test('state importing ui is caught', () {
      expect(
        _violations(
          'state/src/derived.dart',
          _imports(['package:cocktails/ui/screens/ingredients_screen.dart']),
        ),
        isNotEmpty,
      );
    });

    test(
      'ui importing data is caught even though domain and state are allowed',
      () {
        expect(
          _violations(
            'ui/screens/ingredients_screen.dart',
            _imports(['package:cocktails/data/data.dart']),
          ),
          isNotEmpty,
        );
      },
    );

    test('reaching into an allowed layer\'s src is caught, barrel only', () {
      expect(
        _violations(
          'data/src/yaml_codec.dart',
          _imports(['package:cocktails/domain/src/collection.dart']),
        ),
        isNotEmpty,
      );
    });

    test('a public file outside src is not another layer\'s surface', () {
      expect(
        _violations(
          'data/src/yaml_codec.dart',
          _imports(['package:cocktails/domain/extra.dart']),
        ),
        isNotEmpty,
      );
    });

    test('re-exporting another layer is caught, even an allowed one', () {
      // Otherwise state's barrel would hand ui a transitive route to data.
      expect(
        _violations(
          'state/state.dart',
          _exports(['package:cocktails/data/data.dart']),
        ),
        isNotEmpty,
      );
      expect(
        _violations(
          'data/data.dart',
          _exports(['package:cocktails/domain/src/collection.dart']),
        ),
        isNotEmpty,
      );
    });

    test(
      'same-layer src-to-src imports must be relative, not package-qualified',
      () {
        expect(
          _violations(
            'domain/src/collection.dart',
            _imports(['package:cocktails/domain/src/names.dart']),
          ),
          isNotEmpty,
        );
      },
    );

    test(
      'a relative import that escapes into a disallowed layer is caught',
      () {
        expect(
          _violations(
            'domain/src/sub/deep.dart',
            _imports(['../../../data/src/foo.dart']),
          ),
          isNotEmpty,
        );
      },
    );

    test('a relative import into an allowed layer\'s src is still caught', () {
      expect(
        _violations(
          'ui/screens/foo.dart',
          _imports(['../../domain/src/collection.dart']),
        ),
        isNotEmpty,
      );
    });

    test('a violation message names the offending file and directive', () {
      final violations = _violations(
        'domain/src/collection.dart',
        _imports(['package:flutter/material.dart']),
      );
      expect(violations.single, contains('domain/src/collection.dart'));
      expect(violations.single, contains('package:flutter/material.dart'));
    });
  });

  group('write-route matcher sanity checks (fake inputs)', () {
    test('a screen naming the raw write route is caught', () {
      expect(
        _writeRouteViolations(
          'ui/screens/ingredients_screen.dart',
          'ref.read(shelfProvider.notifier).editCollection((c) => c);',
        ),
        isNotEmpty,
      );
    });

    test('a screen reaching the notifier for the file seam is not', () {
      expect(
        _writeRouteViolations(
          'ui/screens/settings_screen.dart',
          'final shelf = ref.read(shelfProvider.notifier);\n'
              'await shelf.export();\n'
              'shelf.review(text);\n'
              'await shelf.setDisplay(FixedUnit.ml);',
        ),
        isEmpty,
      );
    });

    test('a screen writing through the writer is not', () {
      expect(
        _writeRouteViolations(
          'ui/screens/tags_screen.dart',
          'ref.read(barWriterProvider)!.removeTag(kind, name);',
        ),
        isEmpty,
      );
    });

    test('the rule is ui-only: state owns the route it publishes', () {
      expect(
        _writeRouteViolations(
          'state/src/bar_writer.dart',
          'Future<void> _edit(f) => _controller.editCollection(f);',
        ),
        isEmpty,
      );
    });

    test('a violation message names the file and what to use instead', () {
      final violation = _writeRouteViolations(
        'ui/screens/foo.dart',
        'editCollection',
      ).single;
      expect(violation, contains('ui/screens/foo.dart'));
      expect(violation, contains('barWriterProvider'));
    });
  });

  group('dependency list parser sanity checks (fake inputs)', () {
    test('the manifest parser takes dependencies, not the SDK or dev ones', () {
      expect(
        _pubspecDependencies('''
name: fake

dependencies:
  flutter:
    sdk: flutter
  # Pinned exactly, mentioning not_a_dependency.
  scrollable_positioned_list: 0.3.8
  yaml: ^3.1.3

dev_dependencies:
  flutter_lints: ^6.0.0
'''),
        {'scrollable_positioned_list', 'yaml'},
      );
    });

    test('the doc parser reads the whole bullet, and stops at its end', () {
      expect(
        _documentedDependencies('''
- Minimal dependencies: `first`, `second`.
  Prose taking `third` for ergonomics, over `pubspec.yaml` and a `Widget`.
- The next bullet, about `fourth`.
'''),
        {'first', 'second', 'third'},
      );
    });

    test('the doc parser reports nothing when the bullet is gone', () {
      expect(_documentedDependencies('- Dependencies: `first`.'), isEmpty);
    });
  });
}
