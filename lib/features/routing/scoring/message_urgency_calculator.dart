import '../../mesh/models/mesh_message.dart';
import '../config/routing_config.dart';

/// Breakdown of how a message bundle's forwarding urgency score was calculated.
class MessageUrgencyScore {
  final int totalScore;
  final int basePriorityWeight;
  final int ttlBoost;
  final int hopPenalty;
  final bool isExpired;
  final String priorityLabel;

  const MessageUrgencyScore({
    required this.totalScore,
    required this.basePriorityWeight,
    required this.ttlBoost,
    required this.hopPenalty,
    required this.isExpired,
    required this.priorityLabel,
  });

  String get summary => isExpired
      ? 'EXPIRED ($priorityLabel)'
      : 'Urgency: $totalScore [Base: $basePriorityWeight ($priorityLabel), TTL Boost: +$ttlBoost, Hop Penalty: -$hopPenalty]';

  @override
  String toString() => 'MessageUrgencyScore(total=$totalScore, $summary)';
}

/// Computes multi-factor urgency scores to determine transmission dispatch order.
///
/// Urgency Formula:
/// ```
/// UrgencyScore = BasePriorityWeight + TTLUrgencyBoost - HopPenalty
/// ```
/// Rationale:
/// - BasePriorityWeight: Guarantees life-safety emergency SOS and Critical alerts dominate
///   channel access (SOS: 1000, CRITICAL: 800, HIGH: 500, NORMAL: 200, INFO: 100).
/// - TTLUrgencyBoost: As a bundle nears its expiration deadline, its delivery urgency escalates
///   dynamically (up to +300 points) to save valuable situational data from timing out.
/// - HopPenalty: Bundles that have traversed many hops are slightly deprioritized relative to
///   fresh neighboring emergency alerts to damp routing oscillations.
class MessageUrgencyCalculator {
  final RoutingConfig config;

  const MessageUrgencyCalculator({this.config = const RoutingConfig()});

  MessageUrgencyScore calculateUrgency(
    MeshMessage message, {
    DateTime? referenceTime,
  }) {
    final now = (referenceTime ?? DateTime.now().toUtc()).toUtc();

    if (message.isExpired(referenceTime: now)) {
      return const MessageUrgencyScore(
        totalScore: 0,
        basePriorityWeight: 0,
        ttlBoost: 0,
        hopPenalty: 0,
        isExpired: true,
        priorityLabel: 'EXPIRED',
      );
    }

    // 1. Base Priority Weight
    int baseWeight;
    String priorityLabel;

    if (message.isSos) {
      baseWeight = config.sosWeight;
      priorityLabel = 'SOS';
    } else {
      switch (message.priority) {
        case MessagePriority.critical:
          baseWeight = config.criticalWeight;
          priorityLabel = 'CRITICAL';
          break;
        case MessagePriority.high:
          baseWeight = config.highWeight;
          priorityLabel = 'HIGH';
          break;
        case MessagePriority.normal:
          baseWeight = config.normalWeight;
          priorityLabel = 'NORMAL';
          break;
        case MessagePriority.low:
          baseWeight = config.infoWeight;
          priorityLabel = 'INFO';
          break;
      }
    }

    // 2. Dynamic TTL Urgency Boost
    int ttlBoost = 0;
    final int remainingSeconds = message.expiresAt.difference(now).inSeconds;
    final int totalTtl = message.ttl > 0 ? message.ttl : 86400;

    if (remainingSeconds > 0 && totalTtl > 0) {
      final double remainingRatio = (remainingSeconds / totalTtl).clamp(0.0, 1.0);
      if (remainingRatio < config.ttlUrgencyThresholdRatio) {
        // Linear escalation as TTL approaches 0
        final double urgencyFraction = 1.0 - (remainingRatio / config.ttlUrgencyThresholdRatio);
        ttlBoost = (urgencyFraction * config.ttlMaxBoost).round();
      }
    }

    // 3. Hop Penalty
    final int hopPenalty = message.hopCount * config.hopPenalty;

    // Total composite urgency (bounded between 1 and 3000)
    final int totalScore = (baseWeight + ttlBoost - hopPenalty).clamp(1, 3000);

    return MessageUrgencyScore(
      totalScore: totalScore,
      basePriorityWeight: baseWeight,
      ttlBoost: ttlBoost,
      hopPenalty: hopPenalty,
      isExpired: false,
      priorityLabel: priorityLabel,
    );
  }
}
