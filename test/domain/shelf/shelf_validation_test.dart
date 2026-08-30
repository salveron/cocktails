import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/domain_test_support.dart';

void main() {
  group('the device\'s own name', () {
    test('passes where it keeps the rules a name keeps', () {
      expect(validateShelf(bars: [ownedBar()], deviceName: 'ZEN'), isEmpty);
    });

    test('is reported at the key the index writes it under', () {
      final issues = validateShelf(bars: const [], deviceName: '');
      expect(issues.single.path, const ['device']);
      expect(issues.single.message, 'Empty device name');
    });

    test('goes unchecked where the reader has named none', () {
      expect(validateShelf(bars: const [], deviceName: null), isEmpty);
    });
  });

  // codec reads an untrusted file into records and must say what is wrong with
  // it rather than crash (ADR 05).
  group('validateShelf', () {
    test('a clean shelf is valid, open or empty', () {
      expect(validateShelf(bars: [ownedBar(), guestBar()]), isEmpty);
      expect(validateShelf(bars: [ownedBar()], openId: '5f2c9a'), isEmpty);
      expect(validateShelf(bars: const []), isEmpty);
    });

    test('two bars of one name are no issue at all (FR-BAR-1)', () {
      expect(
        validateShelf(
          bars: [
            ownedBar(),
            guestBar(name: 'Home bar'),
          ],
        ),
        isEmpty,
      );
    });

    test('an id twice over is a duplicate, reported at the second', () {
      final issue = validateShelf(
        bars: [
          ownedBar(),
          guestBar(id: '5f2c9a'),
        ],
      ).single;
      expect(issue.kind, ValidationIssueKind.duplicateName);
      expect(issue.location, 'bars[1].id');
      expect(issue.message, contains('5f2c9a'));
    });

    test('ids compare exactly, the fold being a rule for names (ADR 08)', () {
      expect(
        validateShelf(
          bars: [
            ownedBar(id: '5f2c9a'),
            guestBar(id: '5F2C9A'),
          ],
        ),
        isEmpty,
      );
    });

    test('an empty id is reported where a name would be', () {
      expect(
        validateShelf(bars: [ownedBar(id: '')]).single.kind,
        ValidationIssueKind.emptyName,
      );
    });

    test('a bar name keeps every value rule but uniqueness', () {
      for (final (name, kind) in [
        ('', ValidationIssueKind.emptyName),
        (' Home bar', ValidationIssueKind.whitespaceInName),
        ('Home\nbar', ValidationIssueKind.lineBreakInName),
      ]) {
        final issue = validateShelf(bars: [ownedBar(name: name)]).single;
        expect(issue.kind, kind, reason: name);
        expect(issue.location, 'bars[0].name', reason: name);
      }
    });

    test('open must name a bar the shelf holds, and is read first', () {
      final issues = validateShelf(
        bars: [ownedBar(name: '')],
        openId: 'gone',
      );
      expect(issues.first.location, 'open');
      expect(issues.first.kind, ValidationIssueKind.malformedValue);
      expect(issues.first.message, contains('gone'));
      expect(issues.last.location, 'bars[0].name');
    });

    test('a guest bar needs the source it refreshes from', () {
      final issue = validateShelf(bars: [guestBar(source: null)]).single;
      expect(issue.kind, ValidationIssueKind.malformedValue);
      expect(issue.location, 'bars[0].source');
    });

    test('an owned bar carries neither a source nor a refresh time', () {
      final issues = validateShelf(
        bars: [
          Bar(
            id: '5f2c9a',
            name: 'Home bar',
            mode: BarMode.owner,
            source: aSource,
            refreshed: anHourAgo,
          ),
        ],
      );
      expect(issues.map((i) => i.location), [
        'bars[0].source',
        'bars[0].refreshed',
      ]);
    });

    test('a guest bar dates no change of its own (FR-BAR-3)', () {
      final issue = validateShelf(
        bars: [
          Bar(
            id: 'b3e1d7',
            name: 'Ada\'s bar',
            mode: BarMode.guest,
            source: aSource,
            updated: anHourAgo,
          ),
        ],
      ).single;
      expect(issue.kind, ValidationIssueKind.malformedValue);
      expect(issue.location, 'bars[0].updated');
    });

    test('a guest bar is not this device\'s to share (FR-BAR-6)', () {
      final issue = validateShelf(
        bars: [
          Bar(
            id: 'b3e1d7',
            name: 'Ada\'s bar',
            mode: BarMode.guest,
            source: aSource,
            offers: const [(via: Transport.lan, guests: [])],
          ),
        ],
      ).single;
      expect(issue.kind, ValidationIssueKind.malformedValue);
      expect(issue.location, 'bars[0].offers[0]');
    });

    test('a guest bar names no optimizer of its own (ADR 21/24)', () {
      final issue = validateShelf(
        bars: [
          Bar(
            id: 'b3e1d7',
            name: 'Ada\'s bar',
            mode: BarMode.guest,
            source: aSource,
            shopping: const ShoppingSettings(),
          ),
        ],
      ).single;
      expect(issue.kind, ValidationIssueKind.malformedValue);
      expect(issue.location, 'bars[0].shopping');
    });

    test('one bar is offered once per transport', () {
      const twice = [
        (via: Transport.lan, guests: <String>[]),
        (via: Transport.lan, guests: ['ada']),
      ];
      final issue = validateShelf(bars: [ownedBar(offers: twice)]).single;
      expect(issue.kind, ValidationIssueKind.duplicateName);
      expect(issue.location, 'bars[0].offers[1]');
      expect(issue.message, contains('lan'));
    });

    test('every issue is collected, none of them fatal', () {
      final issues = validateShelf(
        bars: [
          ownedBar(name: ''),
          guestBar(id: '', source: null),
        ],
        openId: 'gone',
      );
      expect(issues, hasLength(4));
      expect(issues.map((i) => i.location), [
        'open',
        'bars[0].name',
        'bars[1].id',
        'bars[1].source',
      ]);
    });
  });
}
