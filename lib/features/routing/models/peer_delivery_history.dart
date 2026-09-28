/// Tracks transmission reliability and delivery history for a specific peer.
class PeerDeliveryHistory {
  final String peerNodeId;
  int attemptsCount;
  int successCount;
  int failureCount;
  DateTime? lastSuccessTime;
  DateTime? lastFailureTime;
  String? lastFailureReason;

  PeerDeliveryHistory({
    required this.peerNodeId,
    this.attemptsCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.lastSuccessTime,
    this.lastFailureTime,
    this.lastFailureReason,
  });

  /// Success rate in [0.0, 1.0].
  /// Newly discovered peers default to 0.7 (optimistic prior to encourage discovery).
  double get successRate {
    if (attemptsCount == 0) return 0.7;
    return successCount / attemptsCount;
  }

  void recordSuccess(DateTime timestamp) {
    attemptsCount++;
    successCount++;
    lastSuccessTime = timestamp.toUtc();
  }

  void recordFailure(DateTime timestamp, String reason) {
    attemptsCount++;
    failureCount++;
    lastFailureTime = timestamp.toUtc();
    lastFailureReason = reason;
  }

  Map<String, dynamic> toMap() => {
        'peerNodeId': peerNodeId,
        'attemptsCount': attemptsCount,
        'successCount': successCount,
        'failureCount': failureCount,
        'lastSuccessTime': lastSuccessTime?.toIso8601String(),
        'lastFailureTime': lastFailureTime?.toIso8601String(),
        'lastFailureReason': lastFailureReason,
        'successRate': successRate,
      };

  factory PeerDeliveryHistory.fromMap(Map<String, dynamic> map) {
    return PeerDeliveryHistory(
      peerNodeId: map['peerNodeId'] as String? ?? '',
      attemptsCount: map['attemptsCount'] as int? ?? 0,
      successCount: map['successCount'] as int? ?? 0,
      failureCount: map['failureCount'] as int? ?? 0,
      lastSuccessTime: map['lastSuccessTime'] != null
          ? DateTime.tryParse(map['lastSuccessTime'] as String)
          : null,
      lastFailureTime: map['lastFailureTime'] != null
          ? DateTime.tryParse(map['lastFailureTime'] as String)
          : null,
      lastFailureReason: map['lastFailureReason'] as String?,
    );
  }
}
