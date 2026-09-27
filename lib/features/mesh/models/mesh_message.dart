import '../../identity/models/node_role.dart';

/// Categories of emergency mesh messages supported by ResQMesh.
enum MessageType {
  sos,
  hazard,
  info,
  status,
}

/// Transmission priority for DTN bundle dispatch and queue admission.
enum MessagePriority {
  critical, // Emergency SOS alert
  high,     // Urgent medical/hazard alert
  normal,   // General coordination
  low,      // Status beacon / telemetry
}

/// Lifecycle status for persistent DTN bundles.
enum MessageStatus {
  draft,
  queued,
  stored,
  sending,
  sentToPeer,
  deliveredToPeer,
  forwarding,
  forwarded,
  delivered,
  received,
  expired,
  failed,
}

/// Represents a discrete persistent DTN bundle or emergency message
/// designed for store-and-forward relay across ResQMesh offline nodes.
class MeshMessage {
  final String messageId;
  final String originNodeId;
  final String senderNodeId;
  final String destinationNodeId;
  final MessageType messageType;
  final MessagePriority priority;
  final String payload;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int ttl; // in seconds
  final int hopCount;
  final int maxHops;
  final MessageStatus status;
  final int retryCount;
  final DateTime? lastForwardedAt;
  final NodeRole createdByRole;

  MeshMessage({
    String? messageId,
    String? originNodeId,
    String? senderNodeId,
    String? destinationNodeId,
    MessageType? messageType,
    MessagePriority? priority,
    String? payload,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? ttl,
    this.hopCount = 0,
    this.maxHops = 5,
    this.status = MessageStatus.stored,
    this.retryCount = 0,
    this.lastForwardedAt,
    this.createdByRole = NodeRole.civilian,
    // Step 1 backwards-compatibility alias parameters:
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? timestamp,
  })  : messageId = messageId ?? id ?? '',
        originNodeId = originNodeId ?? senderNodeId ?? senderId ?? '',
        senderNodeId = senderNodeId ?? senderId ?? originNodeId ?? '',
        destinationNodeId = destinationNodeId ?? recipientId ?? '*',
        payload = payload ?? content ?? '',
        createdAt = (createdAt ?? timestamp ?? DateTime.now().toUtc()).toUtc(),
        ttl = ttl ?? 86400, // 24 hours default TTL
        expiresAt = (expiresAt ?? (createdAt ?? timestamp ?? DateTime.now().toUtc()).add(Duration(seconds: ttl ?? 86400))).toUtc(),
        priority = priority ?? MessagePriority.normal,
        messageType = messageType ?? ((priority == MessagePriority.critical) ? MessageType.sos : MessageType.info);

  // Backward compatibility getters for Step 1 UI & tests
  String get id => messageId;
  String get senderId => senderNodeId;
  String get recipientId => destinationNodeId;
  String get content => payload;
  DateTime get timestamp => createdAt;

  bool get isBroadcast => destinationNodeId == '*' || destinationNodeId.isEmpty;
  bool get isSos => messageType == MessageType.sos || priority == MessagePriority.critical;

  /// Evaluates whether the bundle has exceeded its time-to-live.
  bool isExpired({DateTime? referenceTime}) {
    final now = (referenceTime ?? DateTime.now().toUtc()).toUtc();
    return now.isAfter(expiresAt);
  }

  MeshMessage copyWith({
    String? messageId,
    String? originNodeId,
    String? senderNodeId,
    String? destinationNodeId,
    MessageType? messageType,
    MessagePriority? priority,
    String? payload,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? ttl,
    int? hopCount,
    int? maxHops,
    MessageStatus? status,
    int? retryCount,
    DateTime? lastForwardedAt,
    NodeRole? createdByRole,
    // Legacy parameter aliases
    String? id,
    String? senderId,
    String? recipientId,
    String? content,
    DateTime? timestamp,
  }) {
    return MeshMessage(
      messageId: messageId ?? id ?? this.messageId,
      originNodeId: originNodeId ?? this.originNodeId,
      senderNodeId: senderNodeId ?? senderId ?? this.senderNodeId,
      destinationNodeId: destinationNodeId ?? recipientId ?? this.destinationNodeId,
      messageType: messageType ?? this.messageType,
      priority: priority ?? this.priority,
      payload: payload ?? content ?? this.payload,
      createdAt: createdAt ?? timestamp ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      ttl: ttl ?? this.ttl,
      hopCount: hopCount ?? this.hopCount,
      maxHops: maxHops ?? this.maxHops,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastForwardedAt: lastForwardedAt ?? this.lastForwardedAt,
      createdByRole: createdByRole ?? this.createdByRole,
    );
  }

  /// Converts the bundle to a flat map suitable for SQLite persistence.
  Map<String, dynamic> toDatabaseMap() {
    return {
      'message_id': messageId,
      'origin_node_id': originNodeId,
      'sender_node_id': senderNodeId,
      'destination_node_id': destinationNodeId,
      'message_type': messageType.name,
      'priority': priority.name,
      'payload': payload,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'ttl': ttl,
      'hop_count': hopCount,
      'max_hops': maxHops,
      'status': status.name,
      'retry_count': retryCount,
      'last_forwarded_at': lastForwardedAt?.millisecondsSinceEpoch,
      'created_by_role': createdByRole.name,
    };
  }

  /// Reconstructs a [MeshMessage] from a SQLite row map.
  factory MeshMessage.fromDatabaseMap(Map<String, dynamic> map) {
    return MeshMessage(
      messageId: map['message_id'] as String,
      originNodeId: map['origin_node_id'] as String,
      senderNodeId: map['sender_node_id'] as String,
      destinationNodeId: map['destination_node_id'] as String,
      messageType: MessageType.values.firstWhere(
        (t) => t.name == map['message_type'],
        orElse: () => MessageType.info,
      ),
      priority: MessagePriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => MessagePriority.normal,
      ),
      payload: map['payload'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int, isUtc: true),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int, isUtc: true),
      ttl: map['ttl'] as int,
      hopCount: map['hop_count'] as int? ?? 0,
      maxHops: map['max_hops'] as int? ?? 5,
      status: MessageStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => MessageStatus.stored,
      ),
      retryCount: map['retry_count'] as int? ?? 0,
      lastForwardedAt: map['last_forwarded_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_forwarded_at'] as int, isUtc: true)
          : null,
      createdByRole: NodeRole.values.firstWhere(
        (r) => r.name == map['created_by_role'],
        orElse: () => NodeRole.civilian,
      ),
    );
  }

  /// JSON / Map representation for serialization and testing.
  Map<String, dynamic> toMap() {
    return {
      'id': messageId,
      'messageId': messageId,
      'originNodeId': originNodeId,
      'senderId': senderNodeId,
      'senderNodeId': senderNodeId,
      'recipientId': destinationNodeId,
      'destinationNodeId': destinationNodeId,
      'messageType': messageType.name,
      'priority': priority.name,
      'content': payload,
      'payload': payload,
      'timestamp': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'ttl': ttl,
      'hopCount': hopCount,
      'maxHops': maxHops,
      'status': status.name,
      'retryCount': retryCount,
      'lastForwardedAt': lastForwardedAt?.toIso8601String(),
      'createdByRole': createdByRole.name,
    };
  }

  factory MeshMessage.fromMap(Map<String, dynamic> map) {
    final rawMessageId = (map['messageId'] ?? map['id']) as String;
    final rawOriginNodeId = (map['originNodeId'] ?? map['senderNodeId'] ?? map['senderId']) as String;
    final rawSenderNodeId = (map['senderNodeId'] ?? map['senderId'] ?? rawOriginNodeId) as String;
    final rawDestNodeId = (map['destinationNodeId'] ?? map['recipientId'] ?? '*') as String;
    final rawPayload = (map['payload'] ?? map['content'] ?? '') as String;
    final rawCreatedAt = DateTime.parse((map['createdAt'] ?? map['timestamp']) as String);
    final rawTtl = map['ttl'] as int? ?? 86400;
    final rawExpiresAt = map['expiresAt'] != null
        ? DateTime.parse(map['expiresAt'] as String)
        : rawCreatedAt.add(Duration(seconds: rawTtl));

    return MeshMessage(
      messageId: rawMessageId,
      originNodeId: rawOriginNodeId,
      senderNodeId: rawSenderNodeId,
      destinationNodeId: rawDestNodeId,
      payload: rawPayload,
      createdAt: rawCreatedAt,
      expiresAt: rawExpiresAt,
      ttl: rawTtl,
      messageType: MessageType.values.firstWhere(
        (t) => t.name == map['messageType'],
        orElse: () => MessageType.info,
      ),
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
      retryCount: map['retryCount'] as int? ?? 0,
      lastForwardedAt: map['lastForwardedAt'] != null
          ? DateTime.parse(map['lastForwardedAt'] as String)
          : null,
      createdByRole: NodeRole.values.firstWhere(
        (r) => r.name == map['createdByRole'],
        orElse: () => NodeRole.civilian,
      ),
    );
  }
}
