import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('wornInOrder', () {
    const vocabulary = [
      Tag('classic', color: TagColor.rose),
      Tag('sour', color: TagColor.sand),
      Tag('tiki', color: TagColor.teal),
    ];
    List<String> namesOf(List<Tag> tags) => [for (final tag in tags) tag.name];

    test('reads in vocabulary order, not the order they were worn', () {
      expect(namesOf(wornInOrder(vocabulary, ['tiki', 'classic'])), [
        'classic',
        'tiki',
      ]);
    });

    test('drops a name the vocabulary no longer holds', () {
      expect(namesOf(wornInOrder(vocabulary, ['vintage', 'sour'])), ['sour']);
    });

    test('answers with the tags themselves, colours included', () {
      expect(wornInOrder(vocabulary, ['sour']).single.color, TagColor.sand);
    });

    test('wearing none and a vocabulary of none both come out empty', () {
      expect(wornInOrder(vocabulary, const []), isEmpty);
      expect(wornInOrder(const [], const ['classic']), isEmpty);
    });

    test('a name wanted twice is answered once', () {
      expect(namesOf(wornInOrder(vocabulary, ['sour', 'sour'])), ['sour']);
    });

    test('a name worn in another case is the same tag (ADR 08)', () {
      expect(namesOf(wornInOrder(vocabulary, ['SOUR'])), ['sour']);
    });
  });

  tokenVocabulary(
    'TagColor',
    values: TagColor.values,
    token: (value) => value.token,
    fromToken: TagColor.fromToken,
    tokens: const ['teal', 'indigo', 'plum', 'rose', 'sand', 'slate'],
    unknown: 'puce',
  );

  test('the tag palette spends no colour stock or availability needs', () {
    expect([
      for (final color in TagColor.values) color.token,
    ], isNot(contains(anyOf('green', 'amber', 'red'))));
  });

  group('Tag', () {
    Tag build({String name = 'sour', TagColor color = TagColor.teal}) =>
        Tag(name, color: color);

    valueEquality(build, {
      'name': build(name: 'classic'),
      'color': build(color: TagColor.rose),
    });

    const tag = Tag('sour', color: TagColor.rose);
    copyWithContract([
      (field: 'nothing named', apply: () => tag.copyWith(), expected: tag),
      (
        field: 'name',
        apply: () => tag.copyWith(name: 'sours'),
        expected: const Tag('sours', color: TagColor.rose),
      ),
      (
        field: 'color',
        apply: () => tag.copyWith(color: TagColor.plum),
        expected: const Tag('sour', color: TagColor.plum),
      ),
    ]);
  });
}
