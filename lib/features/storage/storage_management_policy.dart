import '../mesh/models/mesh_message.dart';

/// Storage eviction and quota policy for offline DTN bundle persistence.
///
/// Ensures critical emergency alerts (SOS/Critical) are protected during
/// storage congestion, while expired, delivered, or low-priority telemetry
/// bundles are systematically evicted.
class StorageManagementPolicy {
  final int capacityLimit;

  const StorageManagementPolicy({this.capacityLimit = 500});

  /// Evaluates the message list and evicts items to stay within [capacityLimit].
  List<MeshMessage> enforceCapacity(
    List<MeshMessage> messages, {
    DateTime? referenceTime,
    void Function(MeshMessage evicted)? onEvict,
  }) {
    final now = (referenceTime ?? DateTime.now().toUtc()).toUtc();
    final working = List<MeshMessage>.from(messages);

    // 1. Evict expired messages first
    working.removeWhere((m) {
      if (m.isExpired(referenceTime: now)) {
        onEvict?.call(m);
        return true;
      }
      return false;
    });

    if (working.length <= capacityLimit) {
      return working;
    }

    // 2. Sort by eviction vulnerability (highest eviction score first)
    working.sort((a, b) {
      final scoreA = _calculateEvictionScore(a);
      final scoreB = _calculateEvictionScore(b);
      return scoreB.compareTo(scoreA);
    });

    // 3. Remove items from the front of the eviction-sorted list
    while (working.length > capacityLimit) {
      final candidate = working.first;
      // Protect unexpired SOS bundles if any non-SOS bundles exist
      if (candidate.isSos && working.any((m) => !m.isSos)) {
        final nonSosIndex = working.indexWhere((m) => !m.isSos);
        if (nonSosIndex != -1) {
          final evicted = working.removeAt(nonSosIndex);
          onEvict?.call(evicted);
          continue;
        }
      }
      final evicted = working.removeAt(0);
      onEvict?.call(evicted);
    }

    return working;
  }

  /// Calculates how readily a message should be evicted under storage pressure.
  /// Higher score = evict sooner.
  int _calculateEvictionScore(MeshMessage message) {
    int score = 0;

    // Already delivered or failed messages are top candidates for removal
    if (message.status == MessageStatus.delivered ||
        message.status == MessageStatus.deliveredToPeer) {
      score += 1000;
    }
    if (message.status == MessageStatus.failed) {
      score += 2000;
    }

    // Priority contribution to eviction vulnerability
    switch (message.priority) {
      case MessagePriority.low:
        score += 500;
        break;
      case MessagePriority.normal:
        score += 300;
        break;
      case MessagePriority.high:
        score += 50;
        break;
      case MessagePriority.critical:
        score -= 2000;
        break;
    }

    // Strongly protect SOS
    if (message.isSos) {
      score -= 10000;
    }

    // Higher hops indicate bundle has circulated widely; favor local fresh bundles
    score += message.hopCount * 15;

    return score;
  }
}
