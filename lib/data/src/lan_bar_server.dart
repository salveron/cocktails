/// The owner's half on the wire
/// ([ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)): one
/// server per device, answering what it offers and each offered bar's export
/// bytes on a path nobody guesses. Everything else is a 404.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'yaml_writer.dart';

/// Where a device answers with what it offers — the wire's own name for it,
/// read by the guest half as well as written by this one.
const lanListPath = '/bars';

/// The path is the whole of a shared bar's protection, a bar shared being a bar
/// given (ADR 22), so it is drawn from secure randomness rather than the seeded
/// draw a bar id is minted with.
const _pathBytes = 16;

final class LanBarServer {
  final HttpServer _socket;
  final Future<String?> Function(String barId) _bytesOf;
  final _offered = <String, Offering>{};

  LanBarServer._(this._socket, this._bytesOf);

  /// Binds an ephemeral port on both stacks: a resolved service may answer with
  /// an IPv6 address alone ([platform facts](../../../docs/architecture.md#platform-facts)).
  static Future<LanBarServer> start(
    Future<String?> Function(String barId) bytesOf,
  ) async {
    final socket = await HttpServer.bind(InternetAddress.anyIPv6, 0);
    final server = LanBarServer._(socket, bytesOf);
    socket.listen(server._answer);
    return server;
  }

  int get port => _socket.port;

  /// Offering a bar again keeps the path it already had, so a rename does not
  /// break a guest that kept the old one.
  void offer(String barId, String name) => _offered[barId] = (
    id: barId,
    name: name,
    path: _offered[barId]?.path ?? _mintPath(),
  );

  void withdraw(String barId) => _offered.remove(barId);

  /// Whether anything is offered at all — what an announcement's life is
  /// measured by, a device sharing nothing announcing nothing (NFR-5).
  bool get isOffering => _offered.isNotEmpty;

  Future<void> stop() => _socket.close(force: true);

  Future<void> _answer(HttpRequest request) async {
    final response = request.response;
    if (request.method != 'GET') return _refuse(response);
    if (request.uri.path == lanListPath) {
      return _send(response, encodeOfferings(_offered.values.toList()));
    }
    final bytes = await _bytesAt(request.uri.path);
    return bytes == null ? _refuse(response) : _send(response, bytes);
  }

  /// A bar the store can no longer answer for reads as one not offered: the
  /// wire has three readings and none of them is *broken* (ADR 22).
  Future<String?> _bytesAt(String path) async {
    for (final offering in _offered.values) {
      if ('/${offering.path}' == path) {
        try {
          return await _bytesOf(offering.id);
        } on Exception {
          return null;
        }
      }
    }
    return null;
  }

  static String _mintPath() {
    final draw = Random.secure();
    return [
      for (var i = 0; i < _pathBytes; i++)
        draw.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  static Future<void> _send(HttpResponse response, String text) {
    response.headers.contentType = ContentType(
      'application',
      'yaml',
      charset: 'utf-8',
    );
    response.add(utf8.encode(text));
    return response.close();
  }

  static Future<void> _refuse(HttpResponse response) {
    response.statusCode = HttpStatus.notFound;
    return response.close();
  }
}
