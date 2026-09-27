import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:resqmesh/features/decision/basic_decision_engine.dart';
import 'package:resqmesh/features/discovery/ble_discovery_stub.dart';
import 'package:resqmesh/features/identity/models/node_role.dart';
import 'package:resqmesh/features/identity/repositories/in_memory_node_identity_repository.dart';
import 'package:resqmesh/features/identity/services/node_identity_service.dart';
import 'package:resqmesh/features/mesh/message_manager.dart';
import 'package:resqmesh/features/mesh/models/mesh_message.dart';
import 'package:resqmesh/features/routing/dtn_router_stub.dart';
import 'package:resqmesh/features/storage/exceptions/storage_exceptions.dart';
import 'package:resqmesh/features/storage/repositories/sqlite_dtn_message_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI database factory for desktop test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;
  late SqliteDtnMessageRepository repository;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('rqm_dtn_test_');
    dbPath = p.join(tempDir.path, 'test_resqmesh_dtn.db');
    repository = SqliteDtnMessageRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    await repository.init();
  });

  tearDown(() async {
    if (repository.isOpen) {
      await repository.close();
    }
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('ResQMesh Step 3 — Persistent SQLite Message & Bundle Storage Tests', () {
    // TEST 1
    test('TEST 1: Database initializes successfully', () async {
      expect(repository.isOpen, isTrue);
      final count = await repository.getMessageCount();
      expect(count, equals(0));
    });

    // TEST 2
    test('TEST 2: Message can be inserted', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-11111111-1111-1111-1111-111111111111',
        originNodeId: 'RQM-NODE-ORIGIN-A',
        senderNodeId: 'RQM-NODE-SENDER-A',
        destinationNodeId: '*',
        messageType: MessageType.sos,
        priority: MessagePriority.critical,
        payload: 'EMERGENCY: Trapped in collapsed structure',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 12)),
        ttl: 43200,
        hopCount: 0,
        maxHops: 5,
        status: MessageStatus.stored,
        createdByRole: NodeRole.civilian,
      );

      await repository.createMessage(msg);
      final count = await repository.getMessageCount();
      expect(count, equals(1));
    });

    // TEST 3
    test('TEST 3: Inserted message can be retrieved', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-22222222-2222-2222-2222-222222222222',
        originNodeId: 'RQM-NODE-ALPHA',
        senderNodeId: 'RQM-NODE-ALPHA',
        destinationNodeId: 'RQM-NODE-BRAVO',
        messageType: MessageType.hazard,
        priority: MessagePriority.high,
        payload: 'Flash flood approaching bridge',
        createdAt: DateTime.utc(2026, 9, 27, 10, 0, 0),
        expiresAt: DateTime.utc(2026, 9, 28, 10, 0, 0),
        ttl: 86400,
        hopCount: 1,
        maxHops: 4,
        status: MessageStatus.stored,
        retryCount: 0,
        createdByRole: NodeRole.responder,
      );

      await repository.createMessage(msg);
      final retrieved = await repository.getMessageById(msg.messageId);

      expect(retrieved, isNotNull);
      expect(retrieved!.messageId, equals(msg.messageId));
      expect(retrieved.payload, equals('Flash flood approaching bridge'));
      expect(retrieved.messageType, equals(MessageType.hazard));
      expect(retrieved.priority, equals(MessagePriority.high));
      expect(retrieved.createdByRole, equals(NodeRole.responder));
    });

    // TEST 4
    test('TEST 4: Message survives database reinitialization', () async {
      final msgId = 'RQM-MSG-33333333-3333-3333-3333-333333333333';
      final msg = MeshMessage(
        messageId: msgId,
        originNodeId: 'RQM-ORIGIN-NODE',
        senderNodeId: 'RQM-ORIGIN-NODE',
        payload: 'Persistent across database restarts',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
      );

      await repository.createMessage(msg);
      await repository.close();
      expect(repository.isOpen, isFalse);

      // Reinitialize a new repository instance pointing to the exact same file
      final reloadedRepo = SqliteDtnMessageRepository(
        databaseFactory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      await reloadedRepo.init();

      final reloaded = await reloadedRepo.getMessageById(msgId);
      expect(reloaded, isNotNull);
      expect(reloaded!.payload, equals('Persistent across database restarts'));
      await reloadedRepo.close();
    });

    // TEST 5
    test('TEST 5: Message ID is unique', () async {
      final msg1 = MeshMessage(
        messageId: 'RQM-MSG-UNIQUE-001',
        originNodeId: 'NODE-1',
        senderNodeId: 'NODE-1',
        payload: 'First unique bundle',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final msg2 = MeshMessage(
        messageId: 'RQM-MSG-UNIQUE-002',
        originNodeId: 'NODE-1',
        senderNodeId: 'NODE-1',
        payload: 'Second unique bundle',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await repository.createMessage(msg1);
      await repository.createMessage(msg2);

      final count = await repository.getMessageCount();
      expect(count, equals(2));
      expect(msg1.messageId, isNot(equals(msg2.messageId)));
    });

    // TEST 6
    test('TEST 6: Duplicate message IDs are rejected', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-DUP-CHECK',
        originNodeId: 'NODE-A',
        senderNodeId: 'NODE-A',
        payload: 'Duplicate insertion attempt',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await repository.createMessage(msg);

      // Attempting to insert the exact same message ID must throw DuplicateMessageException
      await expectLater(
        () => repository.createMessage(msg),
        throwsA(isA<DuplicateMessageException>()),
      );

      final count = await repository.getMessageCount();
      expect(count, equals(1));
    });

    // TEST 7
    test('TEST 7: originNodeId is preserved', () async {
      const originalOrigin = 'RQM-ORIGIN-SURVIVOR-44';
      const relayedSender = 'RQM-RELAY-ROUTER-99';

      final msg = MeshMessage(
        messageId: 'RQM-MSG-ORIGIN-TEST',
        originNodeId: originalOrigin,
        senderNodeId: relayedSender,
        payload: 'Relayed SOS bundle',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
      );

      await repository.createMessage(msg);
      final retrieved = await repository.getMessageById('RQM-MSG-ORIGIN-TEST');

      expect(retrieved!.originNodeId, equals(originalOrigin));
      expect(retrieved.originNodeId, isNot(equals(retrieved.senderNodeId)));
    });

    // TEST 8
    test('TEST 8: senderNodeId is stored correctly', () async {
      const sender = 'RQM-SENDER-PARAMEDIC-01';

      final msg = MeshMessage(
        messageId: 'RQM-MSG-SENDER-TEST',
        originNodeId: 'RQM-ORIGIN-CIVILIAN-02',
        senderNodeId: sender,
        payload: 'Status report',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      );

      await repository.createMessage(msg);
      final retrieved = await repository.getMessageById('RQM-MSG-SENDER-TEST');

      expect(retrieved!.senderNodeId, equals(sender));
    });

    // TEST 9
    test('TEST 9: Priority is stored correctly', () async {
      for (final prio in MessagePriority.values) {
        final msg = MeshMessage(
          messageId: 'RQM-MSG-PRIO-${prio.name}',
          originNodeId: 'NODE-PRIO',
          senderNodeId: 'NODE-PRIO',
          priority: prio,
          payload: 'Priority test: ${prio.name}',
          createdAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
        await repository.createMessage(msg);
      }

      final criticals = await repository.getMessagesByPriority(MessagePriority.critical);
      expect(criticals.length, equals(1));
      expect(criticals.first.priority, equals(MessagePriority.critical));

      final highs = await repository.getMessagesByPriority(MessagePriority.high);
      expect(highs.length, equals(1));
      expect(highs.first.priority, equals(MessagePriority.high));
    });

    // TEST 10
    test('TEST 10: Message type is stored correctly', () async {
      for (final type in MessageType.values) {
        final msg = MeshMessage(
          messageId: 'RQM-MSG-TYPE-${type.name}',
          originNodeId: 'NODE-TYPE',
          senderNodeId: 'NODE-TYPE',
          messageType: type,
          payload: 'Type test: ${type.name}',
          createdAt: DateTime.now().toUtc(),
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );
        await repository.createMessage(msg);
      }

      final all = await repository.getAllMessages();
      expect(all.length, equals(MessageType.values.length));

      final sosMsg = await repository.getMessageById('RQM-MSG-TYPE-sos');
      expect(sosMsg!.messageType, equals(MessageType.sos));

      final hazardMsg = await repository.getMessageById('RQM-MSG-TYPE-hazard');
      expect(hazardMsg!.messageType, equals(MessageType.hazard));
    });

    // TEST 11
    test('TEST 11: TTL/expiresAt are persisted', () async {
      final now = DateTime.utc(2026, 9, 27, 12, 0, 0);
      const ttlSeconds = 3600;
      final expectedExpiry = now.add(const Duration(seconds: ttlSeconds));

      final msg = MeshMessage(
        messageId: 'RQM-MSG-TTL-TEST',
        originNodeId: 'NODE-TTL',
        senderNodeId: 'NODE-TTL',
        payload: 'Expiring message',
        createdAt: now,
        expiresAt: expectedExpiry,
        ttl: ttlSeconds,
      );

      await repository.createMessage(msg);
      final retrieved = await repository.getMessageById('RQM-MSG-TTL-TEST');

      expect(retrieved!.ttl, equals(ttlSeconds));
      expect(retrieved.createdAt.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
      expect(retrieved.expiresAt.millisecondsSinceEpoch, equals(expectedExpiry.millisecondsSinceEpoch));
    });

    // TEST 12
    test('TEST 12: Hop count is persisted', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-HOPS',
        originNodeId: 'NODE-HOPS',
        senderNodeId: 'NODE-HOPS',
        payload: 'Multi-hop relay counter',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        hopCount: 3,
        maxHops: 7,
      );

      await repository.createMessage(msg);
      final retrieved = await repository.getMessageById('RQM-MSG-HOPS');

      expect(retrieved!.hopCount, equals(3));
      expect(retrieved.maxHops, equals(7));
    });

    // TEST 13
    test('TEST 13: Message status can be updated', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-STATUS-TEST',
        originNodeId: 'NODE-STATUS',
        senderNodeId: 'NODE-STATUS',
        payload: 'Status update lifecycle',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        status: MessageStatus.stored,
      );

      await repository.createMessage(msg);
      await repository.updateMessageStatus(msg.messageId, MessageStatus.forwarded);

      final retrieved = await repository.getMessageById(msg.messageId);
      expect(retrieved!.status, equals(MessageStatus.forwarded));
    });

    // TEST 14
    test('TEST 14: Retry count can be incremented', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-RETRY-TEST',
        originNodeId: 'NODE-RETRY',
        senderNodeId: 'NODE-RETRY',
        payload: 'Retry counter testing',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        retryCount: 0,
      );

      await repository.createMessage(msg);
      await repository.incrementRetryCount(msg.messageId);
      await repository.incrementRetryCount(msg.messageId);

      final retrieved = await repository.getMessageById(msg.messageId);
      expect(retrieved!.retryCount, equals(2));
    });

    // TEST 15
    test('TEST 15: Expired messages can be queried', () async {
      final now = DateTime.utc(2026, 9, 27, 12, 0, 0);

      // Expired bundle
      final expiredMsg = MeshMessage(
        messageId: 'RQM-EXPIRED-01',
        originNodeId: 'NODE-EXP',
        senderNodeId: 'NODE-EXP',
        payload: 'Already expired bundle',
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.subtract(const Duration(hours: 1)),
        ttl: 3600,
      );

      // Active bundle
      final activeMsg = MeshMessage(
        messageId: 'RQM-ACTIVE-01',
        originNodeId: 'NODE-EXP',
        senderNodeId: 'NODE-EXP',
        payload: 'Active bundle',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        ttl: 7200,
      );

      await repository.createMessage(expiredMsg);
      await repository.createMessage(activeMsg);

      final expiredList = await repository.getExpiredMessages(now: now);
      expect(expiredList.length, equals(1));
      expect(expiredList.first.messageId, equals('RQM-EXPIRED-01'));
    });

    // TEST 16
    test('TEST 16: Active messages can be queried', () async {
      final now = DateTime.utc(2026, 9, 27, 12, 0, 0);

      final expiredMsg = MeshMessage(
        messageId: 'RQM-EXP-02',
        originNodeId: 'NODE-ACT',
        senderNodeId: 'NODE-ACT',
        payload: 'Expired',
        createdAt: now.subtract(const Duration(hours: 4)),
        expiresAt: now.subtract(const Duration(hours: 2)),
      );

      final activeMsg = MeshMessage(
        messageId: 'RQM-ACT-02',
        originNodeId: 'NODE-ACT',
        senderNodeId: 'NODE-ACT',
        payload: 'Active still valid',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
      );

      await repository.createMessage(expiredMsg);
      await repository.createMessage(activeMsg);

      final activeList = await repository.getActiveMessages(now: now);
      expect(activeList.length, equals(1));
      expect(activeList.first.messageId, equals('RQM-ACT-02'));
    });

    // TEST 17
    test('TEST 17: Messages can be deleted', () async {
      final msg = MeshMessage(
        messageId: 'RQM-MSG-DELETE',
        originNodeId: 'NODE-DEL',
        senderNodeId: 'NODE-DEL',
        payload: 'To be deleted',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );

      await repository.createMessage(msg);
      expect(await repository.getMessageCount(), equals(1));

      await repository.deleteMessage(msg.messageId);
      expect(await repository.getMessageCount(), equals(0));
      expect(await repository.getMessageById(msg.messageId), isNull);
    });

    // TEST 18
    test('TEST 18: Expired messages can be deleted explicitly', () async {
      final now = DateTime.utc(2026, 9, 27, 12, 0, 0);

      final exp1 = MeshMessage(
        messageId: 'RQM-PURGE-1',
        originNodeId: 'NODE-PURGE',
        senderNodeId: 'NODE-PURGE',
        payload: 'Expired 1',
        createdAt: now.subtract(const Duration(hours: 5)),
        expiresAt: now.subtract(const Duration(hours: 3)),
      );

      final exp2 = MeshMessage(
        messageId: 'RQM-PURGE-2',
        originNodeId: 'NODE-PURGE',
        senderNodeId: 'NODE-PURGE',
        payload: 'Expired 2',
        createdAt: now.subtract(const Duration(hours: 4)),
        expiresAt: now.subtract(const Duration(hours: 1)),
      );

      final active = MeshMessage(
        messageId: 'RQM-PURGE-ACTIVE',
        originNodeId: 'NODE-PURGE',
        senderNodeId: 'NODE-PURGE',
        payload: 'Keep this active bundle',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 5)),
      );

      await repository.createMessage(exp1);
      await repository.createMessage(exp2);
      await repository.createMessage(active);
      expect(await repository.getMessageCount(), equals(3));

      final deletedCount = await repository.deleteExpiredMessages(now: now);
      expect(deletedCount, equals(2));
      expect(await repository.getMessageCount(), equals(1));
      expect((await repository.getMessageById('RQM-PURGE-ACTIVE')), isNotNull);
    });

    // TEST 19
    test('TEST 19: MessageManager creates messages using the current Node ID', () async {
      final identityRepo = InMemoryNodeIdentityRepository();
      final identityService = NodeIdentityService(repository: identityRepo);
      final identity = await identityService.initialize();

      final manager = MessageManager(
        decisionEngine: BasicDecisionEngine(),
        dtnRouter: DtnRouterStub(),
        discoveryService: BleDiscoveryStub(),
        identityService: identityService,
        messageRepository: repository,
      );
      await manager.initializeStorage();

      final sentMessage = await manager.sendMessage(
        content: 'Testing Node ID attribution in DTN storage',
        messageType: MessageType.sos,
        priority: MessagePriority.critical,
      );

      expect(sentMessage.originNodeId, equals(identity.nodeId));
      expect(sentMessage.senderNodeId, equals(identity.nodeId));
      expect(sentMessage.messageId.startsWith('RQM-MSG-'), isTrue);

      // Verify it was stored in SQLite
      final fromDb = await repository.getMessageById(sentMessage.messageId);
      expect(fromDb, isNotNull);
      expect(fromDb!.originNodeId, equals(identity.nodeId));
      expect(fromDb.senderNodeId, equals(identity.nodeId));
      expect(fromDb.payload, equals('Testing Node ID attribution in DTN storage'));
    });

    // TEST 20
    test('TEST 20: Database works without Internet/network access', () async {
      // Local SQLite operates strictly on on-disk relational tables without network calls
      expect(repository.isOpen, isTrue);

      final offlineMsg = MeshMessage(
        messageId: 'RQM-OFFLINE-TEST',
        originNodeId: 'RQM-OFFLINE-NODE',
        senderNodeId: 'RQM-OFFLINE-NODE',
        payload: 'Pure offline store-and-forward',
        createdAt: DateTime.now().toUtc(),
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
      );

      await repository.createMessage(offlineMsg);
      final retrieved = await repository.getMessageById('RQM-OFFLINE-TEST');
      expect(retrieved, isNotNull);
      expect(retrieved!.payload, equals('Pure offline store-and-forward'));
    });
  });
}
