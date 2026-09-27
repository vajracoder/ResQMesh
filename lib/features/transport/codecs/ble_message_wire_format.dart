import 'dart:convert';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../../discovery/ble_advertisement_codec.dart';
import '../../identity/models/node_role.dart';
import '../../mesh/models/mesh_message.dart';

/// Exceptions thrown during wire message validation.
class MessageValidationException implements Exception {
  final String message;
  const MessageValidationException(this.message);

  @override
  String toString() => 'MessageValidationException: $message';
}

/// Serializes and deserializes [MeshMessage] objects to/from a compact wire payload
/// for transmission across Bluetooth Low Energy GATT links.
class BleMessageWireFormat {
  /// Encodes a [MeshMessage] into a compact UTF-8 JSON wire payload.
  static Uint8List encode(MeshMessage message) {
    final map = <String, dynamic>{
      'v': AppConstants.protocolVersion,
      'mid': message.messageId,
      'orig': message.originNodeId,
      'snd': message.senderNodeId,
      'dst': message.destinationNodeId,
      'type': message.messageType.name,
      'prio': message.priority.name,
      'pay': message.payload,
      'ts': message.createdAt.millisecondsSinceEpoch,
      'exp': message.expiresAt.millisecondsSinceEpoch,
      'ttl': message.ttl,
      'hop': message.hopCount,
      'max': message.maxHops,
      'role': message.createdByRole.name,
    };

    final jsonStr = jsonEncode(map);
    return Uint8List.fromList(utf8.encode(jsonStr));
  }

  /// Decodes and validates a raw wire payload back into a [MeshMessage].
  /// Returns `null` if the data is corrupt, invalid JSON, or fails validation.
  static MeshMessage? decode(Uint8List bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final dynamic parsed = jsonDecode(jsonStr);
      if (parsed is! Map<String, dynamic>) {
        return null;
      }

      final map = parsed;

      // Protocol version validation
      final version = map['v'] as String? ?? '';
      if (!isSupportedVersion(version)) {
        return null;
      }

      final messageId = map['mid'] as String? ?? '';
      final origin = map['orig'] as String? ?? '';
      final sender = map['snd'] as String? ?? '';
      final destination = map['dst'] as String? ?? '*';
      final payload = map['pay'] as String? ?? '';
      final createdAtMs = map['ts'] as int?;
      final expiresAtMs = map['exp'] as int?;
      final ttl = map['ttl'] as int? ?? 86400;
      final hopCount = map['hop'] as int? ?? 0;
      final maxHops = map['max'] as int? ?? 5;
      final roleStr = map['role'] as String? ?? NodeRole.civilian.name;

      if (messageId.isEmpty || origin.isEmpty || payload.isEmpty) {
        return null;
      }

      // Origin and sender node ID sanity check
      if (!BleAdvertisementCodec.isValidNodeId(origin)) {
        return null;
      }

      if (createdAtMs == null || ttl <= 0) {
        return null;
      }

      if (hopCount < 0 || hopCount > maxHops) {
        return null;
      }

      final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true);
      final expiresAt = expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true)
          : createdAt.add(Duration(seconds: ttl));

      final type = MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.info,
      );

      final priority = MessagePriority.values.firstWhere(
        (p) => p.name == map['prio'],
        orElse: () => MessagePriority.normal,
      );

      final role = NodeRole.values.firstWhere(
        (r) => r.name == roleStr,
        orElse: () => NodeRole.civilian,
      );

      return MeshMessage(
        messageId: messageId,
        originNodeId: origin,
        senderNodeId: sender.isNotEmpty ? sender : origin,
        destinationNodeId: destination,
        messageType: type,
        priority: priority,
        payload: payload,
        createdAt: createdAt,
        expiresAt: expiresAt,
        ttl: ttl,
        hopCount: hopCount,
        maxHops: maxHops,
        status: MessageStatus.received,
        createdByRole: role,
      );
    } catch (_) {
      // Never crash on malformed data
      return null;
    }
  }

  /// Validates whether the protocol version is compatible.
  static bool isSupportedVersion(String version) {
    if (version.isEmpty) return false;
    final major = version.split('.').first;
    final expectedMajor = AppConstants.protocolVersion.split('.').first;
    return major == expectedMajor;
  }

  /// Strictly validates a message before admission to the DTN storage.
  static void validate(MeshMessage message) {
    if (message.messageId.isEmpty) {
      throw const MessageValidationException('Message ID cannot be empty');
    }
    if (!BleAdvertisementCodec.isValidNodeId(message.originNodeId)) {
      throw MessageValidationException('Invalid origin node ID: ${message.originNodeId}');
    }
    if (message.payload.trim().isEmpty) {
      throw const MessageValidationException('Payload cannot be empty');
    }
    if (message.ttl <= 0) {
      throw MessageValidationException('TTL must be positive: ${message.ttl}');
    }
    if (message.hopCount > message.maxHops) {
      throw MessageValidationException(
        'Hop count (${message.hopCount}) exceeds max hops (${message.maxHops})',
      );
    }
  }
}
