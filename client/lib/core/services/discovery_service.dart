import 'dart:async';
import 'dart:io';
import 'package:multicast_dns/multicast_dns.dart';

/// LAN Discovery Service
/// Uses mDNS to auto-discover TheBridge servers on the local network
class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final _discoveredServers = <DiscoveredServer>[];
  final _serverController =
      StreamController<List<DiscoveredServer>>.broadcast();

  Stream<List<DiscoveredServer>> get onServersFound => _serverController.stream;
  List<DiscoveredServer> get servers => _discoveredServers;

  /// Scan local network for TheBridge servers via mDNS
  Future<List<DiscoveredServer>> scanForServers({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _discoveredServers.clear();

    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      // Query for TheBridge services
      await for (final PtrResourceRecord ptr
          in client
              .lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer('_thebridge._tcp'),
              )
              .timeout(timeout, onTimeout: (sink) => sink.close())) {
        // Resolve the service
        await for (final SrvResourceRecord srv
            in client.lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )) {
          // Resolve the IP address
          await for (final IPAddressResourceRecord ip
              in client.lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )) {
            final server = DiscoveredServer(
              name: ptr.domainName,
              host: ip.address.address,
              port: srv.port,
              discoveredAt: DateTime.now(),
            );

            if (!_discoveredServers.any(
              (s) => s.host == server.host && s.port == server.port,
            )) {
              _discoveredServers.add(server);
              _serverController.add(List.from(_discoveredServers));
            }
          }
        }
      }

      client.stop();
    } catch (e) {
      // mDNS may not be available on all platforms
      // Fall back to manual configuration
    }

    // Also try common LAN addresses as fallback
    if (_discoveredServers.isEmpty) {
      await _scanCommonAddresses();
    }

    return _discoveredServers;
  }

  /// Fallback: scan common LAN addresses for TheBridge server
  Future<void> _scanCommonAddresses() async {
    final commonPorts = [3050, 3001];
    final gatewayPrefixes = await _getLocalSubnetPrefixes();

    for (final prefix in gatewayPrefixes) {
      // Scan common server addresses on the subnet
      for (final lastOctet in [1, 2, 10, 100, 200, 254]) {
        final host = '$prefix.$lastOctet';
        for (final port in commonPorts) {
          try {
            final socket = await Socket.connect(
              host,
              port,
              timeout: const Duration(milliseconds: 500),
            );
            socket.destroy();
            _discoveredServers.add(
              DiscoveredServer(
                name: 'TheBridge Server',
                host: host,
                port: port,
                discoveredAt: DateTime.now(),
              ),
            );
            _serverController.add(List.from(_discoveredServers));
          } catch (_) {
            // Not available
          }
        }
      }
    }
  }

  /// Get local subnet prefixes from network interfaces
  Future<List<String>> _getLocalSubnetPrefixes() async {
    final prefixes = <String>{};
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface_ in interfaces) {
        for (final addr in interface_.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (_) {}
    return prefixes.toList();
  }

  /// Check if a specific server is reachable
  Future<bool> checkServer(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _serverController.close();
  }
}

/// Represents a discovered TheBridge server on the LAN
class DiscoveredServer {
  final String name;
  final String host;
  final int port;
  final DateTime discoveredAt;

  DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    required this.discoveredAt,
  });

  String get url => 'http://$host:$port';

  @override
  String toString() => '$name ($host:$port)';
}
