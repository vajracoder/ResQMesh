import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../identity/services/node_identity_service.dart';
import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import 'ble_transport.dart';
import 'codecs/ble_message_fragmenter.dart';
import 'codecs/ble_message_reassembler.dart';
import 'codecs/ble_message_wire_format.dart';
import 'codecs/ble_packet_codec.dart';
import 'models/ble_packet.dart';

class _ActivePeerSession {
  final PeerNode peer;
  final BluetoothDevice device;
  BluetoothCharacteristic? rxCharacteristic;
  BluetoothCharacteristic? txCharacteristic;
  StreamSubscription<List<int>>? notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  _ActivePeerSession({
    required this.peer,
    required this.device,
  });

  void dispose() {
    notificationSubscription?.cancel();
    connectionSubscription?.cancel();
  }
}

/// Production implementation of [BleTransport] utilizing:
/// - `FlutterBlePeripheral` for GATT server (peripheral reception and notification)
/// - `FlutterBluePlus` for GATT client (central connection and transmission)
class FlutterBleTransport extends BleTransport {
  final NodeIdentityService? identityService;

  final StreamController<MeshMessage> _messageReceivedController =
      StreamController<MeshMessage>.broadcast();
  final StreamController<BleAckPacket> _ackReceivedController =
      StreamController<BleAckPacket>.broadcast();
  final StreamController<PeerNode> _peerConnectionController =
      StreamController<PeerNode>.broadcast();

  final BleMessageReassembler _reassembler = BleMessageReassembler();
  final Map<String, _ActivePeerSession> _sessions = {};
  final Map<String, PeerConnectionState> _peerStates = {};
  final Map<String, Completer<BleAckPacket>> _pendingAcks = {};

  StreamSubscription<Uint8List>? _peripheralDataSubscription;
  Timer? _staleAssemblyTimer;
  BleTransportStats _stats = const BleTransportStats();

  FlutterBleTransport({this.identityService});

  String get localNodeId => identityService?.currentNodeId ?? '';

  @override
  Stream<MeshMessage> get onMessageReceived => _messageReceivedController.stream;

  @override
  Stream<BleAckPacket> get onAckReceived => _ackReceivedController.stream;

  @override
  Stream<PeerNode> get onPeerConnectionChanged => _peerConnectionController.stream;

  @override
  BleTransportStats get stats => _stats;

  @override
  PeerConnectionState getConnectionState(String nodeId) {
    return _peerStates[nodeId] ?? PeerConnectionState.disconnected;
  }

  @override
  List<PeerNode> get connectedPeers =>
      _sessions.values.map((s) => s.peer).toList();

  @override
  int get connectedPeerCount => _sessions.length;

  @override
  Future<void> initialize() async {
    // Start periodic stale fragment cleanup
    _staleAssemblyTimer = Timer.periodic(
      const Duration(seconds: AppConstants.fragmentAssemblyTimeoutSeconds),
      (_) => _reassembler.pruneStaleAssemblies(),
    );

    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('ResQMesh: BleTransport native GATT initialized in desktop/test mode.');
      return;
    }

    try {
      final peripheral = FlutterBlePeripheral();
      _peripheralDataSubscription = peripheral.onDataReceived.listen((data) {
        handleIncomingRawBytes(data);
      });
    } catch (e) {
      debugPrint('ResQMesh: Peripheral GATT listener setup notice: $e');
    }
  }

  /// Processes raw wire bytes received either via Peripheral GATT write or Central notification.
  void handleIncomingRawBytes(Uint8List data, {String? fromPeerId}) {
    if (data.isEmpty) return;

    _stats = _stats.copyWith(
      bytesReceived: _stats.bytesReceived + data.length,
      lastEventTimestamp: DateTime.now().toUtc(),
    );

    final decoded = BlePacketCodec.decode(data);
    if (decoded == null) {
      return;
    }

    if (decoded is BleMessageFragment) {
      _handleFragment(decoded, fromPeerId: fromPeerId);
    } else if (decoded is BleAckPacket) {
      _handleAck(decoded);
    }
  }

  void _handleFragment(BleMessageFragment fragment, {String? fromPeerId}) {
    final completeBytes = _reassembler.addFragment(fragment);
    if (completeBytes == null) {
      // More fragments expected or duplicate
      return;
    }

    // Attempt to decode reconstructed wire message
    final message = BleMessageWireFormat.decode(completeBytes);
    if (message == null) {
      return;
    }

    _stats = _stats.copyWith(
      messagesReceived: _stats.messagesReceived + 1,
      lastBleEvent: 'Message received from ${message.originNodeId}',
      lastEventTimestamp: DateTime.now().toUtc(),
    );
    notifyListeners();

    // Emit received message to DTN storage & UI pipeline
    _messageReceivedController.add(message);

    // Send application-level ACK back to sender
    final ack = BleAckPacket(
      messageId: message.messageId,
      ackNodeId: localNodeId,
    );
    sendAckBack(ack, targetNodeId: message.senderNodeId);
  }

  void _handleAck(BleAckPacket ack) {
    _stats = _stats.copyWith(
      lastBleEvent: 'ACK received for ${ack.messageId}',
      lastEventTimestamp: DateTime.now().toUtc(),
    );
    notifyListeners();

    _ackReceivedController.add(ack);

    final pending = _pendingAcks.remove(ack.messageId);
    if (pending != null && !pending.isCompleted) {
      pending.complete(ack);
    }
  }

  /// Sends an ACK back to the neighboring node using either Central write or Peripheral notification.
  Future<void> sendAckBack(BleAckPacket ack, {String? targetNodeId}) async {
    final ackBytes = BlePacketCodec.encodeAck(ack);

    // 1. Try notifying through peripheral GATT service if active
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final peripheral = FlutterBlePeripheral();
        await peripheral.sendData(
          ackBytes,
          characteristicUuid: AppConstants.bleCharacteristicTxUuid,
        );
        _stats = _stats.copyWith(
          bytesSent: _stats.bytesSent + ackBytes.length,
        );
        return;
      } catch (_) {}
    }

    // 2. Try writing through an established Central session
    if (targetNodeId != null) {
      final session = _sessions[targetNodeId];
      if (session?.rxCharacteristic != null) {
        try {
          await session!.rxCharacteristic!.write(ackBytes, withoutResponse: false);
          _stats = _stats.copyWith(
            bytesSent: _stats.bytesSent + ackBytes.length,
          );
        } catch (_) {}
      }
    }
  }

  @override
  Future<bool> connect(PeerNode peer) async {
    if (peer.nodeId.isEmpty) return false;

    _updatePeerState(peer, PeerConnectionState.connecting);

    if (kIsWeb || !Platform.isAndroid) {
      // In non-Android environment, record ready connection state
      _updatePeerState(peer, PeerConnectionState.ready);
      return true;
    }

    try {
      BluetoothDevice device;
      if (peer.deviceAddress != null && peer.deviceAddress!.isNotEmpty) {
        device = BluetoothDevice.fromId(peer.deviceAddress!);
      } else {
        _updatePeerState(peer, PeerConnectionState.failed);
        return false;
      }

      final session = _ActivePeerSession(peer: peer, device: device);

      // Listen for connection state changes
      session.connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _sessions.remove(peer.nodeId);
          _updatePeerState(peer, PeerConnectionState.disconnected);
        }
      });

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: AppConstants.bleConnectionTimeoutSeconds),
        autoConnect: false,
      );

      _updatePeerState(peer, PeerConnectionState.connected);
      _updatePeerState(peer, PeerConnectionState.discoveringServices);

      final services = await device.discoverServices();
      BluetoothCharacteristic? rxChar;
      BluetoothCharacteristic? txChar;

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() ==
            AppConstants.bleServiceUuid.toLowerCase()) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == AppConstants.bleCharacteristicTxUuid.toLowerCase()) {
              // Peripheral TX is the central's notification characteristic.
              txChar = char;
            }
            if (charUuid == AppConstants.bleCharacteristicRxUuid.toLowerCase()) {
              // Peripheral RX is writable by the central.
              rxChar = char;
            }
          }
        }
      }

      session.rxCharacteristic = rxChar;
      session.txCharacteristic = txChar;

      if (txChar != null) {
        await txChar.setNotifyValue(true);
        session.notificationSubscription = txChar.onValueReceived.listen((bytes) {
          handleIncomingRawBytes(Uint8List.fromList(bytes), fromPeerId: peer.nodeId);
        });
      }

      _sessions[peer.nodeId] = session;
      _updatePeerState(peer, PeerConnectionState.ready);
      return true;
    } catch (e) {
      debugPrint('ResQMesh: Failed to connect to peer ${peer.nodeId}: $e');
      _sessions.remove(peer.nodeId);
      _updatePeerState(peer, PeerConnectionState.failed);
      return false;
    }
  }

  @override
  Future<void> disconnect(String nodeId) async {
    final session = _sessions.remove(nodeId);
    if (session != null) {
      _updatePeerState(session.peer, PeerConnectionState.disconnecting);
      try {
        session.dispose();
        await session.device.disconnect();
      } catch (_) {}
      _updatePeerState(session.peer, PeerConnectionState.disconnected);
    }
  }

  @override
  Future<bool> sendMeshMessage(MeshMessage message, PeerNode peer) async {
    // Ensure peer is in ready state or attempt connection
    if (getConnectionState(peer.nodeId) != PeerConnectionState.ready) {
      final connected = await connect(peer);
      if (!connected) {
        _recordFailure('Connection failed to ${peer.nodeId}');
        return false;
      }
    }

    _updatePeerState(peer, PeerConnectionState.sending);

    final wireBytes = BleMessageWireFormat.encode(message);
    final fragments = BleMessageFragmenter.fragment(
      wireBytes,
      messageId: message.messageId,
      chunkSize: AppConstants.bleMaxFragmentPayloadSize,
    );

    final ackCompleter = Completer<BleAckPacket>();
    _pendingAcks[message.messageId] = ackCompleter;

    try {
      final session = _sessions[peer.nodeId];

      if (kIsWeb || !Platform.isAndroid || session == null) {
        // Desktop / Mock simulation mode fallback: simulate remote receive & ACK
        _stats = _stats.copyWith(
          bytesSent: _stats.bytesSent + wireBytes.length,
          messagesSent: _stats.messagesSent + 1,
          lastBleEvent: 'Delivered to ${peer.nodeId} (simulated/local ACK)',
          lastEventTimestamp: DateTime.now().toUtc(),
        );
        _updatePeerState(peer, PeerConnectionState.ready);
        notifyListeners();
        return true;
      }

      final char = session.rxCharacteristic;
      if (char == null) {
        _recordFailure('Target write characteristic not found on ${peer.nodeId}');
        _updatePeerState(peer, PeerConnectionState.ready);
        return false;
      }

      // Transmit all fragments sequentially
      for (final fragment in fragments) {
        final packetBytes = BlePacketCodec.encodeFragment(fragment);
        await char.write(packetBytes, withoutResponse: false);
        _stats = _stats.copyWith(
          bytesSent: _stats.bytesSent + packetBytes.length,
        );
      }

      // Await application-level ACK
      await ackCompleter.future.timeout(
        const Duration(seconds: AppConstants.bleAckTimeoutSeconds),
      );

      _stats = _stats.copyWith(
        messagesSent: _stats.messagesSent + 1,
        lastBleEvent: 'Delivered to ${peer.nodeId} (ACK received)',
        lastEventTimestamp: DateTime.now().toUtc(),
      );
      _updatePeerState(peer, PeerConnectionState.ready);
      notifyListeners();
      return true;
    } on TimeoutException {
      _pendingAcks.remove(message.messageId);
      _recordFailure('ACK timed out from ${peer.nodeId}');
      _updatePeerState(peer, PeerConnectionState.ready);
      return false;
    } catch (e) {
      _pendingAcks.remove(message.messageId);
      _recordFailure('Transmission error: $e');
      _updatePeerState(peer, PeerConnectionState.ready);
      return false;
    }
  }

  void _recordFailure(String eventReason) {
    _stats = _stats.copyWith(
      messagesFailed: _stats.messagesFailed + 1,
      lastBleEvent: eventReason,
      lastEventTimestamp: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void _updatePeerState(PeerNode peer, PeerConnectionState state) {
    debugPrint('[ResQMesh][BLE] connection state; peer: ${peer.nodeId}; state: $state');
    _peerStates[peer.nodeId] = state;
    final updated = peer.copyWith(connectionState: state);
    _peerConnectionController.add(updated);
    notifyListeners();
  }

  @override
  void dispose() {
    _staleAssemblyTimer?.cancel();
    _peripheralDataSubscription?.cancel();
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    _messageReceivedController.close();
    _ackReceivedController.close();
    _peerConnectionController.close();
    super.dispose();
  }
}
