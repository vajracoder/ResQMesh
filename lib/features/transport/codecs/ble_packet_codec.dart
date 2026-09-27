import 'dart:convert';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../models/ble_packet.dart';

/// Low-level binary codec for BLE wire frames (Fragments and ACKs).
/// Ensures robust parsing without throwing unhandled exceptions on malformed input.
class BlePacketCodec {
  static const int magicByte1 = 0x52; // 'R'
  static const int magicByte2 = 0x4D; // 'M'
  static const int typeFragment = 0x01;
  static const int typeAck = 0x02;
  static const int currentVersionByte = 0x01;

  /// Serializes a [BleMessageFragment] into binary wire bytes.
  static Uint8List encodeFragment(BleMessageFragment fragment) {
    final msgIdBytes = utf8.encode(fragment.messageId);
    final builder = BytesBuilder();

    // Header
    builder.addByte(magicByte1);
    builder.addByte(magicByte2);
    builder.addByte(typeFragment);
    builder.addByte(currentVersionByte);

    // Message ID
    builder.addByte(msgIdBytes.length);
    builder.add(msgIdBytes);

    // Indices (Uint16 Big-Endian)
    final indexData = ByteData(6);
    indexData.setUint16(0, fragment.fragmentIndex, Endian.big);
    indexData.setUint16(2, fragment.totalFragments, Endian.big);
    indexData.setUint16(4, fragment.data.length, Endian.big);
    builder.add(indexData.buffer.asUint8List());

    // Payload data
    builder.add(fragment.data);

    return builder.toBytes();
  }

  /// Serializes a [BleAckPacket] into binary wire bytes.
  static Uint8List encodeAck(BleAckPacket ack) {
    final msgIdBytes = utf8.encode(ack.messageId);
    final ackNodeBytes = utf8.encode(ack.ackNodeId);
    final builder = BytesBuilder();

    // Header
    builder.addByte(magicByte1);
    builder.addByte(magicByte2);
    builder.addByte(typeAck);
    builder.addByte(currentVersionByte);

    // Message ID
    builder.addByte(msgIdBytes.length);
    builder.add(msgIdBytes);

    // ACK Node ID
    builder.addByte(ackNodeBytes.length);
    builder.add(ackNodeBytes);

    // Timestamp (Int64 Big-Endian)
    final timeData = ByteData(8);
    timeData.setInt64(0, ack.timestamp.millisecondsSinceEpoch, Endian.big);
    builder.add(timeData.buffer.asUint8List());

    return builder.toBytes();
  }

  /// Decodes raw wire bytes into either a [BleMessageFragment], a [BleAckPacket], or null.
  /// Strictly rejects malformed, incomplete, or unsupported packets.
  static dynamic decode(List<int> bytes) {
    if (bytes.length < 5) return null;

    // Check magic bytes
    if (bytes[0] != magicByte1 || bytes[1] != magicByte2) {
      return null;
    }

    final packetType = bytes[2];
    final version = bytes[3];

    if (version != currentVersionByte) {
      // Incompatible wire protocol version
      return null;
    }

    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));

      if (packetType == typeFragment) {
        int offset = 4;
        final msgIdLen = bytes[offset++];
        if (bytes.length < offset + msgIdLen + 6) return null;

        final msgId = utf8.decode(bytes.sublist(offset, offset + msgIdLen));
        offset += msgIdLen;

        final fragmentIndex = byteData.getUint16(offset, Endian.big);
        offset += 2;
        final totalFragments = byteData.getUint16(offset, Endian.big);
        offset += 2;
        final dataLen = byteData.getUint16(offset, Endian.big);
        offset += 2;

        if (bytes.length < offset + dataLen) return null;
        final data = Uint8List.fromList(bytes.sublist(offset, offset + dataLen));

        // Sanity checks on fragment indexes
        if (totalFragments <= 0 || fragmentIndex >= totalFragments) {
          return null;
        }

        return BleMessageFragment(
          protocolVersion: AppConstants.protocolVersion,
          messageId: msgId,
          fragmentIndex: fragmentIndex,
          totalFragments: totalFragments,
          data: data,
        );
      } else if (packetType == typeAck) {
        int offset = 4;
        final msgIdLen = bytes[offset++];
        if (bytes.length < offset + msgIdLen + 1) return null;

        final msgId = utf8.decode(bytes.sublist(offset, offset + msgIdLen));
        offset += msgIdLen;

        final ackNodeLen = bytes[offset++];
        if (bytes.length < offset + ackNodeLen + 8) return null;

        final ackNodeId = utf8.decode(bytes.sublist(offset, offset + ackNodeLen));
        offset += ackNodeLen;

        final timeMs = byteData.getInt64(offset, Endian.big);
        final timestamp = DateTime.fromMillisecondsSinceEpoch(timeMs, isUtc: true);

        return BleAckPacket(
          protocolVersion: AppConstants.protocolVersion,
          messageId: msgId,
          ackNodeId: ackNodeId,
          timestamp: timestamp,
        );
      }
    } catch (_) {
      // Safe fallback on unexpected parsing failures
      return null;
    }

    return null;
  }
}
