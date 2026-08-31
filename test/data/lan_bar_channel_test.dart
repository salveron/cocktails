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

/// A browse that answers with whatever the test put on the "network" — the
/// resolve every fetch does afresh, without one (ADR 22).
final class _Network {
  final services = <LanService>[];
  var reachable = true;
  Exception? refusing;

  Future<List<LanService>> browse() async {
    final refused = refusing;
    if (refused != null) throw refused;
    return services;
  }

  Future<bool> reach() async => reachable;

  /// [name] answering on the loopback at [port], which is what a device found
  /// nearby comes back as once resolved.
  void offers(String name, int port) => services.add(
    LanService(name: name, port: port, addresses: ['127.0.0.1']),
  );
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

  /// One device offering and another asking, over the loopback: the owner's
  /// server is real and only the two crossings a guest cannot make in a test —
  /// the browse and the question of being on a network at all — are stood in
  /// for (ADR 22, ADR 27).
  Future<({LanBarChannel guest, _Network network})> nearby(
    Map<String, String> bars, {
    Map<String, String> offering = const {'a1': 'Home bar'},
  }) async {
    final owner = channelOver(bars);
    for (final offered in offering.entries) {
      await owner.channel.offer(offered.key, offered.value);
    }
    final network = _Network()
      ..offers(_instance, owner.announcer.asked.single.port);
    final guest = LanBarChannel(
      bytesOf: (id) async => null,
      deviceName: () => 'guest',
      browser: network.browse,
      reach: network.reach,
    );
    return (guest: guest, network: network);
  }

  UnreachableReason? whyNot(Outcome<BarContent>? outcome) =>
      outcome is Unreachable<BarContent> ? outcome.why : null;

  group("the guest's half", () {
    group('channel contract', () {
      barChannelContract(
        (answering) => _ContractChannel((source) async {
          final over = await nearby({'a1': await _catching(answering)});
          return over.guest.fetch(_sourceFor('a1'));
        }),
      );
    });

    test('a bar offered nearby arrives whole', () async {
      final document = encoded(Collection(ingredients: [Ingredient('gin')]));
      final over = await nearby({'a1': document});
      final outcome = await over.guest.fetch(_sourceFor('a1'));
      expect(outcome, isA<Ok<BarContent>>());
      expect(
        (outcome! as Ok<BarContent>).value.collection.ingredients.single.name,
        'gin',
      );
    });

    /// FR-BAR-5's three readings, told apart by where the ask stopped (ADR 22).
    test('no network of our own is offline', () async {
      final over = await nearby({'a1': encoded(Collection())});
      over.network.reachable = false;
      expect(
        whyNot(await over.guest.fetch(_sourceFor('a1'))),
        UnreachableReason.offline,
      );
    });

    test('an instance that will not resolve is not found', () async {
      final over = await nearby({'a1': encoded(Collection())});
      expect(
        whyNot(
          await over.guest.fetch(
            LanBarChannel.sourceFor(barId: 'a1', instance: 'someone else'),
          ),
        ),
        UnreachableReason.notFound,
      );
    });

    test('a browse that will not run is not found', () async {
      final over = await nearby({'a1': encoded(Collection())});
      over.network.refusing = Exception('no multicast');
      expect(
        whyNot(await over.guest.fetch(_sourceFor('a1'))),
        UnreachableReason.notFound,
      );
    });

    /// The instance answers and its list no longer names the bar: an owner who
    /// stopped sharing, which is exactly what a vanished instance is not.
    test('a bar the list no longer names is withdrawn', () async {
      final over = await nearby({'a1': encoded(Collection())});
      expect(
        whyNot(await over.guest.fetch(_sourceFor('b2'))),
        UnreachableReason.withdrawn,
      );
    });

    /// The list names it and the path answers nothing — a rotated path, or a
    /// bar the owner's store can no longer read. Neither is *broken*.
    test('a path that answers nothing is withdrawn too', () async {
      final over = await nearby(const {}, offering: const {'a1': 'Home bar'});
      expect(
        whyNot(await over.guest.fetch(_sourceFor('a1'))),
        UnreachableReason.withdrawn,
      );
    });

    test('a source carrying no instance is not found', () async {
      final over = await nearby({'a1': encoded(Collection())});
      for (final at in ['', 'a1', 'a1/', '/ZEN']) {
        expect(
          whyNot(
            await over.guest.fetch(
              BarSource(via: Transport.lan, at: at, from: 'ZEN'),
            ),
          ),
          UnreachableReason.notFound,
          reason: 'at: "$at"',
        );
      }
    });

    test(
      'the source it mints keeps the instance and the id, never an address',
      () {
        final source = LanBarChannel.sourceFor(barId: 'a1', instance: 'ZEN');
        expect(source.via, Transport.lan);
        expect(source.at, 'a1/ZEN');
        expect(source.from, 'ZEN');
      },
    );
  });
}

const _instance = 'ZEN';

BarSource _sourceFor(String barId) =>
    LanBarChannel.sourceFor(barId: barId, instance: _instance);

/// The contract hands a channel a function answering the document; a served
/// bar whose bytes throw is a 404 rather than an error a guest can read, so
/// the throw is caught here and the wire reads it as nothing to serve.
Future<String> _catching(Future<String?> Function() answering) async {
  try {
    return await answering() ?? '';
  } on Object {
    return '';
  }
}

/// The contract asks for a [BarChannel]; the LAN's fetch needs a device
/// standing behind it, so this stands one up per ask.
final class _ContractChannel implements BarChannel {
  final Future<Outcome<BarContent>?> Function(BarSource source) _fetch;

  const _ContractChannel(this._fetch);

  @override
  Transport get transport => Transport.lan;

  @override
  Future<Outcome<BarContent>?> fetch(BarSource source) => _fetch(source);
}
