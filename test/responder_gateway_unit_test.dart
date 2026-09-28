import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/features/gateway/gateway_inbox_service.dart';
import 'package:resqmesh/features/identity/models/node_role.dart';
import 'package:resqmesh/features/mesh/models/emergency_type.dart';
import 'package:resqmesh/features/mesh/models/mesh_message.dart';
import 'package:resqmesh/features/mesh/models/peer_node.dart';
import 'package:resqmesh/features/responder/emergency_handoff_service.dart';
import 'package:resqmesh/features/responder/responder_service.dart';
import 'package:resqmesh/features/routing/config/routing_config.dart';
import 'package:resqmesh/features/routing/metrics/routing_research_metrics.dart';
import 'package:resqmesh/features/routing/scoring/peer_scoring_model.dart';
import 'package:resqmesh/features/storage/repositories/dtn_message_repository.dart';
import 'package:resqmesh/features/transport/codecs/ble_message_wire_format.dart';
import 'package:resqmesh/features/transport/models/ble_packet.dart';

/// In-memory mock DTN repository for unit testing ResponderService and GatewayInboxService.
/// Implements [DtnMessageRepository] exactly as specified by the abstract interface.
class MockDtnMessageRepository implements DtnMessageRepository {
  final Map<String, MeshMessage> _storage = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> createMessage(MeshMessage message) async {
    _storage[message.messageId] = message;
  }

  @override
  Future<MeshMessage?> getMessageById(String messageId) async {
    return _storage[messageId];
  }

  @override
  Future<List<MeshMessage>> getAllMessages() async {
    return _storage.values.toList();
  }

  @override
  Future<List<MeshMessage>> getMessagesByStatus(MessageStatus status) async {
    return _storage.values.where((m) => m.status == status).toList();
  }

  @override
  Future<List<MeshMessage>> getMessagesByPriority(MessagePriority priority) async {
    return _storage.values.where((m) => m.priority == priority).toList();
  }

  @override
  Future<List<MeshMessage>> getActiveMessages({DateTime? now}) async {
    return _storage.values.where((m) => !m.isExpired()).toList();
  }

  @override
  Future<List<MeshMessage>> getExpiredMessages({DateTime? now}) async {
    return _storage.values.where((m) => m.isExpired()).toList();
  }

  @override
  Future<void> updateMessage(MeshMessage message) async {
    if (_storage.containsKey(message.messageId)) {
      _storage[message.messageId] = message;
    }
  }

  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final msg = _storage[messageId];
    if (msg != null) {
      _storage[messageId] = msg.copyWith(status: status);
    }
  }

  @override
  Future<void> incrementRetryCount(String messageId) async {}

  @override
  Future<void> deleteMessage(String messageId) async {
    _storage.remove(messageId);
  }

  @override
  Future<int> deleteExpiredMessages({DateTime? now}) async {
    final toRemove = _storage.values
        .where((m) => m.isExpired())
        .map((m) => m.messageId)
        .toList();
    for (final id in toRemove) {
      _storage.remove(id);
    }
    return toRemove.length;
  }

  @override
  Future<int> getMessageCount() async {
    return _storage.length;
  }

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nodeA = 'RQM-00000000-0000-0000-0000-000000000001';
  const nodeB = 'RQM-00000000-0000-0000-0000-000000000002';
  const responderNode = 'RQM-00000000-0000-0000-0000-000000000099';
  const gatewayNode = 'RQM-00000000-0000-0000-0000-000000000088';

  group('Step 8: Responder & Gateway Integration Tests', () {
    test('TEST 1: EmergencyType enum parses strings and classifies urgency correctly', () {
      expect(EmergencyType.fromString('sos'), equals(EmergencyType.sos));
      expect(EmergencyType.fromString('medical'), equals(EmergencyType.medical));
      expect(EmergencyType.fromString('fire'), equals(EmergencyType.fire));
      expect(EmergencyType.fromString('trapped'), equals(EmergencyType.trapped));
      expect(EmergencyType.fromString('missingPerson'), equals(EmergencyType.missingPerson));
      expect(EmergencyType.fromString('hazard'), equals(EmergencyType.hazard));
      expect(EmergencyType.fromString('unknown_val'), equals(EmergencyType.info));
      expect(EmergencyType.fromString(null), equals(EmergencyType.info));

      expect(EmergencyType.sos.isHighUrgency, isTrue);
      expect(EmergencyType.medical.isHighUrgency, isTrue);
      expect(EmergencyType.fire.isHighUrgency, isTrue);
      expect(EmergencyType.trapped.isHighUrgency, isTrue);
      expect(EmergencyType.hazard.isHighUrgency, isFalse);
      expect(EmergencyType.info.isHighUrgency, isFalse);
    });

    test('TEST 2: AckType enum distinguishes PEER_ACK, RESPONDER_ACK, and GATEWAY_ACK', () {
      expect(AckType.peerAck.displayName, equals('PEER ACK'));
      expect(AckType.responderAck.displayName, equals('RESPONDER ACK'));
      expect(AckType.gatewayAck.displayName, equals('GATEWAY ACK'));

      expect(AckType.fromString('peerAck'), equals(AckType.peerAck));
      expect(AckType.fromString('responderAck'), equals(AckType.responderAck));
      expect(AckType.fromString('gatewayAck'), equals(AckType.gatewayAck));
      expect(AckType.fromString(null), equals(AckType.peerAck));
    });

    test('TEST 3: MeshMessage correctly models emergencyType and ackType serialization', () {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-EMERG-001',
        originNodeId: nodeA,
        senderNodeId: nodeA,
        destinationNodeId: '*',
        payload: 'Trapped on 2nd floor',
        emergencyType: EmergencyType.trapped,
        priority: MessagePriority.critical,
        ackType: AckType.responderAck,
      );

      expect(msg.emergencyType, equals(EmergencyType.trapped));
      expect(msg.ackType, equals(AckType.responderAck));
      expect(msg.isSos, isTrue);

      final map = msg.toMap();
      expect(map['emergencyType'], equals('trapped'));
      expect(map['ackType'], equals('responderAck'));

      final restored = MeshMessage.fromMap(map);
      expect(restored.emergencyType, equals(EmergencyType.trapped));
      expect(restored.ackType, equals(AckType.responderAck));
      expect(restored.payload, equals('Trapped on 2nd floor'));
    });

    test('TEST 4: MeshMessage database serialization handles emergency_type and ack_type', () {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-DB-001',
        originNodeId: nodeA,
        payload: 'Chemical hazard leak',
        emergencyType: EmergencyType.hazard,
        priority: MessagePriority.high,
      );

      final dbMap = msg.toDatabaseMap();
      expect(dbMap['emergency_type'], equals('hazard'));
      expect(dbMap['ack_type'], isNull);

      final restored = MeshMessage.fromDatabaseMap(dbMap);
      expect(restored.emergencyType, equals(EmergencyType.hazard));
      expect(restored.ackType, isNull);
    });

    test('TEST 5: BleMessageWireFormat encodes and decodes emergencyType and ackType on BLE wire', () {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-WIRE-001',
        originNodeId: nodeA,
        payload: 'Fire reported in warehouse',
        emergencyType: EmergencyType.fire,
        priority: MessagePriority.critical,
        ackType: AckType.gatewayAck,
      );

      final encoded = BleMessageWireFormat.encode(msg);
      final decoded = BleMessageWireFormat.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.messageId, equals(msg.messageId));
      expect(decoded.emergencyType, equals(EmergencyType.fire));
      expect(decoded.ackType, equals(AckType.gatewayAck));
      expect(decoded.payload, equals('Fire reported in warehouse'));
    });

    test('TEST 6: BleAckPacket supports differentiated AckType semantics', () {
      final ack = BleAckPacket(
        messageId: 'RQM-MSG-001',
        ackNodeId: responderNode,
        ackType: AckType.responderAck,
      );

      expect(ack.ackType, equals(AckType.responderAck));
      expect(ack.toString(), contains('RESPONDER ACK'));
    });

    test('TEST 7: PeerScoringModel grants responderEmergencyBonus (+25.0) to responder peers for emergency messages', () {
      const scoringModel = PeerScoringModel(config: RoutingConfig());
      final now = DateTime.now().toUtc();

      final emergencyMsg = MeshMessage(
        messageId: 'RQM-MSG-SOS-001',
        originNodeId: nodeA,
        payload: 'Emergency SOS alert',
        emergencyType: EmergencyType.sos,
        priority: MessagePriority.critical,
      );

      final civilianPeer = PeerNode(
        nodeId: nodeB,
        displayName: 'Civilian-Node',
        rssi: -60,
        lastSeen: now,
        role: NodeRole.civilian,
      );

      final responderPeer = PeerNode(
        nodeId: responderNode,
        displayName: 'Responder-Node',
        rssi: -60,
        lastSeen: now,
        role: NodeRole.responder,
      );

      final scoreCiv = scoringModel.scorePeer(
        peer: civilianPeer,
        message: emergencyMsg,
        localNodeId: 'LOCAL-NODE',
      );

      final scoreResp = scoringModel.scorePeer(
        peer: responderPeer,
        message: emergencyMsg,
        localNodeId: 'LOCAL-NODE',
      );

      expect(scoreCiv.emergencyRoleBonus, equals(0.0));
      expect(scoreResp.emergencyRoleBonus, equals(25.0));
      expect(scoreResp.totalScore, greaterThan(scoreCiv.totalScore));
    });

    test('TEST 8: PeerScoringModel grants gatewayEmergencyBonus (+20.0) to gateway peers for emergency messages', () {
      const scoringModel = PeerScoringModel(config: RoutingConfig());
      final now = DateTime.now().toUtc();

      final emergencyMsg = MeshMessage(
        messageId: 'RQM-MSG-MED-001',
        originNodeId: nodeA,
        payload: 'Urgent medical assistance required',
        emergencyType: EmergencyType.medical,
        priority: MessagePriority.critical,
      );

      final gatewayPeer = PeerNode(
        nodeId: gatewayNode,
        displayName: 'Gateway-Node',
        rssi: -60,
        lastSeen: now,
        role: NodeRole.gateway,
        isGateway: true,
      );

      final score = scoringModel.scorePeer(
        peer: gatewayPeer,
        message: emergencyMsg,
        localNodeId: 'LOCAL-NODE',
      );

      expect(score.emergencyRoleBonus, equals(20.0));
    });

    test('TEST 9: PeerScoringModel does NOT grant emergency bonuses for normal INFO messages', () {
      const scoringModel = PeerScoringModel(config: RoutingConfig());
      final now = DateTime.now().toUtc();

      final normalMsg = MeshMessage(
        messageId: 'RQM-MSG-INFO-001',
        originNodeId: nodeA,
        payload: 'General weather update',
        emergencyType: EmergencyType.info,
        priority: MessagePriority.normal,
      );

      final responderPeer = PeerNode(
        nodeId: responderNode,
        displayName: 'Responder-Node',
        rssi: -60,
        lastSeen: now,
        role: NodeRole.responder,
      );

      final score = scoringModel.scorePeer(
        peer: responderPeer,
        message: normalMsg,
        localNodeId: 'LOCAL-NODE',
      );

      expect(score.emergencyRoleBonus, equals(0.0));
    });

    test('TEST 10: LocalEmergencyHandoffService marks handoff ready without claiming external connection', () async {
      final handoffService = LocalEmergencyHandoffService();
      final msg = MeshMessage(
        messageId: 'RQM-MSG-HANDOFF-001',
        originNodeId: nodeA,
        payload: 'Rescue needed',
        emergencyType: EmergencyType.sos,
      );

      expect(handoffService.getHandoffStatus(msg.messageId), equals(HandoffStatus.notStarted));

      final success = await handoffService.prepareHandoff(msg);
      expect(success, isTrue);
      expect(handoffService.getHandoffStatus(msg.messageId), equals(HandoffStatus.readyForHandoff));

      final records = handoffService.getHandoffRecords();
      expect(records.length, equals(1));
      expect(records.first.notes, contains('External dispatch NOT connected'));

      handoffService.markExternalUnavailable(msg.messageId);
      expect(handoffService.getHandoffStatus(msg.messageId), equals(HandoffStatus.externalNotConnected));
    });

    test('TEST 11: ResponderService ingests emergencies and counts totals and high urgency', () {
      final repo = MockDtnMessageRepository();
      final service = ResponderService(repository: repo);

      final msg1 = MeshMessage(
        messageId: 'MSG-001',
        originNodeId: nodeA,
        payload: 'Fire reported',
        emergencyType: EmergencyType.fire,
        priority: MessagePriority.critical,
      );

      final msg2 = MeshMessage(
        messageId: 'MSG-002',
        originNodeId: nodeB,
        payload: 'Flooded road observed',
        emergencyType: EmergencyType.hazard,
        priority: MessagePriority.normal,
      );

      service.ingestEmergency(msg1);
      service.ingestEmergency(msg2);

      expect(service.totalCount, equals(2));
      expect(service.activeEmergencyCount, equals(2));
      expect(service.highUrgencyCount, equals(1));
      expect(service.acknowledgedCount, equals(0));
    });

    test('TEST 12: ResponderService triage filtering by EmergencyType and ResponderTriageState', () {
      final repo = MockDtnMessageRepository();
      final service = ResponderService(repository: repo);

      final msgSos = MeshMessage(
        messageId: 'SOS-001',
        originNodeId: nodeA,
        payload: 'SOS call',
        emergencyType: EmergencyType.sos,
        priority: MessagePriority.critical,
      );

      final msgMed = MeshMessage(
        messageId: 'MED-001',
        originNodeId: nodeB,
        payload: 'Need doctor',
        emergencyType: EmergencyType.medical,
        priority: MessagePriority.critical,
      );

      service.ingestEmergency(msgSos);
      service.ingestEmergency(msgMed);

      expect(service.filteredEmergencies.length, equals(2));

      service.setFilterType(EmergencyType.medical);
      expect(service.filteredEmergencies.length, equals(1));
      expect(service.filteredEmergencies.first.message.emergencyType, equals(EmergencyType.medical));

      service.clearFilters();
      expect(service.filteredEmergencies.length, equals(2));
    });

    test('TEST 13: ResponderService acknowledges emergency and records notes', () {
      final repo = MockDtnMessageRepository();
      final service = ResponderService(repository: repo);

      final msg = MeshMessage(
        messageId: 'EMERG-ACK-001',
        originNodeId: nodeA,
        payload: 'Trapped under fallen wall',
        emergencyType: EmergencyType.trapped,
      );

      service.ingestEmergency(msg);
      expect(service.acknowledgedCount, equals(0));

      service.acknowledgeEmergency(msg.messageId, notes: 'Engine unit 4 dispatched');

      expect(service.acknowledgedCount, equals(1));
      final entry = service.allEmergencies.firstWhere((e) => e.message.messageId == msg.messageId);
      expect(entry.triageState, equals(ResponderTriageState.acknowledged));
      expect(entry.acknowledgedAt, isNotNull);
      expect(entry.responderNotes, equals('Engine unit 4 dispatched'));
    });

    test('TEST 14: GatewayInboxService ingests bundles and integrates with EmergencyHandoffService', () {
      final repo = MockDtnMessageRepository();
      final handoff = LocalEmergencyHandoffService();
      final gateway = GatewayInboxService(repository: repo, handoffService: handoff);

      final msg = MeshMessage(
        messageId: 'GW-001',
        originNodeId: nodeA,
        payload: 'General emergency situation',
        emergencyType: EmergencyType.generalEmergency,
      );

      gateway.ingestMessage(msg);

      expect(gateway.totalCount, equals(1));
      expect(gateway.newCount, equals(1));
      expect(handoff.getHandoffStatus(msg.messageId), equals(HandoffStatus.readyForHandoff));

      gateway.updateState(msg.messageId, GatewayMessageState.inReview, notes: 'Reviewing triage');
      expect(gateway.newCount, equals(0));
      expect(gateway.inReviewCount, equals(1));

      gateway.updateState(msg.messageId, GatewayMessageState.resolved);
      expect(gateway.resolvedCount, equals(1));
    });

    test('TEST 15: RoutingResearchMetrics records emergency-specific telemetry', () {
      final metrics = RoutingResearchMetrics();

      metrics.recordEmergencyCreated();
      metrics.recordEmergencyCreated();
      metrics.recordEmergencyReceivedByResponder();
      metrics.recordGatewayReceipt();
      metrics.recordResponderAck();
      metrics.recordEmergencyRelayed();
      metrics.recordEmergencyExpired();
      metrics.recordEmergencyDeliveryDelay(1200);

      expect(metrics.emergenciesCreated, equals(2));
      expect(metrics.emergenciesReceivedByResponder, equals(1));
      expect(metrics.gatewayReceipts, equals(1));
      expect(metrics.responderAcknowledgements, equals(1));
      expect(metrics.emergencyRelayCount, equals(1));
      expect(metrics.emergencyExpirationCount, equals(1));
      expect(metrics.averageEmergencyDeliveryDelayMs, equals(1200.0));

      final map = metrics.toMap();
      expect(map['emergenciesCreated'], equals(2));
      expect(map['responderAcknowledgements'], equals(1));

      metrics.reset();
      expect(metrics.emergenciesCreated, equals(0));
      expect(metrics.responderAcknowledgements, equals(0));
    });
  });
}
