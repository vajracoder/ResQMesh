import '../../identity/models/node_role.dart';
import '../../mesh/models/mesh_message.dart';
import '../../mesh/models/peer_node.dart';
import '../config/routing_config.dart';
import '../models/peer_delivery_history.dart';

/// Comprehensive evaluation result of a candidate peer's forwarding utility.
class PeerUtilityScore {
  final PeerNode peer;
  final double totalScore;
  final double rssiContribution;
  final double recencyContribution;
  final double historyContribution;
  final double roleContribution;
  final double destinationBonus;
  final double emergencyRoleBonus;
  final double duplicatePenalty;
  final bool isEligible;
  final String? disqualificationReason;

  const PeerUtilityScore({
    required this.peer,
    required this.totalScore,
    required this.rssiContribution,
    required this.recencyContribution,
    required this.historyContribution,
    required this.roleContribution,
    this.destinationBonus = 0.0,
    this.emergencyRoleBonus = 0.0,
    this.duplicatePenalty = 0.0,
    required this.isEligible,
    this.disqualificationReason,
  });

  String get summary => isEligible
      ? 'Score: ${totalScore.toStringAsFixed(1)} (RSSI: ${rssiContribution.toStringAsFixed(1)}, Recency: ${recencyContribution.toStringAsFixed(1)}, Hist: ${historyContribution.toStringAsFixed(1)}, Role: ${roleContribution.toStringAsFixed(1)}, DestBonus: ${destinationBonus.toStringAsFixed(1)}, EmerBonus: ${emergencyRoleBonus.toStringAsFixed(1)})'
      : 'Disqualified: $disqualificationReason';

  @override
  String toString() => 'PeerUtilityScore(${peer.nodeId}, eligible=$isEligible, score=${totalScore.toStringAsFixed(1)})';
}

/// Evaluates candidate peers for intelligent store-and-forward bundle dispatch.
///
/// Peer Utility Formula:
/// ```
/// PeerScore = (w_rssi * RSSI_norm) + (w_recency * Recency_norm)
///           + (w_history * History_norm) + (w_role * Role_norm)
///           + Destination_bonus - Duplicate_penalty
/// ```
/// Where:
/// - RSSI_norm: Normalized signal strength between min threshold (-95 dBm) and reference best (-40 dBm).
/// - Recency_norm: Time decay from lastSeen timestamp (1.0 for <10s, 0.0 at stale timeout).
/// - History_norm: Historical transmission ACK/success rate (0.0 to 1.0; 0.7 optimistic default).
/// - Role_norm: Command (1.0), Gateway (0.95), Responder (0.85), Civilian (0.50).
/// - Destination_bonus: +50 if peer is the bundle's final destination.
/// - Duplicate_penalty: Disqualifies candidate if peer already received/acknowledged bundle.
class PeerScoringModel {
  final RoutingConfig config;

  const PeerScoringModel({this.config = const RoutingConfig()});

  PeerUtilityScore scorePeer({
    required PeerNode peer,
    required MeshMessage message,
    required String localNodeId,
    PeerDeliveryHistory? history,
    bool peerAlreadyReceived = false,
    bool peerAlreadyAcked = false,
    DateTime? referenceTime,
  }) {
    final now = (referenceTime ?? DateTime.now().toUtc()).toUtc();

    // Disqualification Checks
    if (peer.nodeId == localNodeId) {
      return PeerUtilityScore(
        peer: peer,
        totalScore: 0.0,
        rssiContribution: 0.0,
        recencyContribution: 0.0,
        historyContribution: 0.0,
        roleContribution: 0.0,
        isEligible: false,
        disqualificationReason: 'Candidate is local node',
      );
    }

    if (peer.nodeId == message.originNodeId) {
      return PeerUtilityScore(
        peer: peer,
        totalScore: 0.0,
        rssiContribution: 0.0,
        recencyContribution: 0.0,
        historyContribution: 0.0,
        roleContribution: 0.0,
        isEligible: false,
        disqualificationReason: 'Candidate is bundle origin',
      );
    }

    if (peerAlreadyReceived || peerAlreadyAcked || message.hasVisitedNode(peer.nodeId)) {
      return PeerUtilityScore(
        peer: peer,
        totalScore: 0.0,
        rssiContribution: 0.0,
        recencyContribution: 0.0,
        historyContribution: 0.0,
        roleContribution: 0.0,
        duplicatePenalty: 1000.0,
        isEligible: false,
        disqualificationReason: 'Peer already received or acknowledged bundle',
      );
    }

    if (peer.hasProtocolMismatch()) {
      return PeerUtilityScore(
        peer: peer,
        totalScore: 0.0,
        rssiContribution: 0.0,
        recencyContribution: 0.0,
        historyContribution: 0.0,
        roleContribution: 0.0,
        isEligible: false,
        disqualificationReason: 'Protocol mismatch (${peer.protocolVersion})',
      );
    }

    if (peer.rssi < config.minRssiThreshold) {
      return PeerUtilityScore(
        peer: peer,
        totalScore: 0.0,
        rssiContribution: 0.0,
        recencyContribution: 0.0,
        historyContribution: 0.0,
        roleContribution: 0.0,
        isEligible: false,
        disqualificationReason: 'RSSI (${peer.rssi} dBm) below threshold (${config.minRssiThreshold} dBm)',
      );
    }

    // 1. RSSI Contribution (Normalized to 0.0 - 1.0)
    final double rawRssiSpan = (config.maxRssiReference - config.minRssiThreshold).toDouble();
    final double normalizedRssi = rawRssiSpan > 0
        ? ((peer.rssi - config.minRssiThreshold) / rawRssiSpan).clamp(0.0, 1.0)
        : 0.5;
    final double rssiScore = normalizedRssi * 100.0 * config.rssiWeight;

    // 2. Recency Contribution (Decaying over 120 seconds)
    final int secondsSinceSeen = now.difference(peer.lastSeen).inSeconds;
    final double normalizedRecency = (1.0 - (secondsSinceSeen / 120.0)).clamp(0.0, 1.0);
    final double recencyScore = normalizedRecency * 100.0 * config.recencyWeight;

    // 3. Delivery History Contribution (Historical success rate)
    final double normalizedHistory = history?.successRate ?? 0.7;
    final double historyScore = normalizedHistory * 100.0 * config.historyWeight;

    // 4. Role Contribution
    double normalizedRole;
    switch (peer.role) {
      case NodeRole.command:
        normalizedRole = 1.0;
        break;
      case NodeRole.gateway:
        normalizedRole = 0.95;
        break;
      case NodeRole.responder:
        normalizedRole = 0.85;
        break;
      case NodeRole.civilian:
        normalizedRole = peer.isGateway ? 0.95 : 0.50;
        break;
    }
    final double roleScore = normalizedRole * 100.0 * config.roleWeight;

    // 5. Destination Relevance Bonus
    double destinationBonus = 0.0;
    if (message.destinationNodeId == peer.nodeId) {
      destinationBonus = config.destinationMatchBonus;
    }

    // 6. Emergency Role Prioritization Bonus (Step 8)
    double emergencyRoleBonus = 0.0;
    if (message.isSos || message.priority == MessagePriority.critical || message.emergencyType.isHighUrgency) {
      if (peer.role == NodeRole.responder || peer.role == NodeRole.command) {
        emergencyRoleBonus = config.responderEmergencyBonus;
      } else if (peer.role == NodeRole.gateway || peer.isGateway) {
        emergencyRoleBonus = config.gatewayEmergencyBonus;
      }
    }

    final double total = rssiScore + recencyScore + historyScore + roleScore + destinationBonus + emergencyRoleBonus;

    return PeerUtilityScore(
      peer: peer,
      totalScore: total,
      rssiContribution: rssiScore,
      recencyContribution: recencyScore,
      historyContribution: historyScore,
      roleContribution: roleScore,
      destinationBonus: destinationBonus,
      emergencyRoleBonus: emergencyRoleBonus,
      isEligible: true,
    );
  }
}
