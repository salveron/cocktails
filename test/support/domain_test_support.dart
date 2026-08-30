/// Support the domain suites share: the two contracts a value type is held to
/// wherever one is tested — an enum's tokens round-trip through the data
/// format, and `==`/`hashCode` isolate every field — and the two kinds of bar
/// record the shelf suites are read over (docs/components.md#testing).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every enum written into the data format promises: the [tokens] it
/// spells, in order, and a [fromToken] that reads back exactly those and
/// answers null for anything else. One body for all four, so a token added to
/// one enum is held to the same contract as the rest.
void tokenVocabulary<T extends Enum>(
  String name, {
  required List<T> values,
  required String Function(T value) token,
  required T? Function(String) fromToken,
  required List<String> tokens,
  required String unknown,
}) {
  group('$name tokens', () {
    test('match the data format', () {
      expect([for (final value in values) token(value)], tokens);
    });

    test('fromToken round-trips every member', () {
      for (final value in values) {
        expect(fromToken(token(value)), value);
      }
    });

    test('fromToken returns null for an unknown token', () {
      expect(fromToken(unknown), isNull);
    });
  });
}

/// What one [ValidationIssue] promises: its [kind] always, [path] and a
/// [messagePart] of its message where a test is about either — the domain's
/// counterpart to `data_test_support.dart`'s `expectIssue`, which adds the
/// line a decode places an issue at.
void expectIssue(
  ValidationIssue actual,
  ValidationIssueKind kind, {
  List<Object>? path,
  String? messagePart,
}) {
  expect(actual.kind, kind, reason: '$actual');
  if (path != null) expect(actual.path, path, reason: '$actual');
  if (messagePart != null) {
    expect(actual.message, contains(messagePart), reason: '$actual');
  }
}

/// Value semantics, read the same way for every type carrying them: two builds
/// of the same values are equal and hash alike, while each of [differing] — the
/// same build with one field moved off its default — is not. Each field is
/// named, so a broken `==` reports which one it stopped reading.
void valueEquality<T>(T Function() build, Map<String, T> differing) {
  test('equality and hashCode isolate each field', () {
    expect(build(), build());
    expect(build().hashCode, build().hashCode);
    differing.forEach((field, moved) {
      expect(build(), isNot(moved), reason: field);
    });
  });
}

/// What every `copyWith` promises: naming nothing answers an equal value, and
/// naming one field replaces it while every other field rides along. Each
/// case names the field, the call that names only it, and what it should
/// answer with — the call is a closure because `copyWith` takes a different
/// named argument per type, which a generic helper cannot spell for it.
void copyWithContract<T>(
  List<({String field, T Function() apply, T expected})> cases,
) {
  group('copyWith replaces one field and carries the rest', () {
    for (final c in cases) {
      test(c.field, () => expect(c.apply(), c.expected, reason: c.field));
    }
  });
}

/// The source a guest bar refreshes from, as the index's own example writes it.
const aSource = BarSource(
  via: Transport.lan,
  at: '_cocktails._tcp/5f2c9a',
  from: 'Home bar (b3e)',
);

/// When a source last answered; UTC, as the index records it.
final anHourAgo = DateTime.utc(2026, 8, 9, 18, 22, 4);

/// The two kinds of record, built so a test names only what it is about.
Bar ownedBar({
  String id = '5f2c9a',
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
  List<Offer> offers = const [],
  DateTime? updated,
  Map<Holding, int>? summary,
}) => Bar(
  id: id,
  name: name,
  mode: BarMode.owner,
  display: display,
  offers: offers,
  updated: updated,
  summary: summary,
);

Bar guestBar({
  String id = 'b3e1d7',
  String name = 'Ada\'s bar',
  FixedUnit display = FixedUnit.part,
  BarSource? source = aSource,
  DateTime? refreshed,
  Map<Holding, int>? summary,
}) => Bar(
  id: id,
  name: name,
  mode: BarMode.guest,
  display: display,
  source: source,
  refreshed: refreshed,
  summary: summary,
);

/// The one recipe simple fixtures build around: gin and campari in equal
/// parts, tagged classic — so a widget test's small collection and a
/// controller test's stored one are not two hand-built Negronis that could
/// quietly drift apart.
final negroniRecipe = Recipe(
  'Negroni',
  tags: const ['classic'],
  lines: const [
    RecipeLine(Amount(1), 'part', ['gin']),
    RecipeLine(Amount(1), 'part', ['campari']),
  ],
);
