import 'dart:math';
import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../models/ble_packet.dart';

/// Divides serialized [MeshMessage] payloads into BLE-sized fragment packets.
class BleMessageFragmenter {
  /// Splits a complete [payload] into a sequence of [BleMessageFragment] objects.
  static List<BleMessageFragment> fragment(
    Uint8List payload, {
    required String messageId,
    int chunkSize = AppConstants.bleMaxFragmentPayloadSize,
    String protocolVersion = AppConstants.protocolVersion,
  }) {
    if (payload.isEmpty) {
      return [
        BleMessageFragment(
          protocolVersion: protocolVersion,
          messageId: messageId,
          fragmentIndex: 0,
          totalFragments: 1,
          data: Uint8List(0),
        ),
      ];
    }

    final safeChunkSize = max(16, chunkSize);
    final totalFragments = (payload.length / safeChunkSize).ceil();
    final fragments = <BleMessageFragment>[];

    for (int i = 0; i < totalFragments; i++) {
      final start = i * safeChunkSize;
      final end = min(start + safeChunkSize, payload.length);
      final chunkData = Uint8List.sublistView(payload, start, end);

      fragments.add(
        BleMessageFragment(
          protocolVersion: protocolVersion,
          messageId: messageId,
          fragmentIndex: i,
          totalFragments: totalFragments,
          data: chunkData,
        ),
      );
    }

    return fragments;
  }
}
