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

  Future<void> scanForServers({int durationSeconds = 3}) async {
    _foundServers.clear();
    _controller.add([]);
    
    _client = MDnsClient();
    try {
      await _client!.start();

      // Look for PTR records (service pointers)
      await for (final PtrResourceRecord ptr in _client!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      ).timeout(Duration(seconds: durationSeconds), onTimeout: (sink) => sink.close())) {
        
        // For each pointer, lookup SRV and IP in parallel
        _lookupServerDetails(ptr);
      }
    } catch (e) {
      print('Discovery error: $e');
    } finally {
      Future.delayed(Duration(seconds: durationSeconds + 1), () {
        _client?.stop();
      });
    }
  }

  Future<void> _lookupServerDetails(PtrResourceRecord ptr) async {
    try {
      await for (final SrvResourceRecord srv in _client!.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      ).timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
        
        await for (final IPAddressResourceRecord ip in _client!.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        ).timeout(const Duration(seconds: 2), onTimeout: (sink) => sink.close())) {
          
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
    } catch (e) {
      print('Detail lookup error for ${ptr.domainName}: $e');
    }
  }

  void dispose() {
    _client?.stop();
    _controller.close();
  }
}
