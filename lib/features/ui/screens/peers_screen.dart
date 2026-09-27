import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../discovery/ble_discovery_service.dart';
import '../../mesh/message_manager.dart';
import '../../mesh/models/peer_node.dart';
import '../../transport/ble_transport.dart';

class PeersScreen extends StatelessWidget {
  const PeersScreen({super.key});

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().toUtc().difference(lastSeen).inSeconds;
    if (diff <= 1) return 'Just now';
    if (diff < 60) return '$diff sec ago';
    return '${diff ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();
    final bleService = context.watch<BleDiscoveryService?>();
    final bleTransport = context.watch<BleTransport?>();
    final peers = manager.peers;

    final isAndroid = !kIsWeb && Platform.isAndroid;
    final isScanning = bleService?.isDiscovering ?? manager.discoveryService.isDiscovering;

    final bluetoothState = bleService?.hardwareState ?? BleHardwareState.unknown;
    final isBluetoothOn = bluetoothState == BleHardwareState.poweredOn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Nodes & Peers'),
        actions: [
          IconButton(
            tooltip: isScanning ? 'Stop BLE Scanning' : 'Start BLE Scanning',
            icon: Icon(
              isScanning ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
              color: isScanning ? AppTheme.alertAmber : AppTheme.meshCyan,
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
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // BLE Hardware & Discovery Status Card
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
                const Row(
                  children: [
                    Icon(Icons.bluetooth_audio_rounded, size: 18, color: AppTheme.meshCyan),
                    SizedBox(width: 8),
                    Text(
                      'BLUETOOTH LOW ENERGY DISCOVERY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Status Indicators Row
                Row(
                  children: [
                    // Bluetooth Status
                    Expanded(
                      child: _buildStatusPill(
                        label: 'Bluetooth',
                        value: isAndroid
                            ? (isBluetoothOn ? 'ON' : 'OFF')
                            : 'SUPPORTED ON ANDROID',
                        isActive: isAndroid && isBluetoothOn,
                        activeColor: AppTheme.activeGreen,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Discovery Status
                    Expanded(
                      child: _buildStatusPill(
                        label: 'Discovery',
                        value: isScanning ? 'SCANNING' : 'IDLE',
                        isActive: isScanning,
                        activeColor: AppTheme.meshCyan,
                      ),
                    ),
                  ],
                ),

                if (!isAndroid) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B202A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppTheme.meshCyan),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'BLE discovery is supported on physical Android devices. No fake peers are generated.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (bleService?.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1518),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.sosRed.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.sosRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bleService!.errorMessage!,
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Discovered Peers Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${peers.length} ${peers.length == 1 ? "PEER" : "PEERS"} NEARBY',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              if (isScanning)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.meshCyan),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Peers List or Clean Empty State
          if (peers.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13171F),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching_rounded,
                      size: 32,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No ResQMesh peers found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scanning for nearby physical devices running ResQMesh. When another node is within BLE range, it will appear here with its Node ID and signal strength.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                  ),
                ],
              ),
            )
          else
            ...peers.map((peer) => _buildPeerCard(context, peer, bleTransport)),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required bool isActive,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10141C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? activeColor : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? activeColor : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeerCard(BuildContext context, PeerNode peer, BleTransport? bleTransport) {
    final hasMismatch = peer.hasProtocolMismatch();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasMismatch ? AppTheme.alertAmber.withValues(alpha: 0.6) : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.meshCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_android_rounded, color: AppTheme.meshCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.name.isNotEmpty ? peer.name : 'ResQMesh Node',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      peer.nodeId,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppTheme.meshCyan,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConnectionBadge(peer, bleTransport),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(Icons.network_wifi_rounded, size: 14, color: _rssiColor(peer.rssi)),
              const SizedBox(width: 4),
              Text(
                '${peer.rssi} dBm',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _rssiColor(peer.rssi),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(
                _formatLastSeen(peer.lastSeen),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const Spacer(),
              if (hasMismatch)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.alertAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Proto ${peer.protocolVersion}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.alertAmber, fontWeight: FontWeight.bold),
                  ),
                ),
              _buildConnectButton(context, peer, bleTransport),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBadge(PeerNode peer, BleTransport? transport) {
    final state = transport?.getConnectionState(peer.nodeId) ?? peer.connectionState;
    Color badgeColor = AppTheme.textMuted;
    String badgeText = 'Discovered';

    switch (state) {
      case PeerConnectionState.ready:
      case PeerConnectionState.connected:
        badgeColor = AppTheme.activeGreen;
        badgeText = '● Connected';
        break;
      case PeerConnectionState.connecting:
      case PeerConnectionState.discoveringServices:
        badgeColor = AppTheme.alertAmber;
        badgeText = '● Connecting';
        break;
      case PeerConnectionState.sending:
        badgeColor = AppTheme.meshCyan;
        badgeText = '● Sending';
        break;
      case PeerConnectionState.receiving:
        badgeColor = AppTheme.meshCyan;
        badgeText = '● Receiving';
        break;
      case PeerConnectionState.failed:
        badgeColor = AppTheme.sosRed;
        badgeText = '● Failed';
        break;
      case PeerConnectionState.disconnecting:
        badgeColor = AppTheme.textMuted;
        badgeText = '● Disconnecting';
        break;
      case PeerConnectionState.discovered:
      case PeerConnectionState.disconnected:
        badgeColor = AppTheme.textMuted;
        badgeText = 'Discovered';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: badgeColor,
        ),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context, PeerNode peer, BleTransport? transport) {
    final state = transport?.getConnectionState(peer.nodeId) ?? peer.connectionState;
    final isConnected = state == PeerConnectionState.ready || state == PeerConnectionState.connected;
    final isConnecting = state == PeerConnectionState.connecting ||
        state == PeerConnectionState.discoveringServices ||
        state == PeerConnectionState.sending;

    if (isConnecting) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.meshCyan),
      );
    }

    if (isConnected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              side: const BorderSide(color: AppTheme.cardBorder),
            ),
            onPressed: () => transport?.disconnect(peer.nodeId),
            child: const Text('Disconnect', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
        ],
      );
    }

    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 28),
        backgroundColor: AppTheme.meshCyan.withValues(alpha: 0.15),
      ),
      onPressed: () => transport?.connect(peer),
      child: const Text('Connect', style: TextStyle(fontSize: 11, color: AppTheme.meshCyan, fontWeight: FontWeight.bold)),
    );
  }

  Color _rssiColor(int rssi) {
    if (rssi >= -65) return AppTheme.activeGreen;
    if (rssi >= -80) return AppTheme.alertAmber;
    return AppTheme.sosRed;
  }
}
