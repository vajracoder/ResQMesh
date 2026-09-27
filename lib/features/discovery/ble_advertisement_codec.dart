import 'dart:convert';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';

/// Decoded advertisement payload from a nearby ResQMesh BLE broadcaster.
class BleAdvertisementPayload {
  final String nodeId;
  final String protocolVersion;
  final String displayName;

  const BleAdvertisementPayload({
    required this.nodeId,
    required this.protocolVersion,
    this.displayName = '',
  });

  @override
  String toString() => 'BleAdvertisementPayload(nodeId: $nodeId, version: $protocolVersion, name: $displayName)';
}

/// Binary encoder and decoder for ResQMesh BLE discovery advertisements.
///
/// Packet Format (Fits within 31-byte BLE legacy advertisement limits):
/// - Offset 0-1  : Magic Header [0x52, 0x51] (ASCII 'R', 'Q')
/// - Offset 2-3  : Protocol Version [Major, Minor] (e.g. 0x01, 0x00 for "1.0")
/// - Offset 4-19 : Node UUID raw bytes (16 bytes)
/// - Offset 20   : Name length N (1 byte, max 8 bytes)
/// - Offset 21.. : Optional truncated UTF-8 display name (N bytes)
class BleAdvertisementCodec {
  static const int magicByte1 = 0x52; // 'R'
  static const int magicByte2 = 0x51; // 'Q'
  static const int minPacketSize = 20;

  /// Validates whether a given string is a correctly formatted ResQMesh Node ID.
  /// Formatted as: RQM-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (UUIDv4)
  static bool isValidNodeId(String nodeId) {
    if (!nodeId.startsWith('RQM-')) return false;
    final uuidPart = nodeId.substring(4);
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegex.hasMatch(uuidPart);
  }

  /// Encodes node identity into a compact binary advertisement payload.
  static Uint8List encode({
    required String nodeId,
    String protocolVersion = AppConstants.protocolVersion,
    String displayName = '',
  }) {
    // Extract raw 16 UUID bytes from nodeId ('RQM-<36-char-uuid>')
    final rawHex = nodeId.startsWith('RQM-')
        ? nodeId.substring(4).replaceAll('-', '')
        : nodeId.replaceAll('-', '');

    final uuidBytes = Uint8List(16);
    if (rawHex.length == 32) {
      for (int i = 0; i < 16; i++) {
        final byteHex = rawHex.substring(i * 2, i * 2 + 2);
        uuidBytes[i] = int.parse(byteHex, radix: 16);
      }
    }

    // Parse major.minor version
    int major = 1;
    int minor = 0;
    final parts = protocolVersion.split('.');
    if (parts.isNotEmpty) major = int.tryParse(parts[0]) ?? 1;
    if (parts.length > 1) minor = int.tryParse(parts[1]) ?? 0;

    // Truncate display name to max 24 UTF-8 bytes to fit comfortably within BLE limits
    final nameBytes = utf8.encode(displayName);
    final trimmedNameBytes = nameBytes.length > 24 ? nameBytes.sublist(0, 24) : nameBytes;

    final result = BytesBuilder();
    result.addByte(magicByte1);
    result.addByte(magicByte2);
    result.addByte(major);
    result.addByte(minor);
    result.add(uuidBytes);
    result.addByte(trimmedNameBytes.length);
    if (trimmedNameBytes.isNotEmpty) {
      result.add(trimmedNameBytes);
    }

    return result.toBytes();
  }

  /// Decodes raw manufacturer data or service data into a [BleAdvertisementPayload].
  /// Returns null if the payload is not a valid ResQMesh advertisement packet.
  static BleAdvertisementPayload? decode(List<int> data) {
    if (data.length < minPacketSize) {
      // Fallback: check if encoded as UTF-8 string (e.g. "RQM:1.0:RQM-xxxx:Name")
      return _tryDecodeStringFallback(data);
    }

    // Check magic bytes
    if (data[0] != magicByte1 || data[1] != magicByte2) {
      return _tryDecodeStringFallback(data);
    }

    final major = data[2];
    final minor = data[3];
    final version = '$major.$minor';

    // Extract 16-byte UUID
    final buffer = StringBuffer();
    for (int i = 4; i < 20; i++) {
      buffer.write(data[i].toRadixString(16).padLeft(2, '0'));
    }
    final rawHex = buffer.toString();
    final formattedUuid =
        '${rawHex.substring(0, 8)}-${rawHex.substring(8, 12)}-${rawHex.substring(12, 16)}-${rawHex.substring(16, 20)}-${rawHex.substring(20, 32)}';
    final nodeId = 'RQM-$formattedUuid';

    String displayName = '';
    if (data.length > 20) {
      final nameLen = data[20];
      if (nameLen > 0 && data.length >= 21 + nameLen) {
        try {
          displayName = utf8.decode(data.sublist(21, 21 + nameLen));
        } catch (_) {}
      }
    }

    return BleAdvertisementPayload(
      nodeId: nodeId,
      protocolVersion: version,
      displayName: displayName,
    );
  }

  static BleAdvertisementPayload? _tryDecodeStringFallback(List<int> data) {
    try {
      final str = utf8.decode(data);
      if (str.startsWith('RQM:')) {
        final segments = str.split(':');
        if (segments.length >= 3) {
          final version = segments[1];
          final nodeId = segments[2];
          final name = segments.length > 3 ? segments[3] : '';
          if (isValidNodeId(nodeId)) {
            return BleAdvertisementPayload(
              nodeId: nodeId,
              protocolVersion: version,
              displayName: name,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
