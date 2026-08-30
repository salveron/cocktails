/// The LAN transport's owner half (FR-BAR-6,
/// [ADR 22](../../../docs/adr/22-a-bar-travels-behind-one-seam.md)): one server
/// and one announcement per device, both coming up with the first offer and
/// down with the last withdrawal, so a device sharing nothing announces
/// nothing (NFR-5).
library;

import 'package:cocktails/domain/domain.dart';

import 'bar_channel.dart';
import 'lan_bar_server.dart';
import 'lan_discovery.dart';

final class LanBarChannel implements BarOfferings {
  final Future<String?> Function(String barId) _bytesOf;
  final String _deviceName;
  final LanAnnouncer _announcer;

  /// Kept as the futures rather than what they answer, so two offers at once
  /// raise one server and one announcement between them rather than each.
  Future<LanBarServer>? _serving;
  Future<LanAnnouncement>? _announcing;

  LanBarChannel({
    required this._bytesOf,
    required this._deviceName,
    this._announcer = announce,
  });

  @override
  Transport get transport => Transport.lan;

  @override
  Future<void> offer(String barId, String name) async {
    final server = await (_serving ??= LanBarServer.start(_bytesOf));
    server.offer(barId, name);
    await (_announcing ??= _announcer(name: _deviceName, port: server.port));
  }

  /// Withdrawing what was never offered is not an error: nothing is announced
  /// on its behalf, so there is nothing to silence.
  @override
  Future<void> withdraw(String barId) async {
    final serving = _serving;
    if (serving == null) return;
    final server = await serving;
    server.withdraw(barId);
    if (server.isOffering) return;
    final announcing = _announcing;
    _serving = null;
    _announcing = null;
    if (announcing != null) await (await announcing).stop();
    await server.stop();
  }
}
