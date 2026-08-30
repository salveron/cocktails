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

/// ADR 08: one fold behind every name comparison, and `nameKey` is it. `ui/`
/// spelled its own three times while the rule was out of reach behind the
/// domain barrel (ADR 04), and the tag chips' spelling was a bug — a recipe
/// dropped off its own chip over a case the file was free to carry. The rule
/// is `ui/`-only: `data/` folds a bar's name into a file basename, which is a
/// slug rather than a comparison.
final _rawFold = RegExp(r'\.to(Lower|Upper)Case\(\)');

List<String> _foldViolations(String libPath, String source) => [
  if (_layerOf(libPath) == 'ui' && _rawFold.hasMatch(source))
    '$libPath folds a name itself: comparison goes through nameKey, the one '
        'home for the rule (ADR 08)',
];

/// ADR 25: `screens/` holds route destinations; `widgets/` holds what they
/// are composed from. A widget importing a screen has reached past what hands
/// it a way there into where that way lands — `app.dart`, which builds the
/// shell, and a screen naming a sibling it pushes are the only legitimate
/// routes in.
List<String> _screenImportViolations(String libPath, String source) {
  if (libPath == 'ui/app.dart' || libPath.startsWith('ui/screens/')) return [];
  if (_layerOf(libPath) != 'ui') return [];
  return [
    for (final directive in _directivesOf(source))
      if (directive.target.contains('screens/'))
        '$libPath imports ${directive.target}: only app.dart and screens/ '
            'may import a screen',
  ];
}

/// `ui/` has no barrel, so nothing marks its public surface off from its own
/// detail the way `src/` does for every other layer (docs/components.md
/// "Boundary rules") — a package-qualified intra-`ui` import costs nothing
/// today but makes the tree expensive to move again. Relative imports are
/// what `git mv` and a search-and-replace can still follow.
List<String> _intraUiImportViolations(String libPath, String source) {
  if (_layerOf(libPath) != 'ui') return [];
  return [
    for (final directive in _directivesOf(source))
      if (directive.target.startsWith('package:cocktails/ui/'))
        '$libPath imports ${directive.target}: intra-ui imports must be '
            'relative',
  ];
}

/// ADR 25: a screen is a route destination, and its name says so — the
/// file-naming half of what makes `screens/` a boundary rather than a
/// convention.
List<String> _screenNamingViolations(Iterable<String> screenFiles) => [
  for (final path in screenFiles)
    if (!path.endsWith('_screen.dart')) '$path is not named *_screen.dart',
];

/// ADR 25: nothing loose under `widgets/` — every file sorts into one of its
/// groups, or the layout decays back into the flat bag it was.
List<String> _looseWidgetViolations(Iterable<String> widgetFiles) => [
  for (final path in widgetFiles)
    if (!path.substring('ui/widgets/'.length).contains('/'))
      '$path sits loose under ui/widgets/, outside every group',
];

/// ADR 26: `collection/` -> `shopping/` -> `shelf/` -> loose is domain's own
/// one-way chain — the folders a `domain/src/` folder may import, itself
/// excluded, keyed by name.
const _domainChain = {
  'collection': <String>{},
  'shopping': {'collection'},
  'shelf': {'collection', 'shopping'},
};

/// The `domain/src/`-relative [srcPath]'s folder, or null for a loose file.
String? _domainFolderOf(String srcPath) {
  for (final folder in _domainChain.keys) {
    if (srcPath.startsWith('$folder/')) return folder;
  }
  return null;
}

/// ADR 26: nothing loose under `domain/src/` beyond the four files every
/// folder may read — a fifth folder, or a file sorted into none, decays the
/// layout the same way an unsorted `ui/widgets/` file would (ADR 25).
List<String> _domainLayoutViolations(Iterable<String> srcPaths) => [
  for (final path in srcPaths)
    if (path.contains('/') && _domainFolderOf(path) == null)
      'domain/src/$path sits outside collection/, shopping/, and shelf/',
];

/// ADR 26: a `domain/src/` folder importing one later in its own chain —
/// `collection/` reaching into `shopping/` or `shelf/`, or `shopping/`
/// reaching into `shelf/`.
List<String> _domainChainViolations(String libPath, String source) {
  if (!libPath.startsWith('domain/src/')) return [];
  final fromFolder = _domainFolderOf(libPath.substring('domain/src/'.length));
  if (fromFolder == null) return [];
  final allowed = _domainChain[fromFolder]!;
  return [
    for (final directive in _directivesOf(source))
      if (_targetLibPath(libPath, directive.target) case final target?)
        if (target.startsWith('domain/src/'))
          if (_domainFolderOf(target.substring('domain/src/'.length))
              case final targetFolder?)
            if (targetFolder != fromFolder && !allowed.contains(targetFolder))
              '$libPath depends on ${directive.target}: $fromFolder must not '
                  'depend on $targetFolder',
  ];
}

/// A double belongs to the tests that stand it up. `MemoryBarStore` shipped in
/// the binary for six milestones with `saveCount`, `savedBars` and `snapshots`
/// on it — surface no screen reads, only an assertion does. Type names rather
/// than file names: a double smuggled into a file called something else is the
/// case worth catching.
final _doubleName = RegExp(r'\bclass\s+(Memory|Fake|Mock|Stub)\w*');

List<String> _testDoubleViolations(String libPath, String source) => [
  for (final match in _doubleName.allMatches(source))
    '$libPath declares ${match.group(0)}: a double lives under test/support/, '
        'not in what ships',
];

/// Runs a source-reading rule over every file under [root], failing on any
/// violation and on a sweep that found too few files to have run at all.
void _expectNoneUnder(String root, List<String> Function(String, String) rule) {
  final violations = <String>[];
  var scanned = 0;
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final libPath = entity.path.substring(entity.path.indexOf('lib/') + 4);
    scanned++;
    violations.addAll(rule(libPath, entity.readAsStringSync()));
  }
  expect(scanned, greaterThan(4), reason: 'scanned only $scanned files');
  expect(violations, isEmpty, reason: violations.join('\n'));
}

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

/// One sanity check against a fake input: [description] names the case,
/// [check] runs a rule and returns whatever it found, and [violates] says
/// whether that should be non-empty. Every rule above answers a
/// `List<String>` of violations, so one shape covers all of them.
typedef _Case = ({
  String description,
  bool violates,
  List<String> Function() check,
});

void _expectCases(List<_Case> cases) {
  for (final c in cases) {
    test(
      c.description,
      () => expect(c.check(), c.violates ? isNotEmpty : isEmpty),
    );
  }
}

/// GitHub's own heading slug: lowercase, spaces to hyphens, punctuation gone.
String _slugOf(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 -]'), '')
    .replaceAll(' ', '-');

/// Every heading a markdown [source] answers a `#anchor` link with.
Set<String> _headingAnchors(String source) => {
  for (final line in source.split('\n'))
    if (RegExp(r'^#{1,6} ').hasMatch(line))
      _slugOf(line.replaceFirst(RegExp(r'^#{1,6} '), '')),
};

/// Every `file.md#anchor` [source] links, against no heading of
/// [docHeadings] answering it — keyed by basename, docs/ naming each file
/// once. A file matching no key is missing entirely.
List<String> _unresolvedAnchors(
  String source,
  Map<String, Set<String>> docHeadings,
) => [
  for (final m in RegExp(r'([\w-]+\.md)#([\w-]+)').allMatches(source))
    if (!(docHeadings[m.group(1)] ?? {}).contains(m.group(2)))
      '${m.group(1)}#${m.group(2)}',
];

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
      _expectNoneUnder('lib/ui', _writeRouteViolations);
    });

    test('no screen folds a name itself (ADR 08)', () {
      _expectNoneUnder('lib/ui', _foldViolations);
    });

    test('nothing that ships is a test double', () {
      _expectNoneUnder('lib', _testDoubleViolations);
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

  // docs/adr/25-the-ui-groups-by-subject.md: screens/ holds route
  // destinations, widgets/ holds what they are composed from, and every
  // group under widgets/ names a kind of interface piece.
  group('lib/ui/ layout (ADR 25)', () {
    test(
      'every file directly under lib/ui/screens/ is named *_screen.dart',
      () {
        final files = [
          for (final entity in Directory('lib/ui/screens').listSync())
            if (entity is File)
              entity.path.substring(entity.path.indexOf('lib/') + 4),
        ];
        // Guards against a green sweep that walked nothing (wrong cwd).
        expect(files, isNotEmpty);
        expect(_screenNamingViolations(files), isEmpty);
      },
    );

    test('no file sits loose under lib/ui/widgets/', () {
      final files = [
        for (final entity in Directory(
          'lib/ui/widgets',
        ).listSync(recursive: true))
          if (entity is File)
            entity.path.substring(entity.path.indexOf('lib/') + 4),
      ];
      expect(files, isNotEmpty);
      expect(_looseWidgetViolations(files), isEmpty);
    });

    test('only app.dart and screens/ import a screen', () {
      _expectNoneUnder('lib/ui', _screenImportViolations);
    });

    test('every intra-ui import is relative', () {
      _expectNoneUnder('lib/ui', _intraUiImportViolations);
    });
  });

  // docs/adr/26-the-domain-groups-by-responsibility.md: domain/src/ groups
  // into collection/, shopping/ and shelf/, plus loose files read by more
  // than one, in a one-way chain the same discipline ADR 04 gives the app's
  // four layers.
  group('lib/domain/ layout (ADR 26)', () {
    test('every file under domain/src/ is loose or in collection/, shopping/, '
        'or shelf/', () {
      final files = [
        for (final entity in Directory(
          'lib/domain/src',
        ).listSync(recursive: true))
          if (entity is File)
            entity.path.substring(
              entity.path.indexOf('domain/src/') + 'domain/src/'.length,
            ),
      ];
      expect(files, isNotEmpty);
      expect(_domainLayoutViolations(files), isEmpty);
    });

    test('no domain/src/ folder imports one later in its own chain', () {
      _expectNoneUnder('lib/domain', _domainChainViolations);
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

  // A heading rename breaks every `file.md#anchor` link to it silently.
  // This check catches such regressions before doc compaction hides them.
  group('doc anchors', () {
    test('every file.md#anchor link under docs/, lib/ and test/ resolves', () {
      final docHeadings = <String, Set<String>>{
        for (final entity in Directory('docs').listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.md'))
            entity.path.split('/').last: _headingAnchors(
              entity.readAsStringSync(),
            ),
      };

      final broken = <String>[];
      for (final root in ['docs', 'lib', 'test']) {
        for (final entity in Directory(root).listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.md') && !entity.path.endsWith('.dart')) {
            continue;
          }
          // This file's own doc comments and fake-input fixtures below carry
          // the pattern as an illustration, not a real link.
          if (entity.path.endsWith('architecture_test.dart')) continue;
          for (final anchor in _unresolvedAnchors(
            entity.readAsStringSync(),
            docHeadings,
          )) {
            broken.add('${entity.path} links $anchor, no such heading');
          }
        }
      }
      expect(broken, isEmpty, reason: broken.join('\n'));
    });
  });

  group('doc anchor matcher sanity checks (fake inputs)', () {
    _expectCases([
      (
        description: 'a link naming a real heading resolves',
        violates: false,
        check: () => _unresolvedAnchors('see foo.md#bar', {
          'foo.md': {'bar'},
        }),
      ),
      (
        description: 'a link naming no heading of that file is caught',
        violates: true,
        check: () => _unresolvedAnchors('see foo.md#baz', {
          'foo.md': {'bar'},
        }),
      ),
      (
        description: 'a link to a file with no heading map at all is caught',
        violates: true,
        check: () => _unresolvedAnchors('see missing.md#bar', {}),
      ),
      (
        description: 'a heading slugs punctuation away like GitHub\'s own',
        violates: false,
        check: () => _unresolvedAnchors('see foo.md#what-earns-a-test', {
          'foo.md': _headingAnchors('## What earns a test?'),
        }),
      ),
    ]);
  });

  // The suite above is proven non-vacuous here: it is exercised against
  // constructed fake inputs, not by breaking real code. One shape covers
  // every rule, since each returns the same List<String> of violations:
  // a description, whether the case should violate, and the call that
  // produces the violation list.
  group('boundary matcher sanity checks (fake inputs)', () {
    _expectCases([
      (
        description:
            'domain importing its own loose files and dart:math '
            'is valid',
        violates: false,
        check: () => _violations(
          'domain/src/collection.dart',
          _imports(['names.dart', 'dart:math']),
        ),
      ),
      (
        description: 'the domain barrel exporting its own src is valid',
        violates: false,
        check: () => _violations(
          'domain/domain.dart',
          _exports(['src/collection.dart']),
        ),
      ),
      (
        description:
            'data importing the domain barrel and an external '
            'package is valid',
        violates: false,
        check: () => _violations(
          'data/src/yaml_codec.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:yaml/yaml.dart',
          ]),
        ),
      ),
      (
        description: 'state importing the domain and data barrels is valid',
        violates: false,
        check: () => _violations(
          'state/src/shelf_controller.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:cocktails/data/data.dart',
          ]),
        ),
      ),
      (
        description:
            'ui importing the domain and state barrels plus '
            'Flutter is valid',
        violates: false,
        check: () => _violations(
          'ui/screens/ingredients_screen.dart',
          _imports([
            'package:cocktails/domain/domain.dart',
            'package:cocktails/state/state.dart',
            'package:flutter/material.dart',
          ]),
        ),
      ),
      (
        description: 'domain importing Flutter is caught',
        violates: true,
        check: () => _violations(
          'domain/src/collection.dart',
          _imports(['package:flutter/material.dart']),
        ),
      ),
      (
        description: 'domain importing dart:io is caught',
        violates: true,
        check: () =>
            _violations('domain/src/collection.dart', _imports(['dart:io'])),
      ),
      (
        description: 'domain importing dart:ui is caught',
        violates: true,
        check: () =>
            _violations('domain/src/collection.dart', _imports(['dart:ui'])),
      ),
      (
        description: 'domain importing another layer is caught',
        violates: true,
        check: () => _violations(
          'domain/src/collection.dart',
          _imports(['package:cocktails/data/data.dart']),
        ),
      ),
      (
        description: 'data importing state is caught',
        violates: true,
        check: () => _violations(
          'data/src/bar_store.dart',
          _imports(['package:cocktails/state/state.dart']),
        ),
      ),
      (
        description: 'state importing ui is caught',
        violates: true,
        check: () => _violations(
          'state/src/derived.dart',
          _imports(['package:cocktails/ui/screens/ingredients_screen.dart']),
        ),
      ),
      (
        description:
            'ui importing data is caught even though domain and '
            'state are allowed',
        violates: true,
        check: () => _violations(
          'ui/screens/ingredients_screen.dart',
          _imports(['package:cocktails/data/data.dart']),
        ),
      ),
      (
        description:
            'reaching into an allowed layer\'s src is caught, '
            'barrel only',
        violates: true,
        check: () => _violations(
          'data/src/yaml_codec.dart',
          _imports(['package:cocktails/domain/src/collection.dart']),
        ),
      ),
      (
        description:
            'a public file outside src is not another layer\'s '
            'surface',
        violates: true,
        check: () => _violations(
          'data/src/yaml_codec.dart',
          _imports(['package:cocktails/domain/extra.dart']),
        ),
      ),
      (
        // Otherwise state's barrel would hand ui a transitive route to data.
        description:
            're-exporting an allowed layer is caught (state barrel, '
            'data)',
        violates: true,
        check: () => _violations(
          'state/state.dart',
          _exports(['package:cocktails/data/data.dart']),
        ),
      ),
      (
        description:
            're-exporting reaches a layer\'s src is caught (data '
            'barrel, domain/src)',
        violates: true,
        check: () => _violations(
          'data/data.dart',
          _exports(['package:cocktails/domain/src/collection.dart']),
        ),
      ),
      (
        description:
            'same-layer src-to-src imports must be relative, not '
            'package-qualified',
        violates: true,
        check: () => _violations(
          'domain/src/collection.dart',
          _imports(['package:cocktails/domain/src/names.dart']),
        ),
      ),
      (
        description:
            'a relative import that escapes into a disallowed '
            'layer is caught',
        violates: true,
        check: () => _violations(
          'domain/src/sub/deep.dart',
          _imports(['../../../data/src/foo.dart']),
        ),
      ),
      (
        description:
            'a relative import into an allowed layer\'s src is '
            'still caught',
        violates: true,
        check: () => _violations(
          'ui/screens/foo.dart',
          _imports(['../../domain/src/collection.dart']),
        ),
      ),
    ]);

    test('a violation message names the offending file and directive', () {
      final violations = _violations(
        'domain/src/collection.dart',
        _imports(['package:flutter/material.dart']),
      );
      expect(violations.single, contains('domain/src/collection.dart'));
      expect(violations.single, contains('package:flutter/material.dart'));
    });
  });

  group('source-reading matcher sanity checks (fake inputs)', () {
    _expectCases([
      (
        description: 'a screen naming the raw write route is caught',
        violates: true,
        check: () => _writeRouteViolations(
          'ui/screens/ingredients_screen.dart',
          'ref.read(shelfProvider.notifier).editCollection((c) => c);',
        ),
      ),
      (
        description:
            'a screen reaching the notifier for the file seam is '
            'not caught',
        violates: false,
        check: () => _writeRouteViolations(
          'ui/screens/settings_screen.dart',
          'final shelf = ref.read(shelfProvider.notifier);\n'
              'await shelf.export();\n'
              'shelf.review(text);\n'
              'await shelf.setDisplay(FixedUnit.ml);',
        ),
      ),
      (
        description: 'a screen folding a name itself is caught',
        violates: true,
        check: () => _foldViolations(
          'ui/widgets/search_field.dart',
          'text.toLowerCase().contains(query.toLowerCase());',
        ),
      ),
      (
        description:
            'a screen reading the fold from the domain is not '
            'caught',
        violates: false,
        check: () => _foldViolations(
          'ui/widgets/search_field.dart',
          'nameKey(text).contains(nameKey(query.trim()));',
        ),
      ),
      (
        description: 'the file-basename slug outside ui/ is not caught',
        violates: false,
        check: () => _foldViolations(
          'data/src/file_bar_store.dart',
          "name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');",
        ),
      ),
      (
        description:
            'a double under lib/ is caught, whatever the file is '
            'called',
        violates: true,
        check: () => _testDoubleViolations(
          'data/src/bar_store.dart',
          'base class MemoryBarStore implements BarStore {}',
        ),
      ),
      (
        description:
            'a real implementation naming a double in prose is '
            'not caught',
        violates: false,
        check: () => _testDoubleViolations(
          'data/src/file_bar_store.dart',
          '/// Unlike MemoryBarStore, this one survives a restart.\n'
              'final class FileBarStore implements BarStore {}',
        ),
      ),
      (
        description: 'a screen writing through the writer is not caught',
        violates: false,
        check: () => _writeRouteViolations(
          'ui/screens/tags_screen.dart',
          'ref.read(barWriterProvider)!.removeTag(kind, name);',
        ),
      ),
      (
        description:
            'the write-route rule is ui-only: state owns the '
            'route it publishes',
        violates: false,
        check: () => _writeRouteViolations(
          'state/src/bar_writer.dart',
          'Future<void> _edit(f) => _controller.editCollection(f);',
        ),
      ),
      (
        description: 'a widget importing a screen is caught (ADR 25)',
        violates: true,
        check: () => _screenImportViolations(
          'ui/widgets/forms/editor_form.dart',
          "import '../../screens/units_screen.dart';",
        ),
      ),
      (
        description: 'app.dart importing a screen is not caught (ADR 25)',
        violates: false,
        check: () => _screenImportViolations(
          'ui/app.dart',
          "import 'screens/recipes_screen.dart';",
        ),
      ),
      (
        description: 'one screen importing another is not caught (ADR 25)',
        violates: false,
        check: () => _screenImportViolations(
          'ui/screens/settings_screen.dart',
          "import 'units_screen.dart';",
        ),
      ),
      (
        description:
            'an intra-ui import off the barrel-less package path '
            'is caught',
        violates: true,
        check: () => _intraUiImportViolations(
          'ui/screens/foo.dart',
          "import 'package:cocktails/ui/theme.dart';",
        ),
      ),
      (
        description: 'the same intra-ui import made relative is not caught',
        violates: false,
        check: () => _intraUiImportViolations(
          'ui/screens/foo.dart',
          "import '../theme.dart';",
        ),
      ),
    ]);

    test('a violation message names the file and what to use instead', () {
      final violation = _writeRouteViolations(
        'ui/screens/foo.dart',
        'editCollection',
      ).single;
      expect(violation, contains('ui/screens/foo.dart'));
      expect(violation, contains('barWriterProvider'));
    });
  });

  group('lib/ui/ layout sanity checks (fake inputs)', () {
    _expectCases([
      (
        description: 'a screen not named *_screen.dart is caught',
        violates: true,
        check: () =>
            _screenNamingViolations(['ui/screens/recipe_widgets.dart']),
      ),
      (
        description: 'a screen named *_screen.dart is not caught',
        violates: false,
        check: () => _screenNamingViolations(['ui/screens/units_screen.dart']),
      ),
      (
        description: 'a file loose under widgets/ is caught',
        violates: true,
        check: () => _looseWidgetViolations(['ui/widgets/arriving_bar.dart']),
      ),
      (
        description: 'a file sorted into a group is not caught',
        violates: false,
        check: () =>
            _looseWidgetViolations(['ui/widgets/cards/entry_card.dart']),
      ),
    ]);
  });

  group('lib/domain/ layout sanity checks (fake inputs)', () {
    _expectCases([
      (
        description: 'a file loose at domain/src/ is not a violation',
        violates: false,
        check: () => _domainLayoutViolations(['names.dart']),
      ),
      (
        description:
            'a file sorted into one of the three folders is not '
            'caught',
        violates: false,
        check: () => _domainLayoutViolations(['collection/unit.dart']),
      ),
      (
        description: 'a file under a fourth folder is caught',
        violates: true,
        check: () => _domainLayoutViolations(['discovery/recipe.dart']),
      ),
      (
        description: 'collection/ reaching into shopping/ is caught',
        violates: true,
        check: () => _domainChainViolations(
          'domain/src/collection/collection.dart',
          "import '../shopping/shopping_settings.dart';",
        ),
      ),
      (
        description: 'shopping/ reaching into shelf/ is caught',
        violates: true,
        check: () => _domainChainViolations(
          'domain/src/shopping/optimizer.dart',
          "import '../shelf/bar.dart';",
        ),
      ),
      (
        description:
            'shelf/ reaching into shopping/ and collection/ is '
            'not caught',
        violates: false,
        check: () => _domainChainViolations(
          'domain/src/shelf/bar.dart',
          "import '../shopping/shopping_settings.dart';\n"
              "import '../collection/collection.dart';",
        ),
      ),
      (
        description: 'a folder importing a loose file is not caught',
        violates: false,
        check: () => _domainChainViolations(
          'domain/src/collection/collection.dart',
          "import '../names.dart';",
        ),
      ),
      (
        description:
            'a loose file importing nothing folder-specific is '
            'not scanned',
        violates: false,
        check: () => _domainChainViolations('domain/src/names.dart', ''),
      ),
    ]);
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
