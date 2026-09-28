import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../../mesh/models/emergency_type.dart';

/// Discriminator for BLE wire packets.
enum BlePacketType {
  fragment,
  ack,
}

/// Represents a single discrete BLE transmission fragment of a serialized [MeshMessage].
class BleMessageFragment {
  final String protocolVersion;
  final String messageId;
  final int fragmentIndex; // 0-based
  final int totalFragments;
  final Uint8List data;

  const BleMessageFragment({
    this.protocolVersion = AppConstants.protocolVersion,
    required this.messageId,
    required this.fragmentIndex,
    required this.totalFragments,
    required this.data,
  });

  bool get isFirst => fragmentIndex == 0;
  bool get isLast => fragmentIndex == totalFragments - 1;

  @override
  String toString() =>
      'BleMessageFragment(msgId: $messageId, fragment: ${fragmentIndex + 1}/$totalFragments, bytes: ${data.length})';
}

/// Application-level acknowledgement packet sent back when a neighboring node
/// has successfully reconstructed and stored a complete [MeshMessage] bundle.
class BleAckPacket {
  final String protocolVersion;
  final String messageId;
  final String ackNodeId;
  final DateTime timestamp;
  final AckType ackType;

  BleAckPacket({
    this.protocolVersion = AppConstants.protocolVersion,
    required this.messageId,
    required this.ackNodeId,
    DateTime? timestamp,
    this.ackType = AckType.peerAck,
  }) : timestamp = (timestamp ?? DateTime.now().toUtc()).toUtc();

  @override
  String toString() =>
      'BleAckPacket(msgId: $messageId, from: $ackNodeId, type: ${ackType.displayName}, at: $timestamp)';
}
