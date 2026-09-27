import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../decision/decision_engine_interface.dart';
import '../discovery/peer_discovery_interface.dart';
import '../identity/models/node_role.dart';
import '../identity/services/node_identity_service.dart';
import '../routing/dtn_router_interface.dart';
import '../storage/repositories/dtn_message_repository.dart';
import 'models/mesh_message.dart';
import 'models/peer_node.dart';

/// Central Message Manager coordinating the offline ResQMesh core path:
/// Flutter UI -> Message Manager -> Decision Engine -> DTN Repository -> SQLite -> DTN Router -> Peer Discovery -> BLE
class MessageManager extends ChangeNotifier {
  final DecisionEngine decisionEngine;
  final DtnRouter dtnRouter;
  final PeerDiscoveryService discoveryService;
  final NodeIdentityService? identityService;
  final DtnMessageRepository? messageRepository;
  final String _localNodeId;
  final _uuid = const Uuid();

  final List<MeshMessage> _messages = [];
  StreamSubscription<List<PeerNode>>? _peerSubscription;
  List<PeerNode> _currentPeers = [];
  bool _isStorageInitialized = false;

  MessageManager({
    required this.decisionEngine,
    required this.dtnRouter,
    required this.discoveryService,
    this.identityService,
    this.messageRepository,
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

  /// Initializes storage and loads persisted DTN messages from SQLite into active memory.
  Future<void> initializeStorage() async {
    if (messageRepository != null) {
      await messageRepository!.init();
      final loaded = await messageRepository!.getAllMessages();
      _messages.clear();
      _messages.addAll(loaded);
      _isStorageInitialized = true;
      notifyListeners();
    }
  }

  // --- Public Getters ---
  String get localNodeId {
    final serviceId = identityService?.currentNodeId;
    if (serviceId != null && serviceId.isNotEmpty) {
      return serviceId;
    }
    return _localNodeId;
  }

  List<MeshMessage> get messages => List.unmodifiable(_messages);
  List<PeerNode> get peers => List.unmodifiable(_currentPeers);
  int get activePeerCount => _currentPeers.length;
  int get queuedMessageCount => _messages.where((m) => m.status == MessageStatus.queued || m.status == MessageStatus.stored).length;

  int get totalStoredCount => _messages.length;
  int get activeMessageCount => _messages.where((m) => !m.isExpired()).length;
  int get expiredMessageCount => _messages.where((m) => m.isExpired() || m.status == MessageStatus.expired).length;
  int get criticalMessageCount => _messages.where((m) => m.priority == MessagePriority.critical).length;
  bool get isStorageReady => _isStorageInitialized || messageRepository != null;

  /// Trigger emergency SOS broadcast to all reachable nodes.
  Future<MeshMessage> sendEmergencySos({required String details}) async {
    return sendMessage(
      content: details.isEmpty ? 'EMERGENCY SOS: Immediate assistance required!' : 'EMERGENCY SOS: $details',
      messageType: MessageType.sos,
      priority: MessagePriority.critical,
      recipientId: '*', // Broadcast to all
    );
  }

  /// Creates a test message specifically labeled for local storage verification.
  Future<MeshMessage> createTestMessage({String? customNote}) async {
    return sendMessage(
      content: '[TEST ONLY] Local DTN Storage Test: ${customNote ?? "Simulated emergency transmission"}',
      messageType: MessageType.sos,
      priority: MessagePriority.critical,
      recipientId: '*',
    );
  }

  /// Send standard, hazard, or priority mesh message.
  Future<MeshMessage> sendMessage({
    required String content,
    MessageType messageType = MessageType.info,
    MessagePriority priority = MessagePriority.normal,
    String recipientId = '*',
    int ttl = 86400,
  }) async {
    final now = DateTime.now().toUtc();
    final messageId = 'RQM-MSG-${_uuid.v4()}';
    final role = identityService?.identity?.role ?? NodeRole.civilian;

    final message = MeshMessage(
      messageId: messageId,
      originNodeId: localNodeId,
      senderNodeId: localNodeId,
      destinationNodeId: recipientId,
      messageType: messageType,
      priority: priority,
      payload: content.trim(),
      createdAt: now,
      expiresAt: now.add(Duration(seconds: ttl)),
      ttl: ttl,
      hopCount: 0,
      maxHops: 5,
      status: MessageStatus.queued,
      retryCount: 0,
      createdByRole: role,
    );

    // 1. Evaluate policy via Decision Engine
    final decision = decisionEngine.evaluateMessage(message);

    if (decision == DecisionOutcome.dropStaleOrDuplicated) {
      final droppedMessage = message.copyWith(status: MessageStatus.expired);
      if (messageRepository != null) {
        await messageRepository!.createMessage(droppedMessage);
      }
      _messages.insert(0, droppedMessage);
      notifyListeners();
      return droppedMessage;
    }

    // 2. Persist to SQLite DTN storage
    if (messageRepository != null) {
      await messageRepository!.createMessage(message);
    }

    // 3. Add message to local in-memory history
    _messages.insert(0, message);
    notifyListeners();

    // 4. Dispatch through DTN Router (store-and-forward)
    final dispatched = await dtnRouter.routeMessage(message, _currentPeers);

    // 5. Update status if forwarded
    if (dispatched) {
      final updated = message.copyWith(status: MessageStatus.forwarded);
      final updatedIndex = _messages.indexWhere((m) => m.messageId == message.messageId);
      if (updatedIndex != -1) {
        _messages[updatedIndex] = updated;
      }
      if (messageRepository != null) {
        await messageRepository!.updateMessageStatus(message.messageId, MessageStatus.forwarded);
      }
      notifyListeners();
      return updated;
    }

    return message;
  }

  /// Deletes all expired messages from SQLite and in-memory list.
  Future<int> purgeExpiredMessages() async {
    if (messageRepository != null) {
      final deletedCount = await messageRepository!.deleteExpiredMessages();
      _messages.removeWhere((m) => m.isExpired());
      notifyListeners();
      return deletedCount;
    }
    final before = _messages.length;
    _messages.removeWhere((m) => m.isExpired());
    notifyListeners();
    return before - _messages.length;
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    super.dispose();
  }
}
