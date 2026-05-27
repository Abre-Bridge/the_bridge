import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

class DiscoveredServer {
  final String name;
  final String url;
  final String ip;
  final int port;

  DiscoveredServer({
    required this.name,
    required this.url,
    required this.ip,
    required this.port,
  });
}

class DiscoveryService {
  final String _serviceType = '_thebridge._tcp.local';
  final _controller = StreamController<List<DiscoveredServer>>.broadcast();
  final Map<String, DiscoveredServer> _foundServers = {};
  MDnsClient? _client;

  Stream<List<DiscoveredServer>> get onServersFound => _controller.stream;

  Future<void> scanForServers({int durationSeconds = 5}) async {
    _foundServers.clear();
    _controller.add([]);
    
    _client = MDnsClient();
    await _client!.start();

    await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(_serviceType),
    )) {
      await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      )) {
        await for (final IPAddressResourceRecord ip in _client!.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        )) {
          final serverName = ptr.domainName.split('.').first;
          final serverUrl = 'http://${ip.address.address}:${srv.port}';
          
          final discovered = DiscoveredServer(
            name: serverName,
            url: serverUrl,
            ip: ip.address.address,
            port: srv.port,
          );
          
          _foundServers[serverUrl] = discovered;
          _controller.add(_foundServers.values.toList());
        }
      }
    }

    _client!.stop();
  }

  void dispose() {
    _client?.stop();
    _controller.close();
  }
}
