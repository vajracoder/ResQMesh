import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import '../storage/repositories/dtn_message_repository.dart';
import '../transport/ble_transport.dart';
import 'models/forwarding_record.dart';
import 'models/relay_decision.dart';
import 'models/relay_metrics.dart';

/// Coordinates opportunistic store-and-forward relay across physical BLE encounters.
///
/// Features:
/// - Priority-ordered outbox queue (urgency score + hop penalty)
/// - Per-peer send history to prevent redundant transmissions
/// - Loop prevention and hop limit enforcement
/// - Backward-compatible persistence updates
/// - Runtime metric tracking for diagnostics and UI
class RelayScheduler {
  final BleTransport? transport;
  final DtnMessageRepository? messageRepository;
  final RelayDecisionEngine decisionEngine;
  final RelayMetrics metrics;
  final String localNodeId;

  final List<MeshMessage> _outbox = [];
  final Map<String, Set<String>> _peerSentMessages = {}; // peerNodeId -> Set<messageId>
  final Map<String, Map<String, int>> _peerRetries = {}; // peerNodeId -> {messageId: retryCount}
  final Map<String, Set<String>> _ackedMessages = {}; // messageId -> Set<peerNodeId>

  Timer? _sweepTimer;
  bool _isSweeping = false;

  RelayScheduler({
    required this.decisionEngine,
    required this.metrics,
    required this.localNodeId,
    this.transport,
    this.messageRepository,
  });

  int get outboxCount => _outbox.length;
  List<MeshMessage> get outbox => List.unmodifiable(_outbox);

  /// Enqueues a message for opportunistic store-and-forward relay.
  void scheduleMessage(MeshMessage message) {
    if (message.isExpired()) {
      metrics.recordExpired();
      return;
    }

    if (message.hopCount >= message.maxHops ||
        message.hopCount >= AppConstants.maxHopCount) {
      return;
    }

    // Replace if already in outbox, else add
    final existingIndex =
        _outbox.indexWhere((m) => m.messageId == message.messageId);
    if (existingIndex != -1) {
      _outbox[existingIndex] = message;
    } else {
      _outbox.add(message);
      metrics.recordStored();
    }

    // Sort descending by priority score
    _outbox.sort((a, b) => decisionEngine
        .priorityScore(b)
        .compareTo(decisionEngine.priorityScore(a)));

    // Capacity bound
    if (_outbox.length > AppConstants.relayOutboxCapacity) {
      _outbox.removeRange(AppConstants.relayOutboxCapacity, _outbox.length);
    }

    metrics.updateWaitingCount(_outbox.length);
  }

  /// Removes a message from the outbox by messageId.
  void removeFromOutbox(String messageId) {
    _outbox.removeWhere((m) => m.messageId == messageId);
    metrics.updateWaitingCount(_outbox.length);
  }

  /// Marks an ACK received from a peer for a specific messageId.
  void recordAck(String messageId, String peerNodeId) {
    _ackedMessages.putIfAbsent(messageId, () => {}).add(peerNodeId);
    metrics.recordDelivered();
  }

  /// Evaluates and dispatches queued messages to encountered peers.
  /// Returns the number of successful relay transmissions.
  Future<int> sweepRelay(List<PeerNode> availablePeers) async {
    if (_isSweeping || _outbox.isEmpty || availablePeers.isEmpty) {
      return 0;
    }

    _isSweeping = true;
    int relayedCount = 0;

    try {
      final now = DateTime.now().toUtc();
      // Filter out expired messages
      _outbox.removeWhere((m) {
        if (m.isExpired(referenceTime: now)) {
          metrics.recordExpired();
          return true;
        }
        return false;
      });

      // Filter eligible peers: must be ResQMesh peer and not local node
      final eligiblePeers = availablePeers
          .where((p) => p.isResQMeshPeer && p.nodeId != localNodeId)
          .toList();

      metrics.updateRelayPeerCount(eligiblePeers.length);

      if (eligiblePeers.isEmpty) {
        metrics.updateWaitingCount(_outbox.length);
        return 0;
      }

      // Snapshot outbox to iterate safely
      final candidateMessages = List<MeshMessage>.from(_outbox);

      for (final message in candidateMessages) {
        for (final peer in eligiblePeers) {
          final ttlRemaining = message.expiresAt.difference(now).inSeconds;
          final alreadyForwarded =
              _peerSentMessages[peer.nodeId]?.contains(message.messageId) ??
                  false;
          final alreadyAcked =
              _ackedMessages[message.messageId]?.contains(peer.nodeId) ?? false;
          final retries = _peerRetries[peer.nodeId]?[message.messageId] ?? 0;

          final input = RelayDecisionInput(
            message: message,
            peer: peer,
            ttlRemainingSeconds: ttlRemaining,
            localNodeId: localNodeId,
            peerAlreadyForwarded: alreadyForwarded,
            peerAlreadyAcked: alreadyAcked,
            retryCountForPeer: retries,
          );

          final decision = decisionEngine.evaluate(input);

          if (decision.outcome == RelayOutcome.duplicate) {
            metrics.recordDuplicatePrevented();
            continue;
          }

          if (!decision.shouldForward) {
            continue;
          }

          // Prepare relay-forwarded bundle:
          final newHopCount = message.hopCount + 1;
          final record = ForwardingRecord(
            relayNodeId: localNodeId,
            forwardedAt: DateTime.now().toUtc(),
            hopNumber: newHopCount,
            rssi: peer.rssi,
          );

          final updatedHistory = [...message.forwardingHistory, record];
          final outbound = message.copyWith(
            senderNodeId: localNodeId,
            hopCount: newHopCount,
            lastForwardedAt: DateTime.now().toUtc(),
            status: MessageStatus.forwarded,
            forwardingHistory: updatedHistory,
          );

          bool sent = false;
          if (transport != null) {
            sent = await transport!.sendMeshMessage(outbound, peer);
          } else {
            sent = true;
          }

          if (sent) {
            _peerSentMessages
                .putIfAbsent(peer.nodeId, () => {})
                .add(message.messageId);
            _peerRetries[peer.nodeId]?.remove(message.messageId);
            metrics.recordRelayed(outbound.hopCount);

            if (messageRepository != null) {
              await messageRepository!.updateMessage(outbound);
            }

            // Update in-memory outbox entry
            final idx =
                _outbox.indexWhere((m) => m.messageId == message.messageId);
            if (idx != -1) {
              _outbox[idx] = outbound;
            }

            relayedCount++;
          } else {
            final nextRetry = retries + 1;
            _peerRetries.putIfAbsent(peer.nodeId, () => {})[message.messageId] =
                nextRetry;
            metrics.recordFailed();
          }
        }
      }
    } finally {
      metrics.updateWaitingCount(_outbox.length);
      _isSweeping = false;
    }

    return relayedCount;
  }

  /// Starts background periodic opportunistic forwarding sweeps.
  void startPeriodicRelay(
    List<PeerNode> Function() getPeers, {
    Duration interval =
        const Duration(seconds: AppConstants.relaySchedulerIntervalSeconds),
  }) {
    stopPeriodicRelay();
    _sweepTimer = Timer.periodic(interval, (_) {
      sweepRelay(getPeers());
    });
  }

  /// Stops background periodic relay timer.
  void stopPeriodicRelay() {
    _sweepTimer?.cancel();
    _sweepTimer = null;
  }

  void clear() {
    _outbox.clear();
    _peerSentMessages.clear();
    _peerRetries.clear();
    _ackedMessages.clear();
    metrics.updateWaitingCount(0);
  }

  void dispose() {
    stopPeriodicRelay();
    clear();
  }
}
