import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/features/decision/basic_decision_engine.dart';
import 'package:resqmesh/features/decision/decision_engine_interface.dart';
import 'package:resqmesh/features/discovery/ble_discovery_stub.dart';
import 'package:resqmesh/features/mesh/message_manager.dart';
import 'package:resqmesh/features/mesh/models/mesh_message.dart';
import 'package:resqmesh/features/routing/dtn_router_stub.dart';

void main() {
  group('ResQMesh Step 1 - Core Path Architecture Unit Tests', () {
    test('Decision Engine prioritizes SOS and handles hop limits correctly', () {
      final engine = BasicDecisionEngine();

      final sosMessage = MeshMessage(
        id: 'msg-1',
        senderId: 'node-A',
        recipientId: '*',
        content: 'SOS Test',
        timestamp: DateTime.now(),
        priority: MessagePriority.critical,
      );

      final normalMessage = MeshMessage(
        id: 'msg-2',
        senderId: 'node-A',
        recipientId: '*',
        content: 'Normal Test',
        timestamp: DateTime.now(),
        priority: MessagePriority.normal,
        hopCount: 1,
        maxHops: 5,
      );

      final staleMessage = MeshMessage(
        id: 'msg-3',
        senderId: 'node-A',
        recipientId: '*',
        content: 'Stale Test',
        timestamp: DateTime.now(),
        priority: MessagePriority.normal,
        hopCount: 5,
        maxHops: 5,
      );

      expect(engine.evaluateMessage(sosMessage), equals(DecisionOutcome.acceptImmediately));
      expect(engine.evaluateMessage(normalMessage), equals(DecisionOutcome.queueStoreAndForward));
      expect(engine.evaluateMessage(staleMessage), equals(DecisionOutcome.dropStaleOrDuplicated));
    });

    test('BleDiscoveryStub strictly does not create fake peers', () {
      final stub = BleDiscoveryStub();
      expect(stub.currentPeers, isEmpty);
      expect(stub.isDiscovering, isFalse);
    });

    test('DtnRouterStub retains messages in store-and-forward queue when no peers exist', () async {
      final router = DtnRouterStub();
      final msg = MeshMessage(
        id: 'msg-offline',
        senderId: 'node-A',
        recipientId: '*',
        content: 'Testing offline store-and-forward',
        timestamp: DateTime.now(),
      );

      final dispatched = await router.routeMessage(msg, const []);
      expect(dispatched, isFalse);

      final queued = await router.getQueuedBundles();
      expect(queued.length, equals(1));
      expect(queued.first.status, equals(MessageStatus.queued));
    });

    test('MessageManager coordinates core path pipeline offline', () async {
      final decisionEngine = BasicDecisionEngine();
      final dtnRouter = DtnRouterStub();
      final discoveryService = BleDiscoveryStub();

      final manager = MessageManager(
        decisionEngine: decisionEngine,
        dtnRouter: dtnRouter,
        discoveryService: discoveryService,
        localNodeId: 'node-test-001',
      );

      expect(manager.localNodeId, equals('node-test-001'));
      expect(manager.activePeerCount, equals(0));
      expect(manager.messages, isEmpty);

      // Send emergency SOS
      final dispatchedMsg = await manager.sendEmergencySos(details: 'Need medical kit');

      expect(dispatchedMsg.isSos, isTrue);
      expect(dispatchedMsg.recipientId, equals('*'));
      expect(dispatchedMsg.status, equals(MessageStatus.queued));
      expect(manager.messages.length, equals(1));
      expect(manager.queuedMessageCount, equals(1));

      // Verify DTN Router received and stored bundle
      final queuedBundles = await dtnRouter.getQueuedBundles();
      expect(queuedBundles.length, equals(1));
      expect(queuedBundles.first.id, equals(dispatchedMsg.id));
    });
  });
}
