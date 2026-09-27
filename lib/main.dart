import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/decision/basic_decision_engine.dart';
import 'features/discovery/ble_discovery_stub.dart';
import 'features/mesh/message_manager.dart';
import 'features/routing/dtn_router_stub.dart';
import 'features/ui/screens/main_shell.dart';

void main() {
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

  // Initialize Core Path components (Flutter UI -> Message Manager -> Decision Engine -> DTN Router -> Discovery -> BLE)
  final decisionEngine = BasicDecisionEngine();
  final dtnRouter = DtnRouterStub();
  final discoveryService = BleDiscoveryStub();

  final messageManager = MessageManager(
    decisionEngine: decisionEngine,
    dtnRouter: dtnRouter,
    discoveryService: discoveryService,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MessageManager>.value(value: messageManager),
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
