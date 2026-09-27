import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resqmesh/features/decision/basic_decision_engine.dart';
import 'package:resqmesh/features/discovery/ble_discovery_service.dart';
import 'package:resqmesh/features/identity/repositories/in_memory_node_identity_repository.dart';
import 'package:resqmesh/features/identity/services/node_identity_service.dart';
import 'package:resqmesh/features/mesh/message_manager.dart';
import 'package:resqmesh/features/routing/dtn_router_stub.dart';
import 'package:resqmesh/features/storage/repositories/dtn_message_repository.dart';
import 'package:resqmesh/features/storage/repositories/in_memory_dtn_message_repository.dart';
import 'package:resqmesh/main.dart';

void main() {
  testWidgets('ResQMesh Step 1+2+3+4 Foundation Smoke & Navigation Test', (WidgetTester tester) async {
    final decisionEngine = BasicDecisionEngine();
    final dtnRouter = DtnRouterStub();

    final identityRepo = InMemoryNodeIdentityRepository();
    final identityService = NodeIdentityService(repository: identityRepo);
    await identityService.initialize();

    final messageRepo = InMemoryDtnMessageRepository();
    await messageRepo.init();

    final discoveryService = BleDiscoveryService(identityService: identityService);
    await discoveryService.initialize();

    final messageManager = MessageManager(
      decisionEngine: decisionEngine,
      dtnRouter: dtnRouter,
      discoveryService: discoveryService,
      identityService: identityService,
      messageRepository: messageRepo,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NodeIdentityService>.value(value: identityService),
          ChangeNotifierProvider<BleDiscoveryService>.value(value: discoveryService),
          ChangeNotifierProvider<MessageManager>.value(value: messageManager),
          Provider<DtnMessageRepository>.value(value: messageRepo),
        ],
        child: const ResQMeshApp(),
      ),
    );

    // Verify OFFLINE MESH banner
    expect(find.text('OFFLINE MESH ACTIVE'), findsOneWidget);

    // Verify SOS button exists
    expect(find.text('BROADCAST'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);

    // Verify status cards
    expect(find.text('NEARBY PEERS'), findsOneWidget);
    expect(find.text('DTN OUTBOX'), findsOneWidget);

    // Tap SOS button and verify dialog opens
    await tester.tap(find.text('BROADCAST'));
    await tester.pumpAndSettle();

    expect(find.text('BROADCAST SOS'), findsOneWidget);
    expect(find.text('DISPATCH SOS NOW'), findsOneWidget);

    // Tap Dispatch SOS Now
    await tester.tap(find.text('DISPATCH SOS NOW'));
    await tester.pumpAndSettle();

    // Verify message is now queued/stored in local DTN outbox
    expect(messageManager.queuedMessageCount, equals(1));
    expect(messageManager.totalStoredCount, equals(1));

    // Test Navigation to Messages tab
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Messages'), findsOneWidget);
    expect(find.text('Compose'), findsOneWidget);

    // Test Navigation to Mesh Nodes tab
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Mesh Nodes & Peers'), findsOneWidget);
    expect(find.text('No ResQMesh peers found'), findsOneWidget);
    expect(find.text('BLUETOOTH LOW ENERGY DISCOVERY'), findsOneWidget);

    // Test Navigation to Diagnostics tab
    await tester.tap(find.byIcon(Icons.schema_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Architecture & Diagnostics'), findsOneWidget);
    expect(find.text('STRICT ZERO-INTERNET RULE'), findsOneWidget);

    // Step 2: Verify MY NODE section appears with identity data
    expect(find.text('MY NODE'), findsOneWidget);
    expect(find.text('Node ID'), findsOneWidget);
    expect(find.text('Display Name'), findsOneWidget);
    expect(find.text('ResQMesh Node'), findsWidgets);
    expect(find.text('CIVILIAN'), findsOneWidget);
    expect(find.text('No'), findsOneWidget); // Gateway: No

    // Step 3: Scroll down to reveal LOCAL DTN STORAGE section
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('LOCAL DTN STORAGE'), findsOneWidget);
    expect(find.text('Database Status'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('Stored Messages'), findsOneWidget);

    // Step 4: Scroll further to reveal BLE PEER DISCOVERY section
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(find.text('BLE PEER DISCOVERY'), findsOneWidget);
    expect(find.text('BLE Hardware'), findsOneWidget);

    // Scroll further to reveal the pipeline diagram
    final pipelineFinder = find.text('Peer Discovery (BLE)');
    await tester.scrollUntilVisible(pipelineFinder, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Node Identity'), findsOneWidget);
    expect(pipelineFinder, findsOneWidget);
  });
}
