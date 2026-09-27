import 'dart:async';
import 'package:flutter/foundation.dart';
import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import 'models/ble_packet.dart';

/// Runtime statistics tracked by the BLE message transport layer.
class BleTransportStats {
  final int messagesSent;
  final int messagesReceived;
  final int messagesFailed;
  final int bytesSent;
  final int bytesReceived;
  final String lastBleEvent;
  final DateTime? lastEventTimestamp;

  const BleTransportStats({
    this.messagesSent = 0,
    this.messagesReceived = 0,
    this.messagesFailed = 0,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.lastBleEvent = 'None',
    this.lastEventTimestamp,
  });

  BleTransportStats copyWith({
    int? messagesSent,
    int? messagesReceived,
    int? messagesFailed,
    int? bytesSent,
    int? bytesReceived,
    String? lastBleEvent,
    DateTime? lastEventTimestamp,
  }) {
    return BleTransportStats(
      messagesSent: messagesSent ?? this.messagesSent,
      messagesReceived: messagesReceived ?? this.messagesReceived,
      messagesFailed: messagesFailed ?? this.messagesFailed,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      lastBleEvent: lastBleEvent ?? this.lastBleEvent,
      lastEventTimestamp: lastEventTimestamp ?? this.lastEventTimestamp,
    );
  }
}

/// Abstract contract for the ResQMesh BLE Message Transport layer.
/// Responsible for establishing GATT connections, fragmenting/reassembling packets,
/// exchanging wire messages, and delivering application-level ACKs between physical devices.
abstract class BleTransport extends ChangeNotifier {
  /// Initializes the GATT server and hardware listeners.
  Future<void> initialize();

  /// Connects to a discovered [PeerNode] over BLE GATT.
  Future<bool> connect(PeerNode peer);

  /// Disconnects gracefully from the given peer node.
  Future<void> disconnect(String nodeId);

  /// Fragments and transmits a [MeshMessage] over BLE to a reachable [PeerNode].
  /// Returns `true` if all fragments were written and an ACK was received, `false` otherwise.
  Future<bool> sendMeshMessage(MeshMessage message, PeerNode peer);

  /// Stream emitting completely reassembled, validated incoming messages.
  Stream<MeshMessage> get onMessageReceived;

  /// Stream emitting incoming application-level acknowledgements.
  Stream<BleAckPacket> get onAckReceived;

  /// Stream emitting peer connection state transitions.
  Stream<PeerNode> get onPeerConnectionChanged;

  /// Returns the current connection state of a specific peer node.
  PeerConnectionState getConnectionState(String nodeId);

  /// List of currently connected peer nodes.
  List<PeerNode> get connectedPeers;

  /// Count of currently connected peers.
  int get connectedPeerCount;

  /// Real-time BLE transport statistics.
  BleTransportStats get stats;
}
