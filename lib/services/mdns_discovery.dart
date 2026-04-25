import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// Risultato discovery mDNS servizio `_retrowave._tcp`.
class MdnsEndpoint {
  MdnsEndpoint({required this.host, required this.port, this.ipv4});

  final String host;
  final int port;
  final InternetAddress? ipv4;

  String get baseUrl {
    if (ipv4 != null) {
      final a = ipv4!.address;
      return port == 80 ? 'http://$a' : 'http://$a:$port';
    }
    final h = host.endsWith('.') ? host.substring(0, host.length - 1) : host;
    return port == 80 ? 'http://$h' : 'http://$h:$port';
  }
}

/// Scansiona `_retrowave._tcp.local` e risolve host/port (e A dove possibile).
Future<List<MdnsEndpoint>> discoverRetrowaveEndpoints({
  Duration ptrTimeout = const Duration(seconds: 6),
}) async {
  final MDnsClient client = MDnsClient();
  await client.start();
  final List<MdnsEndpoint> out = [];
  final Set<String> seen = {};

  try {
    await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer('_retrowave._tcp.local'),
      timeout: ptrTimeout,
    )) {
      final String instance = ptr.domainName;
      await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(instance),
        timeout: const Duration(seconds: 3),
      )) {
        String target = srv.target;
        if (target.endsWith('.')) {
          target = target.substring(0, target.length - 1);
        }
        final key = '$target:${srv.port}';
        if (seen.contains(key)) continue;
        seen.add(key);

        InternetAddress? ip;
        await for (final IPAddressResourceRecord a in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4('$target.local'),
          timeout: const Duration(seconds: 2),
        )) {
          ip = a.address;
          break;
        }
        ip ??= await _tryLookup('$target.local');
        ip ??= await _tryLookup(target);

        out.add(MdnsEndpoint(host: target, port: srv.port, ipv4: ip));
      }
    }
  } catch (_) {
    // Ignora errori di rete/emulatore
  } finally {
    client.stop();
  }

  return out;
}

Future<InternetAddress?> _tryLookup(String host) async {
  try {
    final list = await InternetAddress.lookup(host);
    for (final a in list) {
      if (a.type == InternetAddressType.IPv4) return a;
    }
    return list.isNotEmpty ? list.first : null;
  } catch (_) {
    return null;
  }
}
