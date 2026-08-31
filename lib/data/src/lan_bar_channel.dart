/// The LAN transport, both halves
/// ([ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)): the
/// owner's, one server and one announcement per device coming up with the first
/// offer and down with the last withdrawal (FR-BAR-6, NFR-5); and the guest's,
/// which owns nothing at all — every fetch resolves the instance afresh, reads
/// what it offers and takes the path that names (FR-BAR-5/8).
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

  /// Kept as the futures rather than what they answer, so two offers at once
  /// raise one server and one announcement between them rather than each.
  Future<LanBarServer>? _serving;
  Future<LanAnnouncement>? _announcing;

  LanBarChannel({
    required this._bytesOf,
    required this._deviceName,
    this._announcer = announce,
    this._browser = browse,
    this._reach = onANetwork,
  });

  /// Where a bar found nearby is kept from: the instance to resolve again and
  /// the id to look for in what it offers, never an address (ADR 22). The id
  /// leads, being the half with a fixed alphabet, so the instance keeps
  /// whatever name the network granted it, separators and all.
  static BarSource sourceFor({
    required String barId,
    required String instance,
  }) => BarSource(via: Transport.lan, at: '$barId/$instance', from: instance);

  @override
  Transport get transport => Transport.lan;

  /// FR-BAR-5/8: the instance resolved afresh, its list read, and the bytes
  /// taken from the path it names. Where the ask stopped is which of the three
  /// readings it answers (ADR 22) — this device off any network, an instance
  /// that will not resolve, or one whose list no longer names the bar. Never
  /// throws: a fetch answers.
  @override
  Future<Outcome<BarContent>?> fetch(BarSource source) async {
    final asked = _askedFor(source);
    if (asked == null) return _unreached(UnreachableReason.notFound);
    if (!await _reach()) return _unreached(UnreachableReason.offline);
    final service = await _resolve(asked.instance);
    if (service == null) return _unreached(UnreachableReason.notFound);
    // A list that will not read is an instance that cannot be asked; one that
    // reads without naming the bar, or a path answering nothing, is an owner
    // who has withdrawn it.
    final listed = readOfferings(await _read(service, lanListPath) ?? '');
    if (listed == null) return _unreached(UnreachableReason.notFound);
    final offered = listed[asked.barId];
    if (offered == null) return _unreached(UnreachableReason.withdrawn);
    final document = await _read(service, '/${offered.path}');
    if (document == null) return _unreached(UnreachableReason.withdrawn);
    return const YamlCodec().decode(document);
  }

  /// FR-BAR-8: every bar every device nearby says it offers, asked once and
  /// answered from one browse. A device that will not say is left out rather
  /// than named with nothing under it — there is nothing a reader could do
  /// with it, and a browse turning up no one is the same news either way.
  @override
  Future<List<Found>> nearby() async {
    final List<LanService> services;
    try {
      services = await _browser();
    } on Exception {
      return const [];
    }
    return [for (final service in services) ...await _offeredBy(service)];
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

  /// The two halves [BarSource.at] carries, or null where it carries neither —
  /// a hand-edited index reads as a source that cannot be found.
  ({String barId, String instance})? _askedFor(BarSource source) {
    final split = source.at.indexOf('/');
    if (split <= 0 || split == source.at.length - 1) return null;
    return (
      barId: source.at.substring(0, split),
      instance: source.at.substring(split + 1),
    );
  }

  /// The instance under that name, browsing only while this one ask needs it.
  Future<LanService?> _resolve(String instance) async {
    try {
      final found = await _browser();
      return found.where((service) => service.name == instance).firstOrNull;
    } on Exception {
      return null;
    }
  }

  /// What [service] answers at [path], or null where nothing readable came
  /// back — every address tried in turn, an IPv6-only answer being one of the
  /// shapes a device comes back in (ADR 27).
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

  /// Withdrawing what was never offered is not an error: nothing is announced
  /// on its behalf, so there is nothing to silence.
  @override
  Future<void> withdraw(String barId) async {
    final serving = _serving;
    if (serving == null) return;
    final server = await serving;
    server.withdraw(barId);
    if (!server.isOffering) await stop();
  }

  /// Both halves down at once — the last withdrawal's ending, and the
  /// composition root's on disposal. What is offered stands on the record
  /// either way, and is announced again at the next start (ADR 22).
  Future<void> stop() async {
    final serving = _serving;
    final announcing = _announcing;
    _serving = null;
    _announcing = null;
    if (announcing != null) await (await announcing).stop();
    if (serving != null) await (await serving).stop();
  }
}
