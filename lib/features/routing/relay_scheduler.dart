import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../mesh/models/mesh_message.dart';
import '../mesh/models/peer_node.dart';
import '../storage/repositories/dtn_message_repository.dart';
import '../transport/ble_transport.dart';
import 'config/routing_config.dart';
import 'intelligent_routing_engine.dart';
import 'models/forwarding_record.dart';
import 'models/relay_decision.dart';
import 'models/relay_metrics.dart';

/// Tracks bounded retry state per peer per message bundle.
class TransmissionRetryRecord {
  final int attemptCount;
  final DateTime lastAttempt;
  final DateTime nextRetry;
  final String? failureReason;

  const TransmissionRetryRecord({
    required this.attemptCount,
    required this.lastAttempt,
    required this.nextRetry,
    this.failureReason,
  });
}

/// Transmission and Relay Scheduler for intelligent DTN store-and-forward routing.
///
/// Features:
/// - Priority-ordered outbox queue with fairness aging (prevents starvation)
/// - Bounded linear/exponential backoff retries per peer
/// - Adaptive peer candidate selection using utility scoring
/// - Duplicate transmission suppression and routing loop prevention
/// - Storage quota enforcement protecting critical life-safety bundles
class RelayScheduler {
  final BleTransport? transport;
  final DtnMessageRepository? messageRepository;
  final RelayDecisionEngine decisionEngine;
  final RelayMetrics metrics;
  final String localNodeId;
  final RoutingConfig config;

  final List<MeshMessage> _outbox = [];
  final Map<String, DateTime> _enqueuedTimes = {}; // messageId -> DateTime
  final Map<String, Set<String>> _peerSentMessages = {}; // peerNodeId -> Set<messageId>
  final Map<String, Map<String, TransmissionRetryRecord>> _peerRetries = {}; // peerNodeId -> {messageId: record}
  final Map<String, Set<String>> _ackedMessages = {}; // messageId -> Set<peerNodeId>

  Timer? _sweepTimer;
  bool _isSweeping = false;

  RelayScheduler({
    required this.decisionEngine,
    required this.metrics,
    required this.localNodeId,
    this.transport,
    this.messageRepository,
    RoutingConfig? config,
  }) : config = config ??
            (decisionEngine is IntelligentRoutingEngine
                ? decisionEngine.config
                : const RoutingConfig());

  int get outboxCount => _outbox.length;
  List<MeshMessage> get outbox => List.unmodifiable(_outbox);

  /// Enqueues a message for opportunistic store-and-forward relay.
  void scheduleMessage(MeshMessage message) {
    if (message.isExpired()) {
      metrics.recordExpired();
      return;
    }

    if (message.hopCount >= message.maxHops ||
        message.hopCount >= config.maximumHops) {
      return;
    }

    final now = DateTime.now().toUtc();
    _enqueuedTimes.putIfAbsent(message.messageId, () => now);

    // Replace if already in outbox, else add
    final existingIndex =
        _outbox.indexWhere((m) => m.messageId == message.messageId);
    if (existingIndex != -1) {
      _outbox[existingIndex] = message;
    } else {
      _outbox.add(message);
      metrics.recordStored();
    }

    _sortOutboxWithFairness();

    // Storage capacity enforcement
    _enforceStorage();
    metrics.updateWaitingCount(_outbox.length);
  }

  /// Sorts outbox with emergency priority dominance and aging fairness credit.
  void _sortOutboxWithFairness() {
    final now = DateTime.now().toUtc();
    _outbox.sort((a, b) {
      final scoreA = _calculateEffectivePriority(a, now);
      final scoreB = _calculateEffectivePriority(b, now);
      return scoreB.compareTo(scoreA); // Highest effective score first
    });
  }

  /// Calculates effective priority score, adding a small aging bonus for queued messages
  /// to avoid starvation of lower priority messages while emergency traffic flows.
  int _calculateEffectivePriority(MeshMessage message, DateTime now) {
    final baseScore = decisionEngine.priorityScore(message);
    if (message.isSos) {
      return baseScore + 10000; // SOS always takes absolute precedence
    }
    final enqueued = _enqueuedTimes[message.messageId] ?? now;
    final ageSeconds = now.difference(enqueued).inSeconds;
    // Add 1 point per 10 seconds of queue waiting (capped at +50)
    final agingCredit = (ageSeconds ~/ 10).clamp(0, 50);
    return baseScore + agingCredit;
  }

  void _enforceStorage() {
    final engine = decisionEngine;
    if (engine is IntelligentRoutingEngine) {
      final pruned = engine.enforceStorageQuotas(_outbox);
      _outbox.clear();
      _outbox.addAll(pruned);
    } else if (_outbox.length > config.storageLimit) {
      _outbox.removeRange(config.storageLimit, _outbox.length);
    }
  }

  /// Removes a message from the outbox by messageId.
  void removeFromOutbox(String messageId) {
    _outbox.removeWhere((m) => m.messageId == messageId);
    _enqueuedTimes.remove(messageId);
    metrics.updateWaitingCount(_outbox.length);
  }

  /// Marks an ACK received from a peer for a specific messageId.
  void recordAck(String messageId, String peerNodeId) {
    _ackedMessages.putIfAbsent(messageId, () => {}).add(peerNodeId);
    metrics.recordDelivered();

    final engine = decisionEngine;
    if (engine is IntelligentRoutingEngine) {
      engine.recordAckReceived(peerId: peerNodeId, messageId: messageId);
    }
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
          _enqueuedTimes.remove(m.messageId);
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

      // Re-sort with fairness
      _sortOutboxWithFairness();

      // Snapshot candidate messages
      final candidateMessages = List<MeshMessage>.from(_outbox);

      for (final message in candidateMessages) {
        // Use IntelligentRoutingEngine target peer selection if available
        List<PeerNode> targets;
        final engine = decisionEngine;
        if (engine is IntelligentRoutingEngine) {
          targets = engine.selectTargetPeers(
            message: message,
            availablePeers: eligiblePeers,
            localNodeId: localNodeId,
            peerSentMap: _peerSentMessages,
            peerAckMap: _ackedMessages,
          );
        } else {
          targets = eligiblePeers;
        }

        for (final peer in targets) {
          final ttlRemaining = message.expiresAt.difference(now).inSeconds;
          final alreadyForwarded =
              _peerSentMessages[peer.nodeId]?.contains(message.messageId) ??
                  false;
          final alreadyAcked =
              _ackedMessages[message.messageId]?.contains(peer.nodeId) ?? false;

          // Bounded retry check
          final retryRecord = _peerRetries[peer.nodeId]?[message.messageId];
          if (retryRecord != null) {
            if (retryRecord.attemptCount >= config.maxRetries) {
              continue; // Exceeded max retries for this peer
            }
            if (now.isBefore(retryRecord.nextRetry)) {
              continue; // Backoff interval still active
            }
          }

          final input = RelayDecisionInput(
            message: message,
            peer: peer,
            ttlRemainingSeconds: ttlRemaining,
            localNodeId: localNodeId,
            peerAlreadyForwarded: alreadyForwarded,
            peerAlreadyAcked: alreadyAcked,
            retryCountForPeer: retryRecord?.attemptCount ?? 0,
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

            if (engine is IntelligentRoutingEngine) {
              engine.recordTransmissionResult(
                peerId: peer.nodeId,
                messageId: message.messageId,
                success: true,
                hopCount: outbound.hopCount,
                rssi: peer.rssi,
              );
            }

            if (messageRepository != null) {
              await messageRepository!.updateMessage(outbound);
            }

            // Update outbox entry with updated hop count & history
            final idx =
                _outbox.indexWhere((m) => m.messageId == message.messageId);
            if (idx != -1) {
              _outbox[idx] = outbound;
            }

            relayedCount++;
          } else {
            final nextAttempts = (retryRecord?.attemptCount ?? 0) + 1;
            final backoffDelay =
                Duration(milliseconds: config.retryBaseDelayMs * nextAttempts);
            _peerRetries.putIfAbsent(peer.nodeId, () => {})[message.messageId] =
                TransmissionRetryRecord(
              attemptCount: nextAttempts,
              lastAttempt: now,
              nextRetry: now.add(backoffDelay),
              failureReason: 'BLE transmission failed',
            );
            metrics.recordFailed();

            if (engine is IntelligentRoutingEngine) {
              engine.recordTransmissionResult(
                peerId: peer.nodeId,
                messageId: message.messageId,
                success: false,
                failureReason: 'BLE GATT error',
              );
            }
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
    _enqueuedTimes.clear();
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
