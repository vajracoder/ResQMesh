import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../identity/models/node_role.dart';
import '../../identity/services/node_identity_service.dart';
import '../../mesh/message_manager.dart';

class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  void _copyNodeId(BuildContext context, String nodeId) {
    Clipboard.setData(ClipboardData(text: nodeId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Node ID copied'),
        duration: Duration(seconds: 2),
        backgroundColor: AppTheme.cardBackground,
      ),
    );
  }

  void _showEditDisplayNameDialog(BuildContext context, NodeIdentityService identityService) {
    final currentName = identityService.identity?.displayName ?? 'ResQMesh Node';
    final textController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          title: const Text(
            'Edit Display Name',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This local label is shown to nearby mesh nodes. Node ID remains strictly unchanged.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF101319),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = textController.text.trim();
                if (newName.isNotEmpty) {
                  await identityService.updateDisplayName(newName);
                }
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();
    final identityService = context.watch<NodeIdentityService>();
    final identity = identityService.identity;

    final architectureLayers = [
      _ArchStep(
        title: 'Flutter UI',
        subtitle: 'Emergency dashboard, message composer & node monitor',
        status: 'Active (Step 1)',
        isActive: true,
        icon: Icons.dashboard_outlined,
      ),
      _ArchStep(
        title: 'Node Identity',
        subtitle: 'Cryptographic UUID persistent across app restarts',
        status: 'Active (Step 2)',
        isActive: true,
        icon: Icons.fingerprint_rounded,
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

    final createdFormatted = identity != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(identity.createdAt.toLocal())
        : 'Loading...';

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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                SizedBox(height: 8),
                Text(
                  'The ResQMesh core path operates completely autonomously on-device. No cellular data, Wi-Fi router, or cloud backend is required for mesh discovery and message delivery.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Diagnostic Storage Error if any
          if (identityService.hasError) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E1518),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.sosRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.sosRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      identityService.errorMessage ?? 'Identity storage error',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --------------------------------
          // MY NODE SECTION
          // --------------------------------
          const Text(
            'MY NODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Node ID with Copy Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Node ID',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            identity?.nodeId ?? manager.localNodeId,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppTheme.meshCyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.meshCyan),
                      tooltip: 'Copy Node ID',
                      onPressed: () => _copyNodeId(context, identity?.nodeId ?? manager.localNodeId),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Display Name with Edit Button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Display Name',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            identity?.displayName ?? 'ResQMesh Node',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                      tooltip: 'Edit Display Name',
                      onPressed: () => _showEditDisplayNameDialog(context, identityService),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Role & Gateway status row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Role',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            identity?.role.displayName ?? NodeRole.civilian.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gateway',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (identity?.isGateway ?? false) ? 'Yes' : 'No',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Protocol Version & Created Timestamp row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Protocol Version',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            identity?.protocolVersion ?? AppConstants.protocolVersion,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Created',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            createdFormatted,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Core Path Status Flow
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
