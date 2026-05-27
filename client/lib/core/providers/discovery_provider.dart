import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/discovery_service.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  final service = DiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});

final discoveredServersProvider = StreamProvider<List<DiscoveredServer>>((ref) {
  return ref.watch(discoveryServiceProvider).onServersFound;
});
