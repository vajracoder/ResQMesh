import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../decision/decision_engine_interface.dart';
import '../discovery/peer_discovery_interface.dart';
import '../routing/dtn_router_interface.dart';
import 'models/mesh_message.dart';
import 'models/peer_node.dart';

/// Central Message Manager coordinating the offline ResQMesh core path:
/// Flutter UI -> Message Manager -> Decision Engine -> DTN Router -> Peer Discovery -> BLE
class MessageManager extends ChangeNotifier {
  final DecisionEngine decisionEngine;
  final DtnRouter dtnRouter;
  final PeerDiscoveryService discoveryService;
  final String _localNodeId;
  final _uuid = const Uuid();

  final List<MeshMessage> _messages = [];
  StreamSubscription<List<PeerNode>>? _peerSubscription;
  List<PeerNode> _currentPeers = [];

  MessageManager({
    required this.decisionEngine,
    required this.dtnRouter,
    required this.discoveryService,
    String? localNodeId,
  })  : _localNodeId = localNodeId ?? 'node-local-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}' {
    _init();
  }

  void _init() {
    _currentPeers = discoveryService.currentPeers;
    _peerSubscription = discoveryService.peersStream.listen((peers) {
      _currentPeers = peers;
      dtnRouter.onPeersUpdated(peers);
      notifyListeners();
    });
  }

  // --- Public Getters ---
  String get localNodeId => _localNodeId;
  List<MeshMessage> get messages => List.unmodifiable(_messages);
  List<PeerNode> get peers => List.unmodifiable(_currentPeers);
  int get activePeerCount => _currentPeers.length;
  int get queuedMessageCount => _messages.where((m) => m.status == MessageStatus.queued).length;

  /// Trigger emergency SOS broadcast to all reachable nodes.
  Future<MeshMessage> sendEmergencySos({required String details}) async {
    return sendMessage(
      content: details.isEmpty ? 'EMERGENCY SOS: Immediate assistance required!' : 'EMERGENCY SOS: $details',
      priority: MessagePriority.critical,
      recipientId: '*', // Broadcast to all
    );
  }

  /// Send standard or priority mesh message.
  Future<MeshMessage> sendMessage({
    required String content,
    MessagePriority priority = MessagePriority.normal,
    String recipientId = '*',
  }) async {
    final message = MeshMessage(
      id: _uuid.v4(),
      senderId: _localNodeId,
      recipientId: recipientId,
      content: content.trim(),
      timestamp: DateTime.now().toUtc(),
      priority: priority,
      status: MessageStatus.queued,
      hopCount: 0,
    );

    // 1. Evaluate policy via Decision Engine
    final decision = decisionEngine.evaluateMessage(message);

    if (decision == DecisionOutcome.dropStaleOrDuplicated) {
      final droppedMessage = message.copyWith(status: MessageStatus.expired);
      _messages.insert(0, droppedMessage);
      notifyListeners();
      return droppedMessage;
    }

    // 2. Add message to local history
    _messages.insert(0, message);
    notifyListeners();

    // 3. Dispatch through DTN Router (store-and-forward)
    final dispatched = await dtnRouter.routeMessage(message, _currentPeers);

    // 4. Update status in local list
    final updatedIndex = _messages.indexWhere((m) => m.id == message.id);
    if (updatedIndex != -1) {
      _messages[updatedIndex] = message.copyWith(
        status: dispatched ? MessageStatus.forwarded : MessageStatus.queued,
      );
      notifyListeners();
    }

    return _messages[updatedIndex != -1 ? updatedIndex : 0];
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    super.dispose();
  }
}
