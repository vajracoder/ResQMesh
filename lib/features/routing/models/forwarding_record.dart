/// Represents a single relay hop in the forwarding path of a DTN bundle.
///
/// Stored as an ordered list on the message; allows reconstructing the
/// physical relay path: A → B → C without requiring network connectivity.
class ForwardingRecord {
  /// Node ID of the peer that performed this relay step.
  final String relayNodeId;

  /// UTC timestamp at which this hop was forwarded.
  final DateTime forwardedAt;

  /// Hop index at the time of this forwarding event.
  final int hopNumber;

  /// RSSI (dBm) of the link used for this hop, or null if unavailable.
  final int? rssi;

  /// Whether the transmission at this hop was acknowledged by the recipient.
  final bool ackReceived;

  const ForwardingRecord({
    required this.relayNodeId,
    required this.forwardedAt,
    required this.hopNumber,
    this.rssi,
    this.ackReceived = false,
  });

  ForwardingRecord copyWith({
    String? relayNodeId,
    DateTime? forwardedAt,
    int? hopNumber,
    int? rssi,
    bool? ackReceived,
  }) {
    return ForwardingRecord(
      relayNodeId: relayNodeId ?? this.relayNodeId,
      forwardedAt: forwardedAt ?? this.forwardedAt,
      hopNumber: hopNumber ?? this.hopNumber,
      rssi: rssi ?? this.rssi,
      ackReceived: ackReceived ?? this.ackReceived,
    );
  }

  Map<String, dynamic> toMap() => {
        'relayNodeId': relayNodeId,
        'forwardedAt': forwardedAt.toIso8601String(),
        'hopNumber': hopNumber,
        'rssi': rssi,
        'ackReceived': ackReceived,
      };

  factory ForwardingRecord.fromMap(Map<String, dynamic> map) {
    return ForwardingRecord(
      relayNodeId: map['relayNodeId'] as String? ?? '',
      forwardedAt: DateTime.tryParse(map['forwardedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      hopNumber: map['hopNumber'] as int? ?? 0,
      rssi: map['rssi'] as int?,
      ackReceived: map['ackReceived'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'ForwardingRecord(node=$relayNodeId, hop=$hopNumber, ack=$ackReceived)';
}
