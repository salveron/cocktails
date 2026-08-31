/// The one file naming a Bonsoir type
/// ([ADR 27](../../../docs/adr/27-nearby-comes-off-bonsoir.md)): announcing a
/// device on DNS-SD and finding the others, in names, ports and addresses. The
/// way out is `nsd` behind these same three operations.
library;

import 'dart:io';

import 'package:bonsoir/bonsoir.dart';

/// What every device sharing a bar answers to.
const lanServiceType = '_cocktails._tcp';

/// A browse is bounded and never left running (ADR 22).
const lanBrowseWindow = Duration(seconds: 4);

/// A platform refusing an announcement says so by never answering, and a
/// caller that waited forever would hang the gesture behind it.
const lanAnnounceWindow = Duration(seconds: 10);

/// A device found nearby, resolved: addresses rather than a hostname, Android
/// resolving no `.local` name from a socket (ADR 27).
class LanService {
  final String name;
  final int port;
  final List<String> addresses;

  const LanService({
    required this.name,
    required this.port,
    required this.addresses,
  });
}

/// A live announcement, [name] being what the network granted rather than what
/// was asked: a clash is settled by suffix, so this is the name to keep and the
/// one a guest asks for again (ADR 27).
abstract interface class LanAnnouncement {
  String get name;

  Future<void> stop();
}

/// How one is made, so what owns an announcement is testable without a device:
/// the platform crosses here and nowhere above it (ADR 18).
typedef LanAnnouncer =
    Future<LanAnnouncement> Function({required String name, required int port});

/// The other two crossings, seams for the same reason: what devices are out
/// there, and whether this one is on a network at all.
typedef LanBrowser = Future<List<LanService>> Function();

typedef LanReach = Future<bool> Function();

/// Whether this device is on a network of its own — the reading that parts
/// *offline* from an owner who is simply not there (FR-BAR-5, ADR 22). Loopback
/// is not a network: nothing else can be reached over it.
Future<bool> onANetwork() async {
  try {
    final interfaces = await NetworkInterface.list();
    return interfaces.any(
      (interface) => interface.addresses.any((at) => !at.isLoopback),
    );
  } on Exception {
    return false;
  }
}

final class _Broadcast implements LanAnnouncement {
  @override
  final String name;
  final BonsoirBroadcast _broadcast;

  const _Broadcast(this.name, this._broadcast);

  @override
  Future<void> stop() => _broadcast.stop();
}

/// Announces [name] on [port] and answers once the network has granted a name,
/// throwing where it never does — which is the only way a refusal reaches here.
Future<LanAnnouncement> announce({
  required String name,
  required int port,
}) async {
  final broadcast = BonsoirBroadcast(
    service: BonsoirService(name: name, type: lanServiceType, port: port),
  );
  await broadcast.initialize();
  final started = broadcast.eventStream!
      .where((event) => event is BonsoirBroadcastStartedEvent)
      .cast<BonsoirBroadcastStartedEvent>()
      .first
      .timeout(lanAnnounceWindow);
  await broadcast.start();
  return _Broadcast((await started).service.name, broadcast);
}

/// Every device answering [lanServiceType] within [within], one entry each: a
/// service is resolved only once found, and the browse is closed either way.
Future<List<LanService>> browse({Duration within = lanBrowseWindow}) async {
  final discovery = BonsoirDiscovery(type: lanServiceType);
  await discovery.initialize();
  final found = <String, LanService>{};
  final listening = discovery.eventStream!.listen((event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        event.service.resolve(discovery.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        if (service.hostAddresses.isNotEmpty) {
          found[service.name] = LanService(
            name: service.name,
            port: service.port,
            addresses: service.hostAddresses,
          );
        }
      default:
        break;
    }
  });
  await discovery.start();
  await Future<void>.delayed(within);
  await listening.cancel();
  await discovery.stop();
  return found.values.toList(growable: false);
}
