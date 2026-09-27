import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';

/// Abstract contract for Delay-Tolerant Network (DTN) routing.
/// Responsible for Store-and-Forward bundle routing between disconnected nodes.
abstract class DtnRouter {
  /// Evaluates and routes an outbound message to available peers.
  /// Returns true if dispatched to at least one peer, or false if queued locally for future encounter.
  Future<bool> routeMessage(MeshMessage message, List<PeerNode> availablePeers);

  /// Called when new peers are encountered to trigger opportunistic forwarding.
  Future<void> onPeersUpdated(List<PeerNode> availablePeers);

  /// Retrieves list of messages currently awaiting forward in the DTN queue.
  Future<List<MeshMessage>> getQueuedBundles();
}
