/// The file transport (FR-BAR-7): every fetch is the picker, so what a reader
/// hands over — a bar, a file the app cannot read, nothing at all — is the
/// whole of what this channel can answer (ADR 22).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final collection = Collection(
    ingredients: [Ingredient('gin', stock: StockLevel.in_)],
    recipes: [
      Recipe(
        'Martini',
        lines: const [
          RecipeLine(Amount(2), 'part', ['gin']),
        ],
      ),
    ],
  );
  final payload = (
    name: "Ada's bar",
    display: FixedUnit.ml,
    collection: collection,
  );
  final document = const YamlCodec().encode(payload);

  /// A channel over a picker answering [text], or throwing [error].
  FileBarChannel picking(String? text, {Object? error}) =>
      FileBarChannel(() async {
        if (error != null) throw error;
        return text;
      });

  test('the transport it answers for is the file', () {
    expect(picking(null).transport, Transport.file);
  });

  /// The address is empty because there is none: the reader is asked every
  /// time, and no file names who sent it.
  test('the source it mints holds no address and no sender', () {
    expect(
      FileBarChannel.source,
      const BarSource(via: Transport.file, at: '', from: ''),
    );
  });

  test('a picked bar arrives whole — name, display and collection', () async {
    final outcome = await picking(document).fetch(FileBarChannel.source);
    expect(outcome, isA<Ok<BarPayload>>());
    expect((outcome! as Ok<BarPayload>).value, payload);
  });

  /// The source is unread: which document answers is the reader's judgement,
  /// so a bar sourced from anywhere else would still be met by the picker.
  test('the source it is handed goes unread', () async {
    final channel = picking(document);
    const elsewhere = BarSource(
      via: Transport.lan,
      at: '10.0.0.4',
      from: 'Ada',
    );
    expect(await channel.fetch(elsewhere), isA<Ok<BarPayload>>());
  });

  test('a reader who picks nothing has not fetched at all', () async {
    expect(await picking(null).fetch(FileBarChannel.source), isNull);
  });

  test('a file the app cannot read is refused, placed by line', () async {
    final outcome = await picking(
      'format: 2\nname: Ada\nrecipes:\n  - name: Martini\n    lines:\n'
      '      - 2 part rye\n',
    ).fetch(FileBarChannel.source);
    expect(outcome, isA<Rejected<BarPayload>>());
    final issues = (outcome! as Rejected<BarPayload>).issues;
    expect(issues, isNotEmpty);
    expect(issues.first.issue.kind, ValidationIssueKind.unknownIngredient);
    expect(issues.first.line, isNotNull);
  });

  /// A fetch answers rather than throws, whatever the platform did (ADR 22).
  test('a picker that fails is refused rather than thrown', () async {
    final outcome = await picking(
      null,
      error: StateError('no activity'),
    ).fetch(FileBarChannel.source);
    expect(outcome, isA<Rejected<BarPayload>>());
    expect(
      (outcome! as Rejected<BarPayload>).issues.single.description,
      contains('no activity'),
    );
  });
}
