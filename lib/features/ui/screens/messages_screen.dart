import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../mesh/message_manager.dart';
import '../../mesh/models/mesh_message.dart';
import '../widgets/message_card.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: SOS, 2: Hazard, 3: Info, 4: Status, 5: Stored

  void _showComposeSheet(BuildContext context) {
    final textController = TextEditingController();
    MessageType selectedType = MessageType.info;
    MessagePriority selectedPriority = MessagePriority.normal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppTheme.cardBorder),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Compose DTN Bundle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MESSAGE TYPE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('SOS'),
                        selected: selectedType == MessageType.sos,
                        selectedColor: AppTheme.sosRed.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = MessageType.sos;
                              selectedPriority = MessagePriority.critical;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Hazard'),
                        selected: selectedType == MessageType.hazard,
                        selectedColor: AppTheme.alertAmber.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = MessageType.hazard;
                              selectedPriority = MessagePriority.high;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Info'),
                        selected: selectedType == MessageType.info,
                        selectedColor: AppTheme.meshCyan.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = MessageType.info;
                              selectedPriority = MessagePriority.normal;
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Status'),
                        selected: selectedType == MessageType.status,
                        selectedColor: AppTheme.textMuted.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedType = MessageType.status;
                              selectedPriority = MessagePriority.low;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'PRIORITY LEVEL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Critical'),
                        selected: selectedPriority == MessagePriority.critical,
                        selectedColor: AppTheme.sosRed.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedPriority = MessagePriority.critical);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('High'),
                        selected: selectedPriority == MessagePriority.high,
                        selectedColor: AppTheme.alertAmber.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedPriority = MessagePriority.high);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Normal'),
                        selected: selectedPriority == MessagePriority.normal,
                        selectedColor: AppTheme.meshCyan.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedPriority = MessagePriority.normal);
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Low'),
                        selected: selectedPriority == MessagePriority.low,
                        selectedColor: AppTheme.textMuted.withValues(alpha: 0.3),
                        onSelected: (val) {
                          if (val) setSheetState(() => selectedPriority = MessagePriority.low);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter emergency status, coordinates, or coordination update...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: const Color(0xFF121418),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('STORE IN LOCAL SQLITE DTN'),
                      onPressed: () {
                        final content = textController.text.trim();
                        if (content.isEmpty) return;
                        Navigator.of(ctx).pop();
                        context.read<MessageManager>().sendMessage(
                          content: content,
                          messageType: selectedType,
                          priority: selectedPriority,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message saved to local persistent SQLite storage.'),
                            backgroundColor: AppTheme.cardBackground,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<MessageManager>();
    final allMessages = manager.messages;

    final filteredMessages = allMessages.where((m) {
      if (_selectedFilterIndex == 1) return m.messageType == MessageType.sos || m.isSos;
      if (_selectedFilterIndex == 2) return m.messageType == MessageType.hazard;
      if (_selectedFilterIndex == 3) return m.messageType == MessageType.info;
      if (_selectedFilterIndex == 4) return m.messageType == MessageType.status;
      if (_selectedFilterIndex == 5) return m.status == MessageStatus.stored || m.status == MessageStatus.queued;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Messages'),
        actions: [
          IconButton(
            tooltip: 'Create Test Emergency SOS',
            icon: const Icon(Icons.add_alert_rounded, color: AppTheme.sosRed),
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
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _buildFilterChip(0, 'All (${allMessages.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'SOS (${allMessages.where((m) => m.messageType == MessageType.sos || m.isSos).length})'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Hazard (${allMessages.where((m) => m.messageType == MessageType.hazard).length})'),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Info (${allMessages.where((m) => m.messageType == MessageType.info).length})'),
                const SizedBox(width: 8),
                _buildFilterChip(4, 'Status (${allMessages.where((m) => m.messageType == MessageType.status).length})'),
                const SizedBox(width: 8),
                _buildFilterChip(5, 'Stored (${allMessages.where((m) => m.status == MessageStatus.stored || m.status == MessageStatus.queued).length})'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.meshCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Compose', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showComposeSheet(context),
      ),
      body: filteredMessages.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'No Messages in Storage',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ResQMesh stores all emergency messages in local SQLite offline. Use Compose or the Test SOS button above to create a message.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add_alert_rounded, color: AppTheme.sosRed, size: 18),
                      label: const Text('Generate Test SOS Message', style: TextStyle(color: AppTheme.sosRed)),
                      onPressed: () => manager.createTestMessage(),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredMessages.length,
              itemBuilder: (ctx, index) => MessageCard(message: filteredMessages[index]),
            ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.meshCyan.withValues(alpha: 0.2) : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.meshCyan : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.meshCyan : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
