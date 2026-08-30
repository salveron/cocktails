/// The LAN transport's owner half (FR-BAR-6, ADR 22): what comes up with the
/// first offer, what stays up between offers, and what goes down with the last
/// withdrawal. The server underneath is the real one; only the announcement is
/// stood in for, being the half no test can reach without a device.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/data/src/lan_discovery.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

/// The platform an announcement crosses to (ADR 18), recording what it was
/// asked for and answering under a name the network "granted" — never the one
/// asked for, since that is what a clash does and what a guest keeps (ADR 27).
final class _Announcer {
  final asked = <({String name, int port})>[];
  var silenced = 0;

  Future<LanAnnouncement> call({
    required String name,
    required int port,
  }) async {
    asked.add((name: name, port: port));
    return _Announced('$name (2)', () => silenced++);
  }
}

final class _Announced implements LanAnnouncement {
  @override
  final String name;
  final void Function() _silence;

  _Announced(this.name, this._silence);

  @override
  Future<void> stop() async => _silence();
}

void main() {
  /// A channel over [bars] and an announcer that records rather than announces.
  ({LanBarChannel channel, _Announcer announcer}) channelOver(
    Map<String, String> bars,
  ) {
    final announcer = _Announcer();
    final channel = LanBarChannel(
      bytesOf: (id) async => bars[id],
      deviceName: () => 'ZEN',
      announcer: announcer.call,
    );
    addTearDown(() async {
      await channel.withdraw('a1');
      await channel.withdraw('b2');
    });
    return (channel: channel, announcer: announcer);
  }

  test('the transport it answers for is the LAN', () {
    expect(channelOver({}).channel.transport, Transport.lan);
  });

  /// NFR-5: a device sharing nothing announces nothing, so nothing is on the
  /// network until a reader puts it there.
  test('a device that has offered nothing announces nothing', () {
    expect(channelOver({'a1': 'first bar'}).announcer.asked, isEmpty);
  });

  test('the first offer announces the device, once and by name', () async {
    final over = channelOver({'a1': 'first bar'});
    await over.channel.offer('a1', 'Home bar');
    expect(over.announcer.asked, hasLength(1));
    expect(over.announcer.asked.single.name, 'ZEN');
  });

  /// One instance per device, never one per bar (ADR 22): a second offer joins
  /// the list the first raised rather than announcing beside it.
  test('a second offer announces nothing further', () async {
    final over = channelOver({'a1': 'first bar', 'b2': 'second bar'});
    await over.channel.offer('a1', 'Home bar');
    await over.channel.offer('b2', 'Beach bar');
    expect(over.announcer.asked, hasLength(1));
    expect(await offeredOn(over.announcer.asked.single.port), hasLength(2));
  });

  test('the port announced is the one the server answers on', () async {
    final over = channelOver({'a1': 'first bar'});
    await over.channel.offer('a1', 'Home bar');
    final listed = await offeredOn(over.announcer.asked.single.port);
    expect(listed.keys, ['a1']);
    expect(listed['a1']!.name, 'Home bar');
  });

  test('withdrawing one of two leaves the device announced', () async {
    final over = channelOver({'a1': 'first bar', 'b2': 'second bar'});
    await over.channel.offer('a1', 'Home bar');
    await over.channel.offer('b2', 'Beach bar');
    await over.channel.withdraw('a1');
    expect(over.announcer.silenced, 0);
    expect(await offeredOn(over.announcer.asked.single.port), hasLength(1));
  });

  test(
    'withdrawing the last silences the device and stops the server',
    () async {
      final over = channelOver({'a1': 'first bar'});
      await over.channel.offer('a1', 'Home bar');
      final port = over.announcer.asked.single.port;
      await over.channel.withdraw('a1');
      expect(over.announcer.silenced, 1);
      await expectLater(askServer(port, '/bars'), throwsA(isA<Exception>()));
    },
  );

  /// Withdrawing what was never offered is not an error: there is nothing
  /// announced on its behalf to silence.
  test('withdrawing a bar never offered does nothing at all', () async {
    final over = channelOver({'a1': 'first bar'});
    await over.channel.withdraw('a1');
    expect(over.announcer.asked, isEmpty);
    expect(over.announcer.silenced, 0);
  });

  /// ADR 28: the reader may rename the device between announcements, so the
  /// name is asked for at each rather than held from the first.
  test('the name is read at each announcement, never kept', () async {
    var name = 'ZEN';
    final announcer = _Announcer();
    final channel = LanBarChannel(
      bytesOf: (id) async => 'first bar',
      deviceName: () => name,
      announcer: announcer.call,
    );
    addTearDown(() => channel.stop());
    await channel.offer('a1', 'Home bar');
    await channel.withdraw('a1');
    name = "Nikita's phone";
    await channel.offer('a1', 'Home bar');
    expect(announcer.asked.map((asked) => asked.name), [
      'ZEN',
      "Nikita's phone",
    ]);
  });

  /// What the composition root does on disposal: both halves down at once,
  /// whatever is still offered.
  test('stopping takes the announcement and the server with it', () async {
    final over = channelOver({'a1': 'first bar', 'b2': 'second bar'});
    await over.channel.offer('a1', 'Home bar');
    await over.channel.offer('b2', 'Beach bar');
    final port = over.announcer.asked.single.port;
    await over.channel.stop();
    expect(over.announcer.silenced, 1);
    await expectLater(askServer(port, '/bars'), throwsA(isA<Exception>()));
  });

  /// The offer outlives the run and the announcement does not (ADR 22), so a
  /// device that went quiet comes back up rather than staying silent.
  test('offering again after the last withdrawal announces afresh', () async {
    final over = channelOver({'a1': 'first bar'});
    await over.channel.offer('a1', 'Home bar');
    await over.channel.withdraw('a1');
    await over.channel.offer('a1', 'Home bar');
    expect(over.announcer.asked, hasLength(2));
    expect(await offeredOn(over.announcer.asked.last.port), hasLength(1));
  });
}
