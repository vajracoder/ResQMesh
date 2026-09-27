import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import '../storage/repositories/dtn_message_repository.dart';
import '../transport/ble_transport.dart';
import 'dtn_router_interface.dart';

/// Production DTN Router for Step 5 that utilizes [BleTransport] to transmit
/// emergency bundles to directly encountered nearby peers.
class BleDtnRouter implements DtnRouter {
  final BleTransport transport;
  final DtnMessageRepository? messageRepository;
  final List<MeshMessage> _outboxQueue = [];

  BleDtnRouter({
    required this.transport,
    this.messageRepository,
  });

  @override
  Future<bool> routeMessage(MeshMessage message, List<PeerNode> availablePeers) async {
    // 1. Filter for reachable, active ResQMesh peers
    final eligiblePeers = availablePeers.where((p) {
      if (!p.isResQMeshPeer) return false;
      if (message.destinationNodeId != '*' && message.destinationNodeId.isNotEmpty) {
        return p.nodeId == message.destinationNodeId;
      }
      return true;
    }).toList();

    // 2. If no peers are reachable, retain bundle in local store-and-forward queue
    if (eligiblePeers.isEmpty) {
      _outboxQueue.removeWhere((m) => m.messageId == message.messageId);
      _outboxQueue.add(message.copyWith(status: MessageStatus.queued));
      return false;
    }

    // 3. Select peer (sort by strongest RSSI for direct link stability)
    eligiblePeers.sort((a, b) => b.rssi.compareTo(a.rssi));
    final targetPeer = eligiblePeers.first;

    // 4. Transmit through BLE transport (fragmentation + GATT write + ACK await)
    final delivered = await transport.sendMeshMessage(message, targetPeer);

    if (delivered) {
      _outboxQueue.removeWhere((m) => m.messageId == message.messageId);
      return true;
    } else {
      // Retain in queue on transmission or ACK failure
      _outboxQueue.removeWhere((m) => m.messageId == message.messageId);
      _outboxQueue.add(message.copyWith(status: MessageStatus.queued));
      return false;
    }
  }

  @override
  Future<void> onPeersUpdated(List<PeerNode> availablePeers) async {
    // Opportunistic forwarding of queued bundles when peers appear
    if (availablePeers.isEmpty || _outboxQueue.isEmpty) return;

    final queuedToForward = List<MeshMessage>.from(_outboxQueue);
    for (final bundle in queuedToForward) {
      final success = await routeMessage(bundle, availablePeers);
      if (success) {
        if (messageRepository != null) {
          await messageRepository!.updateMessageStatus(
            bundle.messageId,
            MessageStatus.deliveredToPeer,
          );
        }
      }
    }
  }

  @override
  Future<List<MeshMessage>> getQueuedBundles() async {
    return List.unmodifiable(_outboxQueue);
  }
}
