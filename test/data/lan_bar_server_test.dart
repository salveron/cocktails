/// The owner's half on the wire (ADR 22): which bars a device says it offers,
/// the bytes behind each unguessable path, and a 404 for everything else. What
/// the list *looks* like is the emitter's, and is pinned in its own test.
library;

import 'package:cocktails/data/src/lan_bar_server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/data_test_support.dart';

void main() {
  /// A server over [bars], a bar id answering the bytes kept for it and any
  /// other id answering null, the way a store that lost one would.
  Future<LanBarServer> serving(Map<String, String> bars) async {
    final server = await LanBarServer.start((id) async => bars[id]);
    addTearDown(server.stop);
    return server;
  }

  test('the port it binds is one the system handed out', () async {
    final server = await serving({});
    expect(server.port, greaterThan(0));
  });

  test('a device offering nothing names no bar', () async {
    final server = await serving({'a1': 'first bar'});
    expect(await offeredOn(server.port), isEmpty);
  });

  /// 128 bits of it: the path is the whole of a shared bar's protection, so a
  /// guessable one would hand every bar on the device to anyone on the network.
  test('an offered bar is named, and given a path nobody guesses', () async {
    final server = await serving({'a1': 'first bar'});
    server.offer('a1', 'Home bar');
    final listed = await offeredOn(server.port);
    expect(listed.keys, ['a1']);
    expect(listed['a1']!.name, 'Home bar');
    expect(listed['a1']!.path, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('the path a bar is listed at serves that bar', () async {
    final server = await serving({'a1': 'first bar', 'b2': 'second bar'});
    server.offer('a1', 'Home bar');
    server.offer('b2', 'Other bar');
    final served = await askServer(
      server.port,
      '/${(await offeredOn(server.port))['a1']!.path}',
    );
    expect(served.status, 200);
    expect(served.body, 'first bar');
  });

  /// One path leaking would otherwise reach every bar the device shares.
  test('each offered bar is at a path of its own', () async {
    final server = await serving({'a1': 'first bar', 'b2': 'second bar'});
    server.offer('a1', 'Home bar');
    server.offer('b2', 'Other bar');
    final listed = await offeredOn(server.port);
    expect(listed['a1']!.path, isNot(listed['b2']!.path));
  });

  /// A guest that kept the path keeps working across a rename: a name is a
  /// label, and the path is not minted from it (FR-BAR-1).
  test('offering a bar again keeps the path it already had', () async {
    final server = await serving({'a1': 'first bar'});
    server.offer('a1', 'Home bar');
    final before = (await offeredOn(server.port))['a1']!.path;
    server.offer('a1', 'Renamed bar');
    final after = (await offeredOn(server.port))['a1']!;
    expect(after.path, before);
    expect(after.name, 'Renamed bar');
  });

  test(
    'a withdrawn bar leaves the list and its path stops answering',
    () async {
      final server = await serving({'a1': 'first bar'});
      server.offer('a1', 'Home bar');
      final path = (await offeredOn(server.port))['a1']!.path;
      server.withdraw('a1');
      expect(await offeredOn(server.port), isEmpty);
      expect((await askServer(server.port, '/$path')).status, 404);
    },
  );

  test('a path nobody was given is refused', () async {
    final server = await serving({'a1': 'first bar'});
    server.offer('a1', 'Home bar');
    expect((await askServer(server.port, '/${'0' * 32}')).status, 404);
  });

  /// The bar is offered, so it is listed; the store having lost it is not one
  /// of the three things the wire can say, so it reads as a path that is gone.
  test('an offered bar the store cannot answer for is refused', () async {
    final server = await serving({});
    server.offer('a1', 'Home bar');
    final path = (await offeredOn(server.port))['a1']!.path;
    expect((await askServer(server.port, '/$path')).status, 404);
  });

  test('anything but a GET is refused, the list included', () async {
    final server = await serving({'a1': 'first bar'});
    server.offer('a1', 'Home bar');
    expect((await askServer(server.port, '/bars', method: 'POST')).status, 404);
  });

  test('a path outside the two it answers is refused', () async {
    final server = await serving({'a1': 'first bar'});
    expect((await askServer(server.port, '/')).status, 404);
    expect((await askServer(server.port, '/bars/a1')).status, 404);
  });
}
