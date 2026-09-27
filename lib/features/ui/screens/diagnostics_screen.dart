import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../discovery/ble_discovery_service.dart';
import '../../identity/services/node_identity_service.dart';
import '../../mesh/message_manager.dart';
import '../../routing/models/relay_metrics.dart';

/// Screen detailing the ResQMesh system status, persistent Node Identity,
/// local SQLite DTN storage statistics, BLE peer discovery, and offline core path pipeline.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  void _copyNodeId(BuildContext context, String nodeId) {
    Clipboard.setData(ClipboardData(text: nodeId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Node ID copied: $nodeId'),
        backgroundColor: AppTheme.cardBackground,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showEditDisplayNameDialog(BuildContext context, NodeIdentityService identityService) {
    final textController = TextEditingController(text: identityService.identity?.displayName ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          title: const Text('Edit Node Display Name', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This name is broadcast to nearby nodes during discovery beacons. It does not alter your persistent Node ID.',
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10141C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();
    final identityService = context.watch<NodeIdentityService>();
    final bleService = context.watch<BleDiscoveryService?>();
    final relayMetrics = context.watch<RelayMetrics?>() ?? manager.relayMetrics;
    final identity = identityService.identity;

    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isScanning = bleService?.isDiscovering ?? manager.discoveryService.isDiscovering;
    final bluetoothState = bleService?.hardwareState ?? BleHardwareState.unknown;
    final isBluetoothOn = bluetoothState == BleHardwareState.poweredOn;

    final architectureLayers = [
      const _ArchStep(
        title: 'Flutter UI',
        subtitle: 'Emergency dashboard, message composer & node monitor',
        status: 'Active (Step 1)',
        isActive: true,
        icon: Icons.dashboard_outlined,
      ),
      const _ArchStep(
        title: 'Node Identity',
        subtitle: 'Cryptographic UUID persistent across app restarts',
        status: 'Active (Step 2)',
        isActive: true,
        icon: Icons.fingerprint_rounded,
      ),
      const _ArchStep(
        title: 'Message Manager',
        subtitle: 'Decoupled coordination, outbox management & state updates',
        status: 'Active (Step 1)',
        isActive: true,
        icon: Icons.alt_route_rounded,
      ),
      const _ArchStep(
        title: 'Decision Engine',
        subtitle: 'Priority admission, TTL enforcement & battery optimization',
        status: 'Contract Ready (Step 8)',
        isActive: true,
        icon: Icons.psychology_outlined,
      ),
      const _ArchStep(
        title: 'Local DTN Storage (SQLite)',
        subtitle: 'Persistent offline message bundles & store-and-forward queue',
        status: 'Active (Step 3)',
        isActive: true,
        icon: Icons.storage_rounded,
      ),
      const _ArchStep(
        title: 'Peer Discovery (BLE)',
        subtitle: 'Real-time neighbor detection & presence beacons',
        status: 'Active (Step 4)',
        isActive: true,
        icon: Icons.sensors_outlined,
      ),
      const _ArchStep(
        title: 'DTN Router',
        subtitle: 'Opportunistic Store-and-Forward bundle routing',
        status: 'Active (Step 6)',
        isActive: true,
        icon: Icons.swap_calls_rounded,
      ),
      const _ArchStep(
        title: 'BLE Local Communication',
        subtitle: 'GATT / L2CAP physical transmission without Internet',
        status: 'Active (Step 5)',
        isActive: true,
        icon: Icons.bluetooth_rounded,
      ),
      const _ArchStep(
        title: 'Nearby ResQMesh Nodes',
        subtitle: 'Multi-hop relay to reach survivors and medical hubs',
        status: 'Multi-Hop Relay Active (Step 6)',
        isActive: true,
        icon: Icons.group_work_outlined,
      ),
    ];

    final createdFormatted = identity != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(identity.createdAt.toLocal())
        : 'Loading...';

    final lastScanFormatted = bleService?.lastScanTimestamp != null
        ? DateFormat('HH:mm:ss').format(bleService!.lastScanTimestamp!.toLocal())
        : 'No scan yet';

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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.meshCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (identity?.role.name ?? 'civilian').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.meshCyan,
                              ),
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
                            'Gateway Node',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (identity?.isGateway ?? false) ? 'Yes (Relay)' : 'No',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Protocol & Created At row
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

          // --------------------------------
          // LOCAL DTN STORAGE SECTION (Step 3)
          // --------------------------------
          const Text(
            'LOCAL DTN STORAGE',
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
                // Database Status Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Database Status',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: manager.isStorageReady
                            ? AppTheme.activeGreen.withValues(alpha: 0.15)
                            : AppTheme.alertAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: manager.isStorageReady ? AppTheme.activeGreen : AppTheme.alertAmber,
                        ),
                      ),
                      child: Text(
                        manager.isStorageReady ? 'READY' : 'INITIALIZING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: manager.isStorageReady ? AppTheme.activeGreen : AppTheme.alertAmber,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Metrics 2x2 Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Stored Messages',
                        value: manager.totalStoredCount.toString(),
                        color: AppTheme.meshCyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Active Messages',
                        value: manager.activeMessageCount.toString(),
                        color: AppTheme.activeGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Expired Messages',
                        value: manager.expiredMessageCount.toString(),
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Critical Messages',
                        value: manager.criticalMessageCount.toString(),
                        color: AppTheme.sosRed,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Development Action: Create Test Message & Purge Expired
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_alert_rounded, size: 16, color: AppTheme.sosRed),
                        label: const Text('Test SOS', style: TextStyle(fontSize: 12, color: AppTheme.sosRed)),
                        onPressed: () async {
                          await manager.createTestMessage();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Created test SOS message in local SQLite storage.'),
                                backgroundColor: AppTheme.cardBackground,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    if (manager.expiredMessageCount > 0) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppTheme.textMuted),
                          label: const Text('Purge Expired', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          onPressed: () async {
                            final deleted = await manager.purgeExpiredMessages();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Purged $deleted expired messages from SQLite.'),
                                  backgroundColor: AppTheme.cardBackground,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --------------------------------
          // BLE PEER DISCOVERY SECTION (Step 4)
          // --------------------------------
          const Text(
            'BLE PEER DISCOVERY',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('BLE Hardware', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      isAndroid ? 'Available' : 'Supported on Android',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isAndroid ? AppTheme.activeGreen : AppTheme.alertAmber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bluetooth Power', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      isAndroid ? (isBluetoothOn ? 'ON' : 'OFF') : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isBluetoothOn ? AppTheme.activeGreen : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Permissions', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      bleService?.scanStatus == BleScanStatus.permissionDenied ? 'Denied' : 'Granted/Checked',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: bleService?.scanStatus == BleScanStatus.permissionDenied
                            ? AppTheme.sosRed
                            : AppTheme.activeGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scanning', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      isScanning ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isScanning ? AppTheme.meshCyan : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ResQMesh Peers', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '${manager.activePeerCount}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.meshCyan),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Last Scan Result', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text(
                      lastScanFormatted,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const Divider(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(
                      isScanning ? Icons.stop_circle_outlined : Icons.sensors_outlined,
                      size: 16,
                      color: isScanning ? AppTheme.alertAmber : AppTheme.meshCyan,
                    ),
                    label: Text(
                      isScanning ? 'Stop BLE Scanning' : 'Scan for Peers',
                      style: TextStyle(color: isScanning ? AppTheme.alertAmber : AppTheme.meshCyan),
                    ),
                    onPressed: () async {
                      if (bleService != null) {
                        if (isScanning) {
                          await bleService.stopDiscovery();
                        } else {
                          await bleService.startDiscovery();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --------------------------------
          // MULTI-HOP DTN RELAY (Step 6)
          // --------------------------------
          const Text(
            'MULTI-HOP DTN RELAY',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Store-and-Forward Mode',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.activeGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'AUTONOMOUS RELAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.activeGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Waiting in Outbox',
                        value: '${relayMetrics.messagesWaiting}',
                        color: AppTheme.alertAmber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Hops Relayed',
                        value: '${relayMetrics.messagesRelayed}',
                        color: AppTheme.meshCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'ACK Confirmed',
                        value: '${relayMetrics.messagesDelivered}',
                        color: AppTheme.activeGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'Loops Prevented',
                        value: '${relayMetrics.duplicatesPrevented}',
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Routing parameters
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Max Observed Hop',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${relayMetrics.maxHopObserved} (Limit: ${AppConstants.maxHopCount})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Average Hop Count',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            relayMetrics.averageHopCount.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.meshCyan),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sweep Interval',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '${AppConstants.relaySchedulerIntervalSeconds}s (Opportunistic)',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Min Link RSSI',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '${AppConstants.minRelayRssi} dBm',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                      width: step.isActive ? 1.4 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: step.isActive
                              ? AppTheme.meshCyan.withValues(alpha: 0.15)
                              : const Color(0xFF161A22),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              step.subtitle,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
