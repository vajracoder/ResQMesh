import '../mesh/models/peer_node.dart';

/// Abstract contract for peer discovery across local communication mediums.
/// Implemented by BLE discovery service in Phase 4.
abstract class PeerDiscoveryService {
  /// Stream emitting real-time lists of currently visible nearby nodes.
  Stream<List<PeerNode>> get peersStream;

  /// Current snapshot of nearby discovered nodes.
  List<PeerNode> get currentPeers;

  /// Whether active scanning/advertising is currently underway.
  bool get isDiscovering;

  /// Initiates peer discovery.
  Future<void> startDiscovery();

  /// Stops peer discovery.
  Future<void> stopDiscovery();

  /// Releases resources.
  void dispose();
}
