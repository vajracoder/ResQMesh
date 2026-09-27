import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/constants/app_constants.dart';
import 'package:resqmesh/features/mesh/models/mesh_message.dart';
import 'package:resqmesh/features/mesh/models/peer_node.dart';
import 'package:resqmesh/features/routing/models/forwarding_record.dart';
import 'package:resqmesh/features/routing/models/relay_decision.dart';
import 'package:resqmesh/features/routing/models/relay_metrics.dart';
import 'package:resqmesh/features/routing/multi_hop_decision_engine.dart';
import 'package:resqmesh/features/routing/relay_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nodeA = 'RQM-00000000-0000-0000-0000-000000000001';
  const nodeB = 'RQM-00000000-0000-0000-0000-000000000002';
  const nodeC = 'RQM-00000000-0000-0000-0000-000000000003';

  late MultiHopDecisionEngine decisionEngine;
  late RelayMetrics metrics;
  late RelayScheduler scheduler;

  setUp(() {
    decisionEngine = const MultiHopDecisionEngine();
    metrics = RelayMetrics();
    scheduler = RelayScheduler(
      decisionEngine: decisionEngine,
      metrics: metrics,
      localNodeId: nodeB,
    );
  });

  tearDown(() {
    scheduler.dispose();
  });

  PeerNode createPeer(String nodeId, {int rssi = -70}) {
    return PeerNode(
      nodeId: nodeId,
      displayName: 'Node-$nodeId',
      rssi: rssi,
      lastSeen: DateTime.now().toUtc(),
      isResQMeshPeer: true,
    );
  }

  MeshMessage createTestMessage({
    String messageId = 'RQM-MSG-TEST-001',
    String origin = nodeA,
    String sender = nodeA,
    String destination = '*',
    int hopCount = 0,
    int maxHops = 5,
    MessagePriority priority = MessagePriority.normal,
    MessageType messageType = MessageType.info,
    int ttl = 86400,
    List<ForwardingRecord>? forwardingHistory,
  }) {
    final now = DateTime.now().toUtc();
    return MeshMessage(
      messageId: messageId,
      originNodeId: origin,
      senderNodeId: sender,
      destinationNodeId: destination,
      messageType: messageType,
      priority: priority,
      payload: 'Emergency coordination payload',
      createdAt: now,
      expiresAt: now.add(Duration(seconds: ttl)),
      ttl: ttl,
      hopCount: hopCount,
      maxHops: maxHops,
      forwardingHistory: forwardingHistory,
    );
  }

  group('ResQMesh Step 6 — Multi-Hop DTN Relay Unit Tests', () {
    // TEST 1
    test('TEST 1: Hop count increments on each forward', () async {
      final msg = createTestMessage(origin: nodeA, sender: nodeA, hopCount: 0);
      scheduler.scheduleMessage(msg);

      final peerC = createPeer(nodeC);
      final relayedCount = await scheduler.sweepRelay([peerC]);

      expect(relayedCount, equals(1));
      expect(scheduler.outbox.length, equals(1));

      final forwarded = scheduler.outbox.first;
      expect(forwarded.hopCount, equals(1));
      expect(forwarded.senderNodeId, equals(nodeB));
      expect(forwarded.originNodeId, equals(nodeA));
      expect(forwarded.forwardingHistory.length, equals(1));
      expect(forwarded.forwardingHistory.first.relayNodeId, equals(nodeB));
      expect(forwarded.forwardingHistory.first.hopNumber, equals(1));
    });

    // TEST 2
    test('TEST 2: Max hop limit is enforced', () {
      final atLimitMsg = createTestMessage(hopCount: 5, maxHops: 5);
      final peerC = createPeer(nodeC);

      final input = RelayDecisionInput(
        message: atLimitMsg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.hopLimitReached));
      expect(decision.shouldForward, isFalse);

      // Over absolute max hop limit constant
      final overGlobalLimitMsg = createTestMessage(
        hopCount: AppConstants.maxHopCount,
        maxHops: AppConstants.maxHopCount + 2,
      );
      final input2 = RelayDecisionInput(
        message: overGlobalLimitMsg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );
      final decision2 = decisionEngine.evaluate(input2);
      expect(decision2.outcome, equals(RelayOutcome.hopLimitReached));
      expect(decision2.shouldForward, isFalse);
    });

    // TEST 3
    test('TEST 3: TTL expiration rejects expired bundles', () {
      final now = DateTime.now().toUtc();
      final expiredMsg = MeshMessage(
        messageId: 'RQM-EXPIRED-001',
        originNodeId: nodeA,
        senderNodeId: nodeA,
        destinationNodeId: '*',
        payload: 'Stale alert',
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        ttl: 3600,
      );

      final peerC = createPeer(nodeC);
      final input = RelayDecisionInput(
        message: expiredMsg,
        peer: peerC,
        ttlRemainingSeconds: 0,
        localNodeId: nodeB,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.expired));
      expect(decision.shouldForward, isFalse);

      // Test remaining TTL below minTtlForRelaySeconds
      final lowTtlMsg = createTestMessage(ttl: 20);
      final inputLow = RelayDecisionInput(
        message: lowTtlMsg,
        peer: peerC,
        ttlRemainingSeconds: 15,
        localNodeId: nodeB,
      );
      final decisionLow = decisionEngine.evaluate(inputLow);
      expect(decisionLow.outcome, equals(RelayOutcome.expired));
      expect(decisionLow.shouldForward, isFalse);
    });

    // TEST 4
    test('TEST 4: Duplicate transmission prevention', () {
      final msg = createTestMessage();
      final peerC = createPeer(nodeC);

      // 1. Peer already received via prior forward
      final inputAlreadyForwarded = RelayDecisionInput(
        message: msg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
        peerAlreadyForwarded: true,
      );
      final decision1 = decisionEngine.evaluate(inputAlreadyForwarded);
      expect(decision1.outcome, equals(RelayOutcome.duplicate));
      expect(decision1.shouldForward, isFalse);

      // 2. Peer already acknowledged
      final inputAlreadyAcked = RelayDecisionInput(
        message: msg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
        peerAlreadyAcked: true,
      );
      final decision2 = decisionEngine.evaluate(inputAlreadyAcked);
      expect(decision2.outcome, equals(RelayOutcome.duplicate));
      expect(decision2.shouldForward, isFalse);
    });

    // TEST 5
    test('TEST 5: Forwarding decision engine evaluates correctly', () {
      final msg = createTestMessage(hopCount: 1, maxHops: 5);
      final peerC = createPeer(nodeC, rssi: -65);

      final input = RelayDecisionInput(
        message: msg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.forward));
      expect(decision.shouldForward, isTrue);
      expect(decision.priorityScore, greaterThan(0));
    });

    // TEST 6
    test('TEST 6: Priority ordering in relay queue', () {
      final sosMsg = createTestMessage(
        messageId: 'MSG-SOS',
        priority: MessagePriority.critical,
        messageType: MessageType.sos,
      );
      final hazardMsg = createTestMessage(
        messageId: 'MSG-HAZARD',
        priority: MessagePriority.high,
        messageType: MessageType.hazard,
      );
      final infoMsg = createTestMessage(
        messageId: 'MSG-INFO',
        priority: MessagePriority.normal,
        messageType: MessageType.info,
      );
      final beaconMsg = createTestMessage(
        messageId: 'MSG-BEACON',
        priority: MessagePriority.low,
        messageType: MessageType.status,
      );

      // Schedule in reverse priority order
      scheduler.scheduleMessage(beaconMsg);
      scheduler.scheduleMessage(infoMsg);
      scheduler.scheduleMessage(hazardMsg);
      scheduler.scheduleMessage(sosMsg);

      final outbox = scheduler.outbox;
      expect(outbox.length, equals(4));
      expect(outbox[0].messageId, equals('MSG-SOS'));
      expect(outbox[1].messageId, equals('MSG-HAZARD'));
      expect(outbox[2].messageId, equals('MSG-INFO'));
      expect(outbox[3].messageId, equals('MSG-BEACON'));
    });

    // TEST 7
    test('TEST 7: Forwarding history records each hop', () async {
      final original = createTestMessage(origin: nodeA, sender: nodeA, hopCount: 0);
      scheduler.scheduleMessage(original);

      final peerC = createPeer(nodeC);
      await scheduler.sweepRelay([peerC]);

      final relayedMsg = scheduler.outbox.first;
      expect(relayedMsg.forwardingHistory.length, equals(1));
      expect(relayedMsg.forwardingHistory[0].relayNodeId, equals(nodeB));
      expect(relayedMsg.forwardingHistory[0].hopNumber, equals(1));

      // Simulate subsequent hop relay by node C
      final schedulerC = RelayScheduler(
        decisionEngine: decisionEngine,
        metrics: RelayMetrics(),
        localNodeId: nodeC,
      );
      schedulerC.scheduleMessage(relayedMsg);

      const nodeD = 'RQM-00000000-0000-0000-0000-000000000004';
      final peerD = createPeer(nodeD);
      await schedulerC.sweepRelay([peerD]);

      final secondHopMsg = schedulerC.outbox.first;
      expect(secondHopMsg.hopCount, equals(2));
      expect(secondHopMsg.forwardingHistory.length, equals(2));
      expect(secondHopMsg.forwardingHistory[0].relayNodeId, equals(nodeB));
      expect(secondHopMsg.forwardingHistory[1].relayNodeId, equals(nodeC));
      expect(secondHopMsg.forwardingHistory[1].hopNumber, equals(2));

      schedulerC.dispose();
    });

    // TEST 8
    test('TEST 8: Routing loop prevention', () {
      final history = [
        ForwardingRecord(
          relayNodeId: nodeC,
          forwardedAt: DateTime.now().toUtc(),
          hopNumber: 1,
        ),
      ];

      final msg = createTestMessage(
        origin: nodeA,
        sender: nodeA,
        forwardingHistory: history,
      );

      expect(msg.hasVisitedNode(nodeC), isTrue);
      expect(msg.hasVisitedNode(nodeA), isTrue);

      final peerC = createPeer(nodeC);
      final input = RelayDecisionInput(
        message: msg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.duplicate));
      expect(decision.shouldForward, isFalse);
    });

    // TEST 9
    test('TEST 9: Store-and-forward offline queuing', () async {
      final msg = createTestMessage();
      scheduler.scheduleMessage(msg);

      expect(scheduler.outboxCount, equals(1));
      expect(metrics.messagesStored, equals(1));

      // Sweep with no reachable peers
      final relayed = await scheduler.sweepRelay([]);
      expect(relayed, equals(0));

      // Message must be safely retained in outbox
      expect(scheduler.outboxCount, equals(1));
      expect(metrics.messagesWaiting, equals(1));
      expect(scheduler.outbox.first.messageId, equals(msg.messageId));
    });

    // TEST 10
    test('TEST 10: Opportunistic forwarding on peer encounter', () async {
      final msg = createTestMessage();
      scheduler.scheduleMessage(msg);
      expect(metrics.messagesRelayed, equals(0));

      // Encounter peer C
      final peerC = createPeer(nodeC);
      final relayed = await scheduler.sweepRelay([peerC]);

      expect(relayed, equals(1));
      expect(metrics.messagesRelayed, equals(1));
      expect(metrics.averageHopCount, equals(1.0));
      expect(metrics.maxHopObserved, equals(1));
    });

    // TEST 11
    test('TEST 11: Peer-specific forward history tracking', () async {
      final msg = createTestMessage();
      scheduler.scheduleMessage(msg);

      final peerC = createPeer(nodeC);
      const nodeD = 'RQM-00000000-0000-0000-0000-000000000004';
      final peerD = createPeer(nodeD);

      // Sweep with peer C only
      final sweep1 = await scheduler.sweepRelay([peerC]);
      expect(sweep1, equals(1));

      // Next sweep with peer C again: must NOT re-forward to C
      final sweep2 = await scheduler.sweepRelay([peerC]);
      expect(sweep2, equals(0));
      expect(metrics.duplicatesPrevented, greaterThanOrEqualTo(1));

      // Next sweep with peer D: MUST forward to D
      final sweep3 = await scheduler.sweepRelay([peerD]);
      expect(sweep3, equals(1));
    });

    // TEST 12
    test('TEST 12: Self-origin check prevents re-forwarding to origin', () {
      final msg = createTestMessage(origin: nodeA);
      final peerA = createPeer(nodeA);

      final input = RelayDecisionInput(
        message: msg,
        peer: peerA,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.selfOrigin));
      expect(decision.shouldForward, isFalse);

      // Also cannot forward to local node itself
      final peerSelf = createPeer(nodeB);
      final inputSelf = RelayDecisionInput(
        message: msg,
        peer: peerSelf,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
      );
      final decisionSelf = decisionEngine.evaluate(inputSelf);
      expect(decisionSelf.outcome, equals(RelayOutcome.selfOrigin));
      expect(decisionSelf.shouldForward, isFalse);
    });

    // TEST 13
    test('TEST 13: Relay metrics accurately reflect operations', () async {
      expect(metrics.messagesStored, equals(0));
      expect(metrics.messagesRelayed, equals(0));
      expect(metrics.messagesDelivered, equals(0));
      expect(metrics.averageHopCount, equals(0.0));

      final msg1 = createTestMessage(messageId: 'MSG-001', hopCount: 0);
      final msg2 = createTestMessage(messageId: 'MSG-002', hopCount: 1);

      scheduler.scheduleMessage(msg1);
      scheduler.scheduleMessage(msg2);
      expect(metrics.messagesStored, equals(2));

      final peerC = createPeer(nodeC);
      await scheduler.sweepRelay([peerC]);

      expect(metrics.messagesRelayed, equals(2));
      // Hops relayed: msg1 went 0 -> 1, msg2 went 1 -> 2. Total hops = 1 + 2 = 3. Avg = 1.5.
      expect(metrics.averageHopCount, equals(1.5));
      expect(metrics.maxHopObserved, equals(2));

      scheduler.recordAck('MSG-001', nodeC);
      expect(metrics.messagesDelivered, equals(1));
    });

    // TEST 14
    test('TEST 14: ACK handling updates status and marks delivery', () async {
      final msg = createTestMessage();
      scheduler.scheduleMessage(msg);

      final peerC = createPeer(nodeC);
      await scheduler.sweepRelay([peerC]);

      scheduler.recordAck(msg.messageId, nodeC);
      expect(metrics.messagesDelivered, equals(1));

      // After ACK, peer C must evaluate to duplicate
      final input = RelayDecisionInput(
        message: msg,
        peer: peerC,
        ttlRemainingSeconds: 3600,
        localNodeId: nodeB,
        peerAlreadyAcked: true,
      );

      final decision = decisionEngine.evaluate(input);
      expect(decision.outcome, equals(RelayOutcome.duplicate));
      expect(decision.shouldForward, isFalse);
    });
  });
}
