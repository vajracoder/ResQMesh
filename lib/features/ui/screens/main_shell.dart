import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'diagnostics_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'peers_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    MessagesScreen(),
    PeersScreen(),
    DiagnosticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            activeIcon: Icon(Icons.dashboard_rounded, color: AppTheme.meshCyan),
            label: 'SOS / Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum_outlined),
            activeIcon: Icon(Icons.forum_rounded, color: AppTheme.meshCyan),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub_rounded, color: AppTheme.meshCyan),
            label: 'Mesh Nodes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schema_outlined),
            activeIcon: Icon(Icons.schema_rounded, color: AppTheme.meshCyan),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }
}
