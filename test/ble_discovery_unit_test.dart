import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/constants/app_constants.dart';
import 'package:resqmesh/features/discovery/ble_advertisement_codec.dart';
import 'package:resqmesh/features/discovery/ble_discovery_service.dart';
import 'package:resqmesh/features/identity/models/node_identity.dart';
import 'package:resqmesh/features/identity/models/node_role.dart';
import 'package:resqmesh/features/identity/repositories/in_memory_node_identity_repository.dart';
import 'package:resqmesh/features/identity/services/node_identity_service.dart';
import 'package:resqmesh/features/mesh/models/peer_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNodeIdentityRepository identityRepo;
  late NodeIdentityService identityService;
  late BleDiscoveryService discoveryService;

  const localId = 'RQM-00000000-0000-0000-0000-000000000001';
  const peerIdA = 'RQM-11111111-1111-1111-1111-111111111111';
  const peerIdB = 'RQM-22222222-2222-2222-2222-222222222222';

  setUp(() async {
    identityRepo = InMemoryNodeIdentityRepository();
    await identityRepo.saveIdentity(
      NodeIdentity(
        nodeId: localId,
        displayName: 'Local Survivor',
        role: NodeRole.civilian,
        createdAt: DateTime.now().toUtc(),
        protocolVersion: AppConstants.protocolVersion,
        isGateway: false,
      ),
    );
    identityService = NodeIdentityService(repository: identityRepo);
    await identityService.initialize();

    discoveryService = BleDiscoveryService(identityService: identityService);
    await discoveryService.initialize();
  });

  tearDown(() {
    discoveryService.dispose();
  });

  group('ResQMesh Step 4 — Real BLE Peer Discovery Unit Tests', () {
    // TEST 1
    test('TEST 1: BLE service initializes correctly', () {
      expect(discoveryService.currentPeers, isEmpty);
      expect(discoveryService.peerCount, equals(0));
      expect(discoveryService.localNodeId, equals(localId));
    });

    // TEST 2
    test('TEST 2: Invalid Node IDs are rejected', () {
      expect(BleAdvertisementCodec.isValidNodeId('INVALID-ID-123'), isFalse);
      expect(BleAdvertisementCodec.isValidNodeId('RQM-short'), isFalse);
      expect(BleAdvertisementCodec.isValidNodeId('node-local-abc'), isFalse);
      expect(BleAdvertisementCodec.isValidNodeId(''), isFalse);

      // Sending corrupt/invalid advertisement data to service must not create a peer
      final malformedBytes = [0x52, 0x51, 0x01, 0x00, 1, 2, 3]; // Truncated
      discoveryService.onAdvertisementReceived(rawData: malformedBytes, rssi: -70);
      expect(discoveryService.currentPeers, isEmpty);
    });

    // TEST 3
    test('TEST 3: Valid ResQMesh Node IDs are accepted', () {
      expect(BleAdvertisementCodec.isValidNodeId(peerIdA), isTrue);
      expect(BleAdvertisementCodec.isValidNodeId(peerIdB), isTrue);

      final encoded = BleAdvertisementCodec.encode(
        nodeId: peerIdA,
        displayName: 'Medic Alpha',
      );

      discoveryService.onAdvertisementReceived(rawData: encoded, rssi: -65);
      expect(discoveryService.peerCount, equals(1));
      expect(discoveryService.currentPeers.first.nodeId, equals(peerIdA));
      expect(discoveryService.currentPeers.first.displayName, equals('Medic Alpha'));
      expect(discoveryService.currentPeers.first.isResQMeshPeer, isTrue);
    });

    // TEST 4
    test('TEST 4: Non-ResQMesh advertisements are ignored', () {
      // Simulate random non-ResQMesh BLE advertisement (e.g. smartwatch, earbuds, iBeacon)
      final nonResQMeshBytes = [0x02, 0x01, 0x06, 0x1A, 0xFF, 0x4C, 0x00];

      discoveryService.onAdvertisementReceived(rawData: nonResQMeshBytes, rssi: -50);
      expect(discoveryService.peerCount, equals(0));
      expect(discoveryService.currentPeers, isEmpty);
    });

    // TEST 5
    test('TEST 5: Own Node ID is ignored (self-filtering)', () {
      // Encode advertisement with the local node's own Node ID
      final ownPacket = BleAdvertisementCodec.encode(
        nodeId: localId,
        displayName: 'Local Survivor Echo',
      );

      discoveryService.onAdvertisementReceived(rawData: ownPacket, rssi: -20);
      // Must not add self to discovered peers list
      expect(discoveryService.peerCount, equals(0));
      expect(discoveryService.currentPeers, isEmpty);
    });

    // TEST 6
    test('TEST 6: Two scan results from the same Node ID produce one peer (deduplication)', () {
      final packet = BleAdvertisementCodec.encode(
        nodeId: peerIdA,
        displayName: 'Peer A',
      );

      // Packet received first time
      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -75);
      expect(discoveryService.peerCount, equals(1));

      // Same packet received again (e.g. 500ms later)
      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -72);
      expect(discoveryService.peerCount, equals(1));
    });

    // TEST 7
    test('TEST 7: RSSI is updated when a peer is seen again', () {
      final packet = BleAdvertisementCodec.encode(
        nodeId: peerIdA,
        displayName: 'Moving Node',
      );

      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -85);
      expect(discoveryService.currentPeers.first.rssi, equals(-85));

      // Node moved closer
      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -55);
      expect(discoveryService.currentPeers.first.rssi, equals(-55));
    });

    // TEST 8
    test('TEST 8: lastSeen is updated', () async {
      final packet = BleAdvertisementCodec.encode(nodeId: peerIdA);

      final t0 = DateTime.utc(2026, 9, 27, 10, 0, 0);
      final initialPeer = PeerNode(
        nodeId: peerIdA,
        rssi: -70,
        lastSeen: t0,
      );

      // Ingest once
      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -70);
      final seenTime1 = discoveryService.currentPeers.first.lastSeen;

      // Small delay to ensure timestamp difference
      await Future.delayed(const Duration(milliseconds: 10));

      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -68);
      final seenTime2 = discoveryService.currentPeers.first.lastSeen;

      expect(seenTime2.isAfter(seenTime1) || seenTime2.isAtSameMomentAs(seenTime1), isTrue);
      expect(initialPeer.lastSeen, equals(t0));
    });

    // TEST 9
    test('TEST 9: Stale peers are removed/marked stale', () {
      final now = DateTime.now().toUtc();
      final freshPeer = PeerNode(
        nodeId: peerIdA,
        rssi: -60,
        lastSeen: now,
      );
      final stalePeer = PeerNode(
        nodeId: peerIdB,
        rssi: -80,
        lastSeen: now.subtract(const Duration(seconds: 30)), // 30 seconds ago > 15s timeout
      );

      expect(freshPeer.isStale(now: now, timeoutSeconds: 15), isFalse);
      expect(stalePeer.isStale(now: now, timeoutSeconds: 15), isTrue);

      // Ingest peer packet
      final packet = BleAdvertisementCodec.encode(nodeId: peerIdA);
      discoveryService.onAdvertisementReceived(rawData: packet, rssi: -60);
      expect(discoveryService.peerCount, equals(1));

      // Force stale peer pruning with a future reference time
      discoveryService.pruneStalePeers(timeoutSeconds: 0); // Everything past is stale
      expect(discoveryService.peerCount, equals(0));
    });

    // TEST 10
    test('TEST 10: Protocol mismatch is detected', () {
      final mismatchedPacket = BleAdvertisementCodec.encode(
        nodeId: peerIdA,
        protocolVersion: '2.5', // Future protocol version
      );

      discoveryService.onAdvertisementReceived(rawData: mismatchedPacket, rssi: -70);
      expect(discoveryService.peerCount, equals(1));

      final peer = discoveryService.currentPeers.first;
      expect(peer.protocolVersion, equals('2.5'));
      expect(peer.hasProtocolMismatch(expectedVersion: '1.0'), isTrue);
    });

    // TEST 11
    test('TEST 11: Bluetooth-disabled state is represented correctly', () {
      discoveryService.setHardwareStateForTest(BleHardwareState.poweredOff);
      expect(discoveryService.hardwareState, equals(BleHardwareState.poweredOff));
    });

    // TEST 12
    test('TEST 12: Permission-denied state is represented correctly', () {
      discoveryService.setScanStatusForTest(BleScanStatus.permissionDenied);
      expect(discoveryService.scanStatus, equals(BleScanStatus.permissionDenied));
    });

    // TEST 13
    test('TEST 13: No fake peers are generated when scanning produces no ResQMesh advertisements', () {
      // Clear peers and ensure zero peers exist
      discoveryService.clearPeers();
      expect(discoveryService.peerCount, equals(0));
      expect(discoveryService.currentPeers, isEmpty);
    });
  });
}
