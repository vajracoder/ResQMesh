import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/decision/basic_decision_engine.dart';
import 'features/discovery/ble_discovery_stub.dart';
import 'features/identity/repositories/shared_prefs_node_identity_repository.dart';
import 'features/identity/services/node_identity_service.dart';
import 'features/mesh/message_manager.dart';
import 'features/routing/dtn_router_stub.dart';
import 'features/storage/repositories/dtn_message_repository.dart';
import 'features/storage/repositories/sqlite_dtn_message_repository.dart';
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

  // Initialize Step 1 Core Path components
  final decisionEngine = BasicDecisionEngine();
  final dtnRouter = DtnRouterStub();
  final discoveryService = BleDiscoveryStub();

  final messageManager = MessageManager(
    decisionEngine: decisionEngine,
    dtnRouter: dtnRouter,
    discoveryService: discoveryService,
    identityService: identityService,
    messageRepository: messageRepository,
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
        ChangeNotifierProvider<MessageManager>.value(value: messageManager),
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
