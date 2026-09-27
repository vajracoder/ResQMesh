import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/constants/app_constants.dart';
import 'package:resqmesh/features/identity/models/node_role.dart';
import 'package:resqmesh/features/identity/repositories/in_memory_node_identity_repository.dart';
import 'package:resqmesh/features/identity/repositories/shared_prefs_node_identity_repository.dart';
import 'package:resqmesh/features/identity/services/node_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ResQMesh Step 2 - Persistent Node Identity Unit Tests', () {
    late InMemoryNodeIdentityRepository repository;
    late NodeIdentityService service;

    setUp(() {
      repository = InMemoryNodeIdentityRepository();
      service = NodeIdentityService(repository: repository);
    });

    test('TEST 1: First initialization creates a Node ID', () async {
      expect(service.currentNodeId, isEmpty);
      final identity = await service.initialize();

      expect(identity.nodeId, isNotEmpty);
      expect(service.currentNodeId, equals(identity.nodeId));
      expect(identity.nodeId.startsWith('RQM-'), isTrue);
    });

    test('TEST 2: Node ID is not empty', () async {
      final identity = await service.initialize();
      expect(identity.nodeId.trim(), isNotEmpty);
      expect(identity.nodeId.length, greaterThan(10));
    });

    test('TEST 3: Node ID remains identical after reinitialization', () async {
      final firstIdentity = await service.initialize();
      final firstNodeId = firstIdentity.nodeId;

      // Reinitialize same service instance
      final secondIdentity = await service.initialize();
      expect(secondIdentity.nodeId, equals(firstNodeId));

      // Reinitialize a fresh service sharing the same persistent repository
      final newServiceInstance = NodeIdentityService(repository: repository);
      final reloadedIdentity = await newServiceInstance.initialize();

      expect(reloadedIdentity.nodeId, equals(firstNodeId));
    });

    test('TEST 4: Display name persists', () async {
      await service.initialize();
      expect(service.identity!.displayName, equals('ResQMesh Node'));

      await service.updateDisplayName("Ishan's ResQMesh");
      expect(service.identity!.displayName, equals("Ishan's ResQMesh"));

      // Verify persistence in repository
      final storedInRepo = await repository.getIdentity();
      expect(storedInRepo!.displayName, equals("Ishan's ResQMesh"));
    });

    test('TEST 5: Changing display name does not change Node ID', () async {
      final initial = await service.initialize();
      final originalNodeId = initial.nodeId;

      await service.updateDisplayName('Rescue Team Alpha');
      expect(service.identity!.displayName, equals('Rescue Team Alpha'));
      expect(service.identity!.nodeId, equals(originalNodeId));
      expect(service.currentNodeId, equals(originalNodeId));

      final stored = await repository.getIdentity();
      expect(stored!.nodeId, equals(originalNodeId));
    });

    test('TEST 6: Default role is CIVILIAN', () async {
      final identity = await service.initialize();
      expect(identity.role, equals(NodeRole.civilian));
      expect(identity.role.displayName, equals('CIVILIAN'));
    });

    test('TEST 7: Default gateway status is false', () async {
      final identity = await service.initialize();
      expect(identity.isGateway, isFalse);
    });

    test('TEST 8: Protocol version is loaded from AppConstants', () async {
      final identity = await service.initialize();
      expect(identity.protocolVersion, equals(AppConstants.protocolVersion));
      expect(identity.protocolVersion, equals('1.0'));
    });

    test('TEST 9: Two independent node identity repositories generate different Node IDs', () async {
      final repoA = InMemoryNodeIdentityRepository();
      final repoB = InMemoryNodeIdentityRepository();

      final serviceA = NodeIdentityService(repository: repoA);
      final serviceB = NodeIdentityService(repository: repoB);

      final identityA = await serviceA.initialize();
      final identityB = await serviceB.initialize();

      expect(identityA.nodeId, isNot(equals(identityB.nodeId)));
      expect(identityA.nodeId.startsWith('RQM-'), isTrue);
      expect(identityB.nodeId.startsWith('RQM-'), isTrue);
    });

    test('TEST 10: Node identity can be loaded after simulated application restart', () async {
      // 1. Initial app run - creates identity and sets custom display name
      final initialService = NodeIdentityService(repository: repository);
      final initialIdentity = await initialService.initialize();
      await initialService.updateDisplayName('Survivor Node 42');
      await initialService.updateRole(NodeRole.responder);

      final savedNodeId = initialIdentity.nodeId;
      final savedCreatedAt = initialIdentity.createdAt;

      // 2. Simulated app restart: new service instance referencing the same underlying storage
      final restartedService = NodeIdentityService(repository: repository);
      expect(restartedService.isInitialized, isFalse);
      expect(restartedService.currentNodeId, isEmpty);

      final restoredIdentity = await restartedService.initialize();

      expect(restoredIdentity.nodeId, equals(savedNodeId));
      expect(restoredIdentity.displayName, equals('Survivor Node 42'));
      expect(restoredIdentity.role, equals(NodeRole.responder));
      expect(restoredIdentity.createdAt, equals(savedCreatedAt));
      expect(restoredIdentity.protocolVersion, equals(AppConstants.protocolVersion));
    });

    test('Error Handling: Storage failure does NOT silently overwrite node identity', () async {
      // Create repository and populate identity
      final failureRepo = InMemoryNodeIdentityRepository();
      final validService = NodeIdentityService(repository: failureRepo);
      final originalIdentity = await validService.initialize();

      // Simulate a read error
      failureRepo.shouldThrowOnRead = true;

      final newService = NodeIdentityService(repository: failureRepo);
      await expectLater(newService.initialize, throwsA(isA<Exception>()));
      expect(newService.hasError, isTrue);
      expect(newService.errorMessage, contains('Failed to load local node identity'));

      // Ensure repository still has original identity and was NOT wiped/overwritten
      failureRepo.shouldThrowOnRead = false;
      final restored = await failureRepo.getIdentity();
      expect(restored!.nodeId, equals(originalIdentity.nodeId));
    });

    test('SharedPreferences persistence integration test with mock values', () async {
      SharedPreferences.setMockInitialValues({});
      final prefsRepo = SharedPrefsNodeIdentityRepository();
      final prefsService = NodeIdentityService(repository: prefsRepo);

      final created = await prefsService.initialize();
      expect(created.nodeId.startsWith('RQM-'), isTrue);

      await prefsService.updateDisplayName('Disaster Response Unit');

      // Reload with new service instance to verify disk persistence
      final reloadedService = NodeIdentityService(repository: prefsRepo);
      final reloaded = await reloadedService.initialize();

      expect(reloaded.nodeId, equals(created.nodeId));
      expect(reloaded.displayName, equals('Disaster Response Unit'));
    });
  });
}
