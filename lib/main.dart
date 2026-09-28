import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/decision/basic_decision_engine.dart';
import 'features/discovery/ble_discovery_service.dart';
import 'features/gateway/gateway_inbox_service.dart';
import 'features/identity/repositories/shared_prefs_node_identity_repository.dart';
import 'features/identity/services/node_identity_service.dart';
import 'features/mesh/message_manager.dart';
import 'features/responder/emergency_handoff_service.dart';
import 'features/responder/responder_service.dart';
import 'features/routing/ble_dtn_router.dart';
import 'features/routing/intelligent_routing_engine.dart';
import 'features/routing/logging/routing_event_log.dart';
import 'features/routing/metrics/routing_research_metrics.dart';
import 'features/routing/models/relay_metrics.dart';
import 'features/storage/repositories/dtn_message_repository.dart';
import 'features/storage/repositories/sqlite_dtn_message_repository.dart';
import 'features/transport/ble_transport.dart';
import 'features/transport/flutter_ble_transport.dart';
import 'features/ui/screens/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark navigation and status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SQLite FFI if running on desktop OS (Windows/Linux/macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Step 2: Persistent Node Identity (SharedPreferences)
  final identityRepository = SharedPrefsNodeIdentityRepository();
  final identityService = NodeIdentityService(repository: identityRepository);

  try {
    await identityService.initialize();
  } catch (e) {
    // Error is logged and displayed via identityService.hasError in diagnostics UI
    debugPrint('ResQMesh: Initial identity load warning: $e');
  }

  // Initialize Step 3: Persistent DTN Message / Bundle Storage (SQLite)
  final messageRepository = SqliteDtnMessageRepository();
  try {
    await messageRepository.init();
  } catch (e) {
    debugPrint('ResQMesh: Initial SQLite DTN database load warning: $e');
  }

  // Initialize Step 4: Real BLE Peer Discovery
  final discoveryService = BleDiscoveryService(identityService: identityService);
  try {
    await discoveryService.initialize();
  } catch (e) {
    debugPrint('ResQMesh: Initial BLE discovery notice: $e');
  }

  // Initialize Step 5: Real BLE Message Transport
  final bleTransport = FlutterBleTransport(identityService: identityService);
  try {
    await bleTransport.initialize();
  } catch (e) {
    debugPrint('ResQMesh: Initial BLE transport notice: $e');
  }

  // Initialize Step 7: Intelligent Emergency DTN Routing Engine
  final routingEventLog = RoutingEventLog();
  final routingResearchMetrics = RoutingResearchMetrics();

  final intelligentEngine = IntelligentRoutingEngine(
    eventLog: routingEventLog,
    metrics: routingResearchMetrics,
  );

  // Initialize Step 8: Responder Triage & Gateway Handoff Integration
  final emergencyHandoffService = LocalEmergencyHandoffService();
  final responderService = ResponderService(repository: messageRepository);
  final gatewayInboxService = GatewayInboxService(
    repository: messageRepository,
    handoffService: emergencyHandoffService,
  );

  final decisionEngine = BasicDecisionEngine();
  final dtnRouter = BleDtnRouter(
    transport: bleTransport,
    messageRepository: messageRepository,
    decisionEngine: intelligentEngine,
  );

  final messageManager = MessageManager(
    decisionEngine: decisionEngine,
    dtnRouter: dtnRouter,
    discoveryService: discoveryService,
    transport: bleTransport,
    identityService: identityService,
    messageRepository: messageRepository,
    responderService: responderService,
    gatewayInboxService: gatewayInboxService,
    routingMetrics: routingResearchMetrics,
  );

  try {
    await messageManager.initializeStorage();
  } catch (e) {
    debugPrint('ResQMesh: Initial storage synchronization warning: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<NodeIdentityService>.value(value: identityService),
        ChangeNotifierProvider<BleDiscoveryService>.value(value: discoveryService),
        ChangeNotifierProvider<BleTransport>.value(value: bleTransport),
        ChangeNotifierProvider<MessageManager>.value(value: messageManager),
        ChangeNotifierProvider<RelayMetrics>.value(value: messageManager.relayMetrics),
        ChangeNotifierProvider<RoutingResearchMetrics>.value(value: routingResearchMetrics),
        ChangeNotifierProvider<RoutingEventLog>.value(value: routingEventLog),
        ChangeNotifierProvider<EmergencyHandoffService>.value(value: emergencyHandoffService),
        ChangeNotifierProvider<ResponderService>.value(value: responderService),
        ChangeNotifierProvider<GatewayInboxService>.value(value: gatewayInboxService),
        Provider<IntelligentRoutingEngine>.value(value: intelligentEngine),
        Provider<DtnMessageRepository>.value(value: messageRepository),
      ],
      child: const ResQMeshApp(),
    ),
  );
}

class ResQMeshApp extends StatelessWidget {
  const ResQMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainShell(),
    );
  }
}
