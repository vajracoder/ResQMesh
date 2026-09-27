import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../mesh/message_manager.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();

    final architectureLayers = [
      _ArchStep(
        title: 'Flutter UI',
        subtitle: 'Emergency dashboard, message composer & node monitor',
        status: 'Active (Step 1)',
        isActive: true,
        icon: Icons.dashboard_outlined,
      ),
      _ArchStep(
        title: 'Message Manager',
        subtitle: 'Decoupled coordination, outbox management & state updates',
        status: 'Active (Step 1)',
        isActive: true,
        icon: Icons.alt_route_rounded,
      ),
      _ArchStep(
        title: 'Decision Engine',
        subtitle: 'Priority admission, TTL enforcement & battery optimization',
        status: 'Contract Ready (Step 8)',
        isActive: true,
        icon: Icons.psychology_outlined,
      ),
      _ArchStep(
        title: 'DTN Router',
        subtitle: 'Opportunistic Store-and-Forward bundle routing',
        status: 'In-Memory Queue (Step 3/7)',
        isActive: true,
        icon: Icons.swap_calls_rounded,
      ),
      _ArchStep(
        title: 'Peer Discovery',
        subtitle: 'BLE neighbor detection & presence beacons',
        status: 'Scheduled (Step 4)',
        isActive: false,
        icon: Icons.sensors_outlined,
      ),
      _ArchStep(
        title: 'BLE Local Communication',
        subtitle: 'GATT / L2CAP physical transmission without Internet',
        status: 'Scheduled (Step 6)',
        isActive: false,
        icon: Icons.bluetooth_rounded,
      ),
      _ArchStep(
        title: 'Nearby ResQMesh Nodes',
        subtitle: 'Multi-hop relay to reach survivors and medical hubs',
        status: 'Mesh Target',
        isActive: false,
        icon: Icons.group_work_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Architecture & Diagnostics'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Zero-Internet Architecture Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131D2A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.meshCyan.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.meshCyan, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'STRICT ZERO-INTERNET RULE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.meshCyan,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'The ResQMesh core path operates completely autonomously on-device. No cellular data, Wi-Fi router, or cloud backend is required for mesh discovery and message delivery.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Local Node ID: ', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text(
                      manager.localNodeId,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppTheme.meshCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'CORE PATH PIPELINE STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Flow diagram list
          ...architectureLayers.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isLast = idx == architectureLayers.length - 1;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: step.isActive ? AppTheme.meshCyan.withValues(alpha: 0.4) : AppTheme.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: step.isActive ? AppTheme.meshCyan.withValues(alpha: 0.15) : const Color(0xFF1E232B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          step.icon,
                          size: 20,
                          color: step.isActive ? AppTheme.meshCyan : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              step.subtitle,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: step.isActive ? AppTheme.activeGreenMuted : const Color(0xFF1E232B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          step.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: step.isActive ? AppTheme.activeGreen : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Container(
                    height: 18,
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.textMuted),
                  ),
              ],
            );
          }),

          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ArchStep {
  final String title;
  final String subtitle;
  final String status;
  final bool isActive;
  final IconData icon;

  const _ArchStep({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.isActive,
    required this.icon,
  });
}
