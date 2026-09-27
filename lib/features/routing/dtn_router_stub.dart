import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import 'dtn_router_interface.dart';

/// Baseline in-memory DTN store-and-forward router for Step 1.
/// Preserves messages in local outbox queue when offline / no peers are encountered.
class DtnRouterStub implements DtnRouter {
  final List<MeshMessage> _bundleOutbox = [];

  @override
  Future<bool> routeMessage(MeshMessage message, List<PeerNode> availablePeers) async {
    // If no peers are reachable, retain message in store-and-forward queue
    if (availablePeers.isEmpty) {
      _bundleOutbox.add(message.copyWith(status: MessageStatus.queued));
      return false;
    }

    // When peers exist (post Step 4/6), message will be dispatched over BLE.
    _bundleOutbox.add(message.copyWith(status: MessageStatus.forwarded));
    return true;
  }

  @override
  Future<void> onPeersUpdated(List<PeerNode> availablePeers) async {
    // Will trigger forwarding of queued bundles upon encountering peers in Step 7.
  }

  @override
  Future<List<MeshMessage>> getQueuedBundles() async {
    return List.unmodifiable(_bundleOutbox);
  }
}
