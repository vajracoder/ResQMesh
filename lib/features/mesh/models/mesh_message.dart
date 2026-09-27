enum MessagePriority {
  critical, // Emergency SOS alert
  high,     // Urgent medical/hazard alert
  normal,   // General coordination
  low,      // Status beacon / telemetry
}

enum MessageStatus {
  draft,
  queued,
  forwarded,
  delivered,
  expired,
}

/// Represents a discrete packet or message within the ResQMesh DTN network.
class MeshMessage {
  final String id;
  final String senderId;
  final String recipientId; // '*' represents broadcast to all nodes
  final String content;
  final DateTime timestamp;
  final MessagePriority priority;
  final MessageStatus status;
  final int hopCount;
  final int maxHops;

  const MeshMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    this.priority = MessagePriority.normal,
    this.status = MessageStatus.queued,
    this.hopCount = 0,
    this.maxHops = 5,
  });

  bool get isBroadcast => recipientId == '*' || recipientId.isEmpty;
  bool get isSos => priority == MessagePriority.critical;

  MeshMessage copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    MessagePriority? priority,
    MessageStatus? status,
    int? hopCount,
    int? maxHops,
  }) {
    return MeshMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      hopCount: hopCount ?? this.hopCount,
      maxHops: maxHops ?? this.maxHops,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'hopCount': hopCount,
      'maxHops': maxHops,
    };
  }

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    return MeshMessage(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      recipientId: map['recipientId'] as String,
      content: map['content'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      priority: MessagePriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => MessagePriority.normal,
      ),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageStatus.queued,
      ),
      hopCount: map['hopCount'] as int? ?? 0,
      maxHops: map['maxHops'] as int? ?? 5,
    );
  }
}
