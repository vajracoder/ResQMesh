import '../../core/constants/app_constants.dart';
import '../mesh/models/mesh_message.dart';
import 'models/relay_decision.dart';

/// Real DTN store-and-forward relay decision engine.
///
/// Evaluates message forwarding policies against candidate peers to enforce:
/// - Hop count limits (routing storm prevention)
/// - TTL expiration gating
/// - Loop prevention (self-origin, path history)
/// - Duplicate transmission prevention (peer-specific ACK and forward history)
/// - Link quality gating (RSSI thresholds and retry limits)
/// - Urgency priority scoring (SOS/Critical prioritised)
class MultiHopDecisionEngine implements RelayDecisionEngine {
  final int minRssi;
  final int maxHops;
  final int minTtlSeconds;
  final int maxRetriesPerPeer;

  const MultiHopDecisionEngine({
    this.minRssi = AppConstants.minRelayRssi,
    this.maxHops = AppConstants.maxHopCount,
    this.minTtlSeconds = AppConstants.minTtlForRelaySeconds,
    this.maxRetriesPerPeer = AppConstants.maxRelayRetriesPerPeer,
  });

  @override
  int priorityScore(MeshMessage message) {
    int baseScore;
    if (message.isSos) {
      baseScore = 100;
    } else {
      switch (message.priority) {
        case MessagePriority.critical:
          baseScore = 100;
          break;
        case MessagePriority.high:
          baseScore = 80;
          break;
        case MessagePriority.normal:
          baseScore = 50;
          break;
        case MessagePriority.low:
          baseScore = 20;
          break;
      }
    }
    final score = baseScore - (message.hopCount * 5);
    return score.clamp(1, 100);
  }

  @override
  RelayDecisionOutput evaluate(RelayDecisionInput input) {
    final message = input.message;
    final peer = input.peer;
    final score = priorityScore(message);

    // 1. Expiration check
    if (message.isExpired() || input.ttlRemainingSeconds <= minTtlSeconds) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.expired,
        reason:
            'Message expired or remaining TTL (${input.ttlRemainingSeconds}s) <= threshold (${minTtlSeconds}s)',
        priorityScore: 0,
      );
    }

    // 2. Loop prevention & self-origin
    if (peer.nodeId == input.localNodeId) {
      return const RelayDecisionOutput(
        outcome: RelayOutcome.selfOrigin,
        reason: 'Cannot forward to local node',
        priorityScore: 0,
      );
    }

    if (peer.nodeId == message.originNodeId) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.selfOrigin,
        reason: 'Peer (${peer.nodeId}) is the origin of this message',
        priorityScore: 0,
      );
    }

    // 3. Hop limit check
    if (message.hopCount >= message.maxHops || message.hopCount >= maxHops) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.hopLimitReached,
        reason:
            'Hop limit reached: hopCount=${message.hopCount}, maxHops=${message.maxHops}',
        priorityScore: 0,
      );
    }

    // 4. Duplicate checks (ACK or already forwarded)
    if (input.peerAlreadyAcked) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.duplicate,
        reason:
            'Peer (${peer.nodeId}) already acknowledged message ${message.messageId}',
        priorityScore: 0,
      );
    }

    if (input.peerAlreadyForwarded) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.duplicate,
        reason:
            'Message ${message.messageId} already forwarded to peer (${peer.nodeId})',
        priorityScore: 0,
      );
    }

    // Loop prevention: check path history
    if (message.hasVisitedNode(peer.nodeId)) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.duplicate,
        reason: 'Peer (${peer.nodeId}) is in the message forwarding path',
        priorityScore: 0,
      );
    }

    // 5. Peer suitability
    if (peer.rssi < minRssi) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.peerUnsuitable,
        reason: 'Peer RSSI (${peer.rssi}) is below threshold ($minRssi)',
        priorityScore: score,
      );
    }

    if (input.retryCountForPeer >= maxRetriesPerPeer) {
      return RelayDecisionOutput(
        outcome: RelayOutcome.peerUnsuitable,
        reason:
            'Max retries ($maxRetriesPerPeer) reached for peer (${peer.nodeId})',
        priorityScore: score,
      );
    }

    // 6. Eligible for forward
    return RelayDecisionOutput(
      outcome: RelayOutcome.forward,
      reason: 'Message approved for forwarding to peer (${peer.nodeId})',
      priorityScore: score,
    );
  }
}
