import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import '../storage/storage_management_policy.dart';
import 'config/routing_config.dart';
import 'logging/routing_event_log.dart';
import 'metrics/routing_research_metrics.dart';
import 'models/peer_delivery_history.dart';
import 'models/relay_decision.dart';
import 'models/routing_decision_explanation.dart';
import 'scoring/message_urgency_calculator.dart';
import 'scoring/peer_scoring_model.dart';

/// Intelligent Emergency-Aware Delay-Tolerant Routing Engine for ResQMesh.
///
/// Implements multi-factor peer utility scoring, dynamic message urgency
/// calculations, role-based preference, destination awareness, and controlled
/// multi-hop dispatch policies without cloud or Internet connectivity.
class IntelligentRoutingEngine implements RelayDecisionEngine {
  final RoutingConfig config;
  final PeerScoringModel peerScorer;
  final MessageUrgencyCalculator urgencyCalculator;
  final RoutingResearchMetrics metrics;
  final RoutingEventLog eventLog;
  final StorageManagementPolicy storagePolicy;

  final Map<String, PeerDeliveryHistory> _peerHistories = {};

  IntelligentRoutingEngine({
    this.config = const RoutingConfig(),
    PeerScoringModel? peerScorer,
    MessageUrgencyCalculator? urgencyCalculator,
    RoutingResearchMetrics? metrics,
    RoutingEventLog? eventLog,
    StorageManagementPolicy? storagePolicy,
  })  : peerScorer = peerScorer ?? PeerScoringModel(config: config),
        urgencyCalculator =
            urgencyCalculator ?? MessageUrgencyCalculator(config: config),
        metrics = metrics ?? RoutingResearchMetrics(),
        eventLog = eventLog ?? RoutingEventLog(),
        storagePolicy = storagePolicy ??
            StorageManagementPolicy(capacityLimit: config.storageLimit);

  @override
  int priorityScore(MeshMessage message) {
    return urgencyCalculator.calculateUrgency(message).totalScore;
  }

  /// Evaluates whether a bundle should be forwarded to a candidate peer.
  @override
  RelayDecisionOutput evaluate(RelayDecisionInput input) {
    final stopwatch = Stopwatch()..start();
    final message = input.message;
    final peer = input.peer;

    // 1. Expiration Check
    if (message.isExpired() ||
        input.ttlRemainingSeconds <= config.minTtlForRelaySeconds) {
      metrics.recordExpired();
      eventLog.log(
        eventType: 'DROP_EXPIRED',
        messageId: message.messageId,
        peerId: peer.nodeId,
        details: 'TTL remaining (${input.ttlRemainingSeconds}s) <= threshold',
      );
      stopwatch.stop();
      metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);
      return RelayDecisionOutput(
        outcome: RelayOutcome.expired,
        reason: 'TTL expired or insufficient for reliable transmission',
        priorityScore: 0,
      );
    }

    // 2. Hop Limit Check
    if (message.hopCount >= message.maxHops ||
        message.hopCount >= config.maximumHops) {
      metrics.recordDropped();
      eventLog.log(
        eventType: 'DROP_HOP_LIMIT',
        messageId: message.messageId,
        peerId: peer.nodeId,
        details: 'Hop count (${message.hopCount}) reached max limit',
      );
      stopwatch.stop();
      metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);
      return RelayDecisionOutput(
        outcome: RelayOutcome.hopLimitReached,
        reason: 'Hop limit reached: ${message.hopCount}/${message.maxHops}',
        priorityScore: 0,
      );
    }

    // 3. Forwarding Policy Filtering
    if (config.forwardingPolicy == ForwardingPolicy.directOnly) {
      // Direct-only policy rejects relays if peer is not the destination
      if (!message.isBroadcast && peer.nodeId != message.destinationNodeId) {
        stopwatch.stop();
        metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);
        return const RelayDecisionOutput(
          outcome: RelayOutcome.storeOnly,
          reason: 'DIRECT_ONLY policy: Peer is not the final destination',
          priorityScore: 0,
        );
      }
    } else if (config.forwardingPolicy == ForwardingPolicy.priorityRelay) {
      // Priority-relay forwards only high, critical, or SOS bundles
      if (!message.isSos &&
          message.priority != MessagePriority.critical &&
          message.priority != MessagePriority.high) {
        stopwatch.stop();
        metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);
        return const RelayDecisionOutput(
          outcome: RelayOutcome.priorityTooLow,
          reason:
              'PRIORITY_RELAY policy: Normal/Info held until network clears',
          priorityScore: 0,
        );
      }
    }

    // 4. Peer Scoring Evaluation
    final history = _peerHistories[peer.nodeId];
    final peerScore = peerScorer.scorePeer(
      peer: peer,
      message: message,
      localNodeId: input.localNodeId,
      history: history,
      peerAlreadyReceived: input.peerAlreadyForwarded,
      peerAlreadyAcked: input.peerAlreadyAcked,
    );

    final urgency = urgencyCalculator.calculateUrgency(message);

    if (!peerScore.isEligible) {
      stopwatch.stop();
      metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);

      if (input.peerAlreadyAcked ||
          input.peerAlreadyForwarded ||
          message.hasVisitedNode(peer.nodeId)) {
        metrics.recordDuplicatePrevented();
        eventLog.log(
          eventType: 'SUPPRESS_DUPLICATE',
          messageId: message.messageId,
          peerId: peer.nodeId,
          details: 'Peer already received or ACKed bundle',
        );
        return RelayDecisionOutput(
          outcome: RelayOutcome.duplicate,
          reason: peerScore.disqualificationReason ?? 'Duplicate bundle',
          priorityScore: 0,
        );
      }

      if (peer.nodeId == message.originNodeId ||
          peer.nodeId == input.localNodeId) {
        return RelayDecisionOutput(
          outcome: RelayOutcome.selfOrigin,
          reason: peerScore.disqualificationReason ?? 'Self or origin node',
          priorityScore: 0,
        );
      }

      return RelayDecisionOutput(
        outcome: RelayOutcome.peerUnsuitable,
        reason: peerScore.disqualificationReason ?? 'Peer unsuitable',
        priorityScore: urgency.totalScore,
      );
    }

    stopwatch.stop();
    metrics.recordDecisionTime(stopwatch.elapsedMilliseconds);

    eventLog.log(
      eventType: 'DECISION_FORWARD',
      messageId: message.messageId,
      peerId: peer.nodeId,
      details: 'Utility: ${peerScore.totalScore.toStringAsFixed(1)}, Urgency: ${urgency.totalScore}',
    );

    return RelayDecisionOutput(
      outcome: RelayOutcome.forward,
      reason:
          'Peer selected (Utility: ${peerScore.totalScore.toStringAsFixed(1)}, Urgency: ${urgency.totalScore})',
      priorityScore: urgency.totalScore,
    );
  }

  /// Selects the best candidate peers from a list of discovered neighbors,
  /// sorting by utility score and bounding by [RoutingConfig.maxRelayFanout].
  List<PeerNode> selectTargetPeers({
    required MeshMessage message,
    required List<PeerNode> availablePeers,
    required String localNodeId,
    Map<String, Set<String>>? peerSentMap,
    Map<String, Set<String>>? peerAckMap,
  }) {
    final scoredPeers = <MapEntry<PeerNode, double>>[];

    for (final peer in availablePeers) {
      final alreadySent =
          peerSentMap?[peer.nodeId]?.contains(message.messageId) ?? false;
      final alreadyAcked =
          peerAckMap?[message.messageId]?.contains(peer.nodeId) ?? false;

      final input = RelayDecisionInput(
        message: message,
        peer: peer,
        ttlRemainingSeconds:
            message.expiresAt.difference(DateTime.now().toUtc()).inSeconds,
        localNodeId: localNodeId,
        peerAlreadyForwarded: alreadySent,
        peerAlreadyAcked: alreadyAcked,
      );

      final decision = evaluate(input);
      if (decision.shouldForward) {
        final history = _peerHistories[peer.nodeId];
        final score = peerScorer.scorePeer(
          peer: peer,
          message: message,
          localNodeId: localNodeId,
          history: history,
        );
        scoredPeers.add(MapEntry(peer, score.totalScore));
      }
    }

    // Sort descending by utility score
    scoredPeers.sort((a, b) => b.value.compareTo(a.value));

    // Limit to configured fan-out to prevent packet flooding
    final selected = scoredPeers
        .take(config.maxRelayFanout)
        .map((entry) => entry.key)
        .toList();

    return selected;
  }

  /// Generates a detailed human-readable explanation of a routing decision.
  RoutingDecisionExplanation explainDecision({
    required MeshMessage message,
    required PeerNode peer,
    required String localNodeId,
    bool peerAlreadyForwarded = false,
    bool peerAlreadyAcked = false,
  }) {
    final ttlRemaining =
        message.expiresAt.difference(DateTime.now().toUtc()).inSeconds;
    final input = RelayDecisionInput(
      message: message,
      peer: peer,
      ttlRemainingSeconds: ttlRemaining,
      localNodeId: localNodeId,
      peerAlreadyForwarded: peerAlreadyForwarded,
      peerAlreadyAcked: peerAlreadyAcked,
    );

    final decision = evaluate(input);
    final urgency = urgencyCalculator.calculateUrgency(message);
    final history = _peerHistories[peer.nodeId];
    final peerUtility = peerScorer.scorePeer(
      peer: peer,
      message: message,
      localNodeId: localNodeId,
      history: history,
      peerAlreadyReceived: peerAlreadyForwarded,
      peerAlreadyAcked: peerAlreadyAcked,
    );

    return RoutingDecisionExplanation(
      messageId: message.messageId,
      peerId: peer.nodeId,
      outcome: decision.outcome,
      reason: decision.reason,
      urgency: urgency,
      peerUtility: peerUtility,
    );
  }

  /// Records transmission result for adaptive peer utility learning.
  void recordTransmissionResult({
    required String peerId,
    required String messageId,
    required bool success,
    int hopCount = 1,
    int? rssi,
    String? failureReason,
  }) {
    final history = _peerHistories.putIfAbsent(
      peerId,
      () => PeerDeliveryHistory(peerNodeId: peerId),
    );

    final now = DateTime.now().toUtc();
    if (success) {
      history.recordSuccess(now);
      metrics.recordForwarded(hopCount, rssi: rssi);
      eventLog.log(
        eventType: 'FORWARD_SUCCESS',
        messageId: messageId,
        peerId: peerId,
        details: 'Relayed hop $hopCount (RSSI: $rssi dBm)',
      );
    } else {
      history.recordFailure(now, failureReason ?? 'Transmission failed');
      metrics.recordRetry();
      eventLog.log(
        eventType: 'FORWARD_FAILURE',
        messageId: messageId,
        peerId: peerId,
        details: failureReason ?? 'Transmission error',
      );
    }
  }

  /// Records confirmed delivery via application-level ACK.
  void recordAckReceived({
    required String peerId,
    required String messageId,
    int? relayDelayMs,
  }) {
    metrics.recordDelivered(delayMs: relayDelayMs);
    eventLog.log(
      eventType: 'ACK_RECEIVED',
      messageId: messageId,
      peerId: peerId,
      details: 'Delivery confirmed to peer ($peerId)',
    );
  }

  /// Enforces storage capacity limits using intelligent eviction.
  List<MeshMessage> enforceStorageQuotas(List<MeshMessage> outbox) {
    return storagePolicy.enforceCapacity(
      outbox,
      onEvict: (evicted) {
        metrics.recordDropped();
        eventLog.log(
          eventType: 'STORAGE_EVICTION',
          messageId: evicted.messageId,
          details: 'Evicted under capacity pressure (${evicted.priority.name})',
        );
      },
    );
  }
}
