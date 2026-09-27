import '../../mesh/models/mesh_message.dart';
import '../../mesh/models/peer_node.dart';

/// The outcome of the relay decision engine for a specific message+peer pair.
enum RelayOutcome {
  /// Forward this message to this peer immediately.
  forward,

  /// Message passes policy but no eligible peer is currently reachable; store for later.
  storeOnly,

  /// Message has already been delivered to or seen by this peer — skip.
  duplicate,

  /// Message TTL has elapsed — discard without forwarding.
  expired,

  /// Hop limit reached — discard to prevent routing storms.
  hopLimitReached,

  /// Peer RSSI or capabilities do not meet relay quality threshold.
  peerUnsuitable,

  /// Message priority is too low for the current network conditions.
  priorityTooLow,

  /// This node is the message's original creator — re-broadcasting would be a loop.
  selfOrigin,
}

/// Input context provided to the relay decision engine for evaluation.
class RelayDecisionInput {
  final MeshMessage message;
  final PeerNode peer;

  /// Seconds of TTL remaining on the message.
  final int ttlRemainingSeconds;

  /// Whether this peer's node ID already appears in the message forwarding history.
  final bool peerAlreadyForwarded;

  /// Whether this peer has been confirmed to have received this messageId via ACK.
  final bool peerAlreadyAcked;

  /// Whether we have already attempted to send to this peer and failed recently.
  final bool recentFailureToThisPeer;

  /// Number of times we have retried forwarding to this specific peer.
  final int retryCountForPeer;

  /// The local node's own node ID (to detect self-origin loops).
  final String localNodeId;

  const RelayDecisionInput({
    required this.message,
    required this.peer,
    required this.ttlRemainingSeconds,
    required this.localNodeId,
    this.peerAlreadyForwarded = false,
    this.peerAlreadyAcked = false,
    this.recentFailureToThisPeer = false,
    this.retryCountForPeer = 0,
  });
}

/// Output decision produced by the relay decision engine.
class RelayDecisionOutput {
  final RelayOutcome outcome;

  /// Human-readable reason for this decision (for diagnostics/logging).
  final String reason;

  /// Priority score used to order the relay transmission queue.
  /// Higher = more urgent. Ranges 0–100.
  final int priorityScore;

  const RelayDecisionOutput({
    required this.outcome,
    required this.reason,
    this.priorityScore = 50,
  });

  bool get shouldForward => outcome == RelayOutcome.forward;

  @override
  String toString() =>
      'RelayDecisionOutput(outcome=$outcome, score=$priorityScore, reason=$reason)';
}

/// Abstract contract for the Step 6 relay decision engine.
///
/// Evaluates whether a specific [MeshMessage] should be forwarded to a
/// specific [PeerNode] given the [RelayDecisionInput] context.
abstract class RelayDecisionEngine {
  RelayDecisionOutput evaluate(RelayDecisionInput input);

  /// Priority score for ordering messages in the transmission queue.
  /// Higher score = higher urgency.
  int priorityScore(MeshMessage message);
}
