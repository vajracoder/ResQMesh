import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import '../storage/repositories/dtn_message_repository.dart';
import '../transport/ble_transport.dart';
import 'dtn_router_interface.dart';
import 'models/relay_decision.dart';
import 'models/relay_metrics.dart';
import 'multi_hop_decision_engine.dart';
import 'relay_scheduler.dart';

/// DTN Router that utilizes [BleTransport] and [RelayScheduler]
/// for opportunistic store-and-forward multi-hop bundle routing across physical devices.
class BleDtnRouter implements DtnRouter {
  final BleTransport? transport;
  final DtnMessageRepository? messageRepository;
  final RelayScheduler relayScheduler;
  final RelayDecisionEngine decisionEngine;
  final RelayMetrics metrics;

  BleDtnRouter({
    this.transport,
    this.messageRepository,
    RelayScheduler? relayScheduler,
    RelayDecisionEngine? decisionEngine,
    RelayMetrics? metrics,
    String? localNodeId,
  })  : metrics = metrics ?? RelayMetrics(),
        decisionEngine = decisionEngine ?? const MultiHopDecisionEngine(),
        relayScheduler = relayScheduler ??
            RelayScheduler(
              transport: transport,
              messageRepository: messageRepository,
              decisionEngine: decisionEngine ?? const MultiHopDecisionEngine(),
              metrics: metrics ?? RelayMetrics(),
              localNodeId: localNodeId ?? 'node-local',
            );

  @override
  Future<bool> routeMessage(
      MeshMessage message, List<PeerNode> availablePeers) async {
    // 1. Enqueue in relay scheduler
    relayScheduler.scheduleMessage(message);

    // 2. Perform immediate sweep if peers are present
    if (availablePeers.isNotEmpty) {
      final relayedCount = await relayScheduler.sweepRelay(availablePeers);
      if (relayedCount > 0) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<void> onPeersUpdated(List<PeerNode> availablePeers) async {
    if (availablePeers.isEmpty || relayScheduler.outboxCount == 0) return;
    await relayScheduler.sweepRelay(availablePeers);
  }

  @override
  Future<List<MeshMessage>> getQueuedBundles() async {
    return relayScheduler.outbox;
  }
}
