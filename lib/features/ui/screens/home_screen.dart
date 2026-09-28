import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../mesh/message_manager.dart';
import '../widgets/emergency_header.dart';
import '../widgets/message_card.dart';
import '../widgets/status_card.dart';
import 'emergency_composer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _triggerSos(BuildContext context) {
    final textController = TextEditingController(text: 'Medical & rescue assistance urgently requested at this location.');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1214),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.sosRed, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.sosRed, size: 28),
              SizedBox(width: 10),
              Text(
                'BROADCAST SOS',
                style: TextStyle(
                  color: AppTheme.sosRed,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This emergency alert will be dispatched via offline mesh DTN Store-and-Forward to all reachable nodes.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF2C1619),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.sosRed),
                  ),
                  labelText: 'Emergency Details',
                  labelStyle: const TextStyle(color: AppTheme.textSecondary),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sosRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<MessageManager>().sendEmergencySos(
                  details: textController.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency SOS broadcast queued in offline DTN store!'),
                    backgroundColor: AppTheme.sosRed,
                  ),
                );
              },
              child: const Text('DISPATCH SOS NOW'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();
    final messages = manager.messages;

    return Scaffold(
      body: Column(
        children: [
          EmergencyHeader(
            nodeId: manager.localNodeId,
            activePeers: manager.activePeerCount,
            queuedMessages: manager.queuedMessageCount,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Prominent SOS Panic Button
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.sosRed.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Material(
                      color: AppTheme.sosRed,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _triggerSos(context),
                        child: Container(
                          width: 150,
                          height: 150,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sos_rounded, size: 48, color: Colors.white),
                              SizedBox(height: 4),
                              Text(
                                'BROADCAST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'TAP TO BROADCAST EMERGENCY ALERT OFFLINE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmergencyComposerScreen()),
                      );
                    },
                    icon: const Icon(Icons.emergency_outlined, size: 18),
                    label: const Text('CLASSIFIED EMERGENCY COMPOSER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: StatusCard(
                        icon: Icons.hub_outlined,
                        title: 'Nearby Peers',
                        value: '${manager.activePeerCount}',
                        accentColor: manager.activePeerCount > 0 ? AppTheme.activeGreen : AppTheme.textMuted,
                        subtitle: 'Step 4 enables BLE',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatusCard(
                        icon: Icons.all_inbox_outlined,
                        title: 'DTN Outbox',
                        value: '${manager.queuedMessageCount}',
                        accentColor: AppTheme.alertAmber,
                        subtitle: 'Awaiting forward',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent Broadcasts
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'RECENT TRANSMISSIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '${messages.length} total',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (messages.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.wifi_tethering_off, size: 36, color: AppTheme.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'No Emergency Transmissions Yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Dispatched SOS alerts and messages will be stored in DTN queue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ...messages.take(5).map((m) => MessageCard(message: m)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
