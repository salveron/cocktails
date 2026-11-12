/// The LAN transport, both halves
/// ([ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)): the
/// owner's one server and announcement per device (FR-BAR-6, NFR-5); the
/// guest's owns nothing and resolves each fetch afresh (FR-BAR-5/8).
library;

import 'dart:convert';
import 'dart:io';

import 'package:cocktails/domain/domain.dart';

import 'bar_channel.dart';
import 'lan_bar_server.dart';
import 'lan_discovery.dart';
import 'sourced_issue.dart';
import 'yaml_codec.dart';
import 'yaml_offerings_reader.dart';
import 'yaml_writer.dart' show Offering;

final class LanBarChannel implements BarChannel, BarFinder, BarOfferings {
  final Future<String?> Function(String barId) _bytesOf;
  final String Function() _deviceName;
  final LanAnnouncer _announcer;
  final LanBrowser _browser;
  final LanReach _reach;

  /// Held as futures so concurrent offers share one server and announcement.
  Future<LanBarServer>? _serving;
  Future<LanAnnouncement>? _announcing;

  LanBarChannel({
    required this._bytesOf,
    required this._deviceName,
    this._announcer = announce,
    this._browser = browsing,
    this._reach = onANetwork,
  });

  /// The instance to re-resolve and the id to find, never an address (ADR 22).
  /// The id leads, having no '/', so an instance name may contain one.
  static BarSource sourceFor({
    required String barId,
    required String instance,
  }) => BarSource(via: Transport.lan, at: '$barId/$instance', from: instance);

  @override
  Transport get transport => Transport.lan;

  /// Each failed step answers its reason and never throws (FR-BAR-5/8, ADR 22).
  @override
  Future<Outcome<BarContent>?> fetch(BarSource source) async {
    final asked = _askedFor(source);
    if (asked == null) return _unreached(UnreachableReason.notFound);
    if (!await _reach()) return _unreached(UnreachableReason.offline);
    final service = await _resolve(asked.instance);
    if (service == null) return _unreached(UnreachableReason.notFound);
    // Unreadable list: not askable. Missing bar or document: withdrawn.
    final listed = readOfferings(await _read(service, lanListPath) ?? '');
    if (listed == null) return _unreached(UnreachableReason.notFound);
    final offered = listed[asked.barId];
    if (offered == null) return _unreached(UnreachableReason.withdrawn);
    final document = await _read(service, '/${offered.path}');
    if (document == null) return _unreached(UnreachableReason.withdrawn);
    return const YamlCodec().decode(document);
  }

  /// Yields as each device answers (FR-BAR-8), so a first match can act early.
  /// Devices that cannot list bars are skipped; no yield means none nearby.
  @override
  Stream<List<Found>> nearby() async* {
    final found = <Found>[];
    try {
      await for (final service in _browser()) {
        final offered = await _offeredBy(service);
        if (offered.isEmpty) continue;
        found.addAll(offered);
        yield [...found];
      }
    } on Exception {
      return;
    }
  }

  Future<List<Found>> _offeredBy(LanService service) async {
    final listed = readOfferings(await _read(service, lanListPath) ?? '');
    return [
      for (final offered in listed?.values ?? const <Offering>[])
        (
          source: sourceFor(barId: offered.id, instance: service.name),
          name: offered.name,
        ),
    ];
  }

  /// Null where [BarSource.at] lacks either half, as a hand-edited index may.
  ({String barId, String instance})? _askedFor(BarSource source) {
    final split = source.at.indexOf('/');
    if (split <= 0 || split == source.at.length - 1) return null;
    return (
      barId: source.at.substring(0, split),
      instance: source.at.substring(split + 1),
    );
  }

  Future<LanService?> _resolve(String instance) async {
    try {
      await for (final service in _browser()) {
        if (service.name == instance) return service;
      }
      return null;
    } on Exception {
      return null;
    }
  }

  /// Tries each address in turn, IPv6-only ones included (ADR 27);
  /// null when none reads.
  Future<String?> _read(LanService service, String path) async {
    final client = HttpClient();
    try {
      for (final address in service.addresses) {
        try {
          final request = await client.get(address, service.port, path);
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) continue;
          return await utf8.decodeStream(response);
        } on Exception {
          continue;
        }
      }
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Outcome<BarContent> _unreached(UnreachableReason why) =>
      Unreachable<BarContent>(why);

  @override
  Future<void> offer(String barId, String name) async {
    final server = await (_serving ??= LanBarServer.start(_bytesOf));
    server.offer(barId, name);
    await (_announcing ??= _announcer(name: _deviceName(), port: server.port));
  }

  /// Withdrawing what was never offered is not an error (nothing to silence).
  @override
  Future<void> withdraw(String barId) async {
    final serving = _serving;
    if (serving == null) return;
    final server = await serving;
    server.withdraw(barId);
    if (!server.isOffering) await stop();
  }

  /// Both halves down at once, on the last withdrawal or on disposal. Offers
  /// stay on the record and are announced again at the next start (ADR 22).
  Future<void> stop() async {
    final serving = _serving;
    final announcing = _announcing;
    _serving = null;
    _announcing = null;
    if (announcing != null) await (await announcing).stop();
    if (serving != null) await (await serving).stop();
  }
}
