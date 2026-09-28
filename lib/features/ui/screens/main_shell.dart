import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../identity/models/node_role.dart';
import '../../identity/services/node_identity_service.dart';
import 'diagnostics_screen.dart';
import 'gateway_inbox_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'peers_screen.dart';
import 'responder_dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final identityService = context.watch<NodeIdentityService>();
    final role = identityService.identity?.role ?? NodeRole.civilian;
    final isGateway = identityService.identity?.isGateway ?? false;

    final screens = <Widget>[
      const HomeScreen(),
      const MessagesScreen(),
      const PeersScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard_rounded),
        activeIcon: Icon(Icons.dashboard_rounded, color: AppTheme.meshCyan),
        label: 'SOS / Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.forum_outlined),
        activeIcon: Icon(Icons.forum_rounded, color: AppTheme.meshCyan),
        label: 'Messages',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.hub_outlined),
        activeIcon: Icon(Icons.hub_rounded, color: AppTheme.meshCyan),
        label: 'Mesh Nodes',
      ),
    ];

    // Conditional tab for Responder
    if (role == NodeRole.responder || role == NodeRole.command) {
      screens.add(const ResponderDashboardScreen());
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.emergency_outlined),
          activeIcon: Icon(Icons.emergency, color: Colors.redAccent),
          label: 'Triage',
        ),
      );
    }

    // Conditional tab for Gateway
    if (role == NodeRole.gateway || isGateway) {
      screens.add(const GatewayInboxScreen());
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.move_to_inbox_outlined),
          activeIcon: Icon(Icons.move_to_inbox, color: Colors.indigoAccent),
          label: 'Gateway',
        ),
      );
    }

    // Always include Diagnostics
    screens.add(const DiagnosticsScreen());
    items.add(
      const BottomNavigationBarItem(
        icon: Icon(Icons.schema_outlined),
        activeIcon: Icon(Icons.schema_rounded, color: AppTheme.meshCyan),
        label: 'Diagnostics',
      ),
    );

    final safeIndex = _currentIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: items,
      ),
    );
  }
}
