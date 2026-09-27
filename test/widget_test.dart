import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resqmesh/features/decision/basic_decision_engine.dart';
import 'package:resqmesh/features/discovery/ble_discovery_stub.dart';
import 'package:resqmesh/features/mesh/message_manager.dart';
import 'package:resqmesh/features/routing/dtn_router_stub.dart';
import 'package:resqmesh/main.dart';

void main() {
  testWidgets('ResQMesh Step 1 Foundation Smoke & Navigation Test', (WidgetTester tester) async {
    final decisionEngine = BasicDecisionEngine();
    final dtnRouter = DtnRouterStub();
    final discoveryService = BleDiscoveryStub();

    final messageManager = MessageManager(
      decisionEngine: decisionEngine,
      dtnRouter: dtnRouter,
      discoveryService: discoveryService,
      localNodeId: 'node-test-ui',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MessageManager>.value(value: messageManager),
        ],
        child: const ResQMeshApp(),
      ),
    );

    // Verify OFFLINE MESH banner and Node ID
    expect(find.text('OFFLINE MESH ACTIVE'), findsOneWidget);
    expect(find.text('node-test-ui'), findsOneWidget);

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

    // Verify message is now queued in local DTN outbox
    expect(messageManager.queuedMessageCount, equals(1));
    expect(find.text('1'), findsWidgets);

    // Test Navigation to Messages tab
    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Messages'), findsOneWidget);
    expect(find.text('Compose'), findsOneWidget);

    // Test Navigation to Mesh Nodes tab
    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Mesh Nodes & Peers'), findsOneWidget);
    expect(find.text('No Nearby Mesh Nodes'), findsOneWidget);

    // Test Navigation to Diagnostics tab
    await tester.tap(find.byIcon(Icons.schema_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Architecture & Diagnostics'), findsOneWidget);
    expect(find.text('STRICT ZERO-INTERNET RULE'), findsOneWidget);
  });
}
