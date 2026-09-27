import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../mesh/models/mesh_message.dart';

class MessageCard extends StatelessWidget {
  final MeshMessage message;

  const MessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSos = message.isSos;
    final timeStr = DateFormat('HH:mm:ss').format(message.timestamp.toLocal());

    Color priorityColor;
    String priorityText;
    switch (message.priority) {
      case MessagePriority.critical:
        priorityColor = AppTheme.sosRed;
        priorityText = 'CRITICAL SOS';
        break;
      case MessagePriority.high:
        priorityColor = AppTheme.alertAmber;
        priorityText = 'URGENT HAZARD';
        break;
      case MessagePriority.normal:
        priorityColor = AppTheme.meshCyan;
        priorityText = 'STANDARD';
        break;
      case MessagePriority.low:
        priorityColor = AppTheme.textMuted;
        priorityText = 'BEACON';
        break;
    }

    Color statusColor;
    String statusText;
    switch (message.status) {
      case MessageStatus.sending:
        statusColor = AppTheme.alertAmber;
        statusText = 'SENDING';
        break;
      case MessageStatus.sentToPeer:
        statusColor = AppTheme.meshCyan;
        statusText = 'SENT TO PEER';
        break;
      case MessageStatus.deliveredToPeer:
      case MessageStatus.delivered:
        statusColor = AppTheme.activeGreen;
        statusText = 'DELIVERED TO PEER';
        break;
      case MessageStatus.queued:
        statusColor = AppTheme.alertAmber;
        statusText = 'QUEUED';
        break;
      case MessageStatus.received:
        statusColor = AppTheme.activeGreen;
        statusText = 'RECEIVED';
        break;
      case MessageStatus.stored:
        statusColor = AppTheme.meshCyan;
        statusText = 'STORED';
        break;
      case MessageStatus.forwarding:
        statusColor = AppTheme.alertAmber;
        statusText = 'FORWARDING';
        break;
      case MessageStatus.forwarded:
        statusColor = AppTheme.activeGreen;
        statusText = 'FORWARDED';
        break;
      case MessageStatus.draft:
        statusColor = AppTheme.textMuted;
        statusText = 'DRAFT';
        break;
      case MessageStatus.expired:
        statusColor = AppTheme.textMuted;
        statusText = 'EXPIRED';
        break;
      case MessageStatus.failed:
        statusColor = AppTheme.sosRed;
        statusText = 'FAILED';
        break;
    }

    final originShort = message.originNodeId.length > 12
        ? '${message.originNodeId.substring(0, 10)}...'
        : message.originNodeId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSos ? const Color(0xFF241417) : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSos ? AppTheme.sosRed.withValues(alpha: 0.5) : AppTheme.cardBorder,
          width: isSos ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: priorityColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  priorityText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: priorityColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (message.isBroadcast)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2838),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.podcasts, size: 10, color: AppTheme.meshCyan),
                      SizedBox(width: 4),
                      Text(
                        'BROADCAST',
                        style: TextStyle(fontSize: 9, color: AppTheme.meshCyan, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.content,
            style: TextStyle(
              fontSize: 14,
              color: isSos ? Colors.white : AppTheme.textPrimary,
              fontWeight: isSos ? FontWeight.w600 : FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 13, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
              ),
              if (originShort.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(
                  '• Origin: $originShort',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
              const Spacer(),
              Text(
                'Hops: ${message.hopCount}/${message.maxHops}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'ID: ${message.messageId.length > 20 ? "${message.messageId.substring(0, 16)}..." : message.messageId} • Sender: ${message.senderNodeId.length > 16 ? "${message.senderNodeId.substring(0, 14)}..." : message.senderNodeId}',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
