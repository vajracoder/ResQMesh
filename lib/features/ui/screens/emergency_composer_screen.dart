import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mesh/message_manager.dart';
import '../../mesh/models/emergency_type.dart';
import '../../mesh/models/mesh_message.dart';

/// Screen enabling rapid composition and broadcast of classified emergency mesh bundles.
class EmergencyComposerScreen extends StatefulWidget {
  const EmergencyComposerScreen({super.key});

  @override
  State<EmergencyComposerScreen> createState() => _EmergencyComposerScreenState();
}

class _EmergencyComposerScreenState extends State<EmergencyComposerScreen> {
  final _contentController = TextEditingController();
  EmergencyType _selectedType = EmergencyType.sos;
  MessagePriority _selectedPriority = MessagePriority.critical;
  bool _isSending = false;

  final List<String> _quickPresets = [
    'Immediate rescue needed at current location',
    'Medical emergency: severe injury, need first aid',
    'Structure fire / smoke hazard observed',
    'Trapped under debris / blocked exit',
    'Missing person last seen nearby',
    'Severe road block / structural collapse hazard',
  ];

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _sendEmergency() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter emergency details or select a preset')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final messageManager = Provider.of<MessageManager>(context, listen: false);
      final msg = await messageManager.sendMessage(
        content: text,
        messageType: (_selectedPriority == MessagePriority.critical || _selectedType == EmergencyType.sos)
            ? MessageType.sos
            : MessageType.hazard,
        priority: _selectedPriority,
        emergencyType: _selectedType,
        recipientId: '*', // Mesh broadcast
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(
              'Emergency broadcast dispatched: ${msg.messageId.substring(0, 16)}...',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dispatch emergency: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Emergency'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Prominent offline transparency disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber.shade300, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'OFFLINE MESH TRANSMISSION ONLY\nThis broadcast reaches nearby ResQMesh nodes via BLE. External authorities (911/EMS) are NOT automatically notified.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Emergency Type Selector
            const Text(
              'EMERGENCY CLASSIFICATION',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmergencyType.values.where((t) => t != EmergencyType.info).map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(type.displayName),
                  selected: isSelected,
                  selectedColor: Colors.red.shade800,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedType = type;
                        if (type.isHighUrgency) {
                          _selectedPriority = MessagePriority.critical;
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Priority Selector
            const Text(
              'TRANSMISSION PRIORITY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            SegmentedButton<MessagePriority>(
              segments: const [
                ButtonSegment(
                  value: MessagePriority.critical,
                  label: Text('CRITICAL'),
                  icon: Icon(Icons.flash_on, color: Colors.red),
                ),
                ButtonSegment(
                  value: MessagePriority.high,
                  label: Text('HIGH'),
                  icon: Icon(Icons.priority_high, color: Colors.orange),
                ),
                ButtonSegment(
                  value: MessagePriority.normal,
                  label: Text('NORMAL'),
                  icon: Icon(Icons.info_outline),
                ),
              ],
              selected: {_selectedPriority},
              onSelectionChanged: (set) {
                setState(() => _selectedPriority = set.first);
              },
            ),
            const SizedBox(height: 20),

            // Quick Presets
            const Text(
              'QUICK PRESETS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickPresets.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(preset, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _contentController.text = preset;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Message Content Field
            const Text(
              'EMERGENCY SITUATION DETAILS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe exact location, condition, number of persons, hazards...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendEmergency,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.emergency_share, size: 24),
              label: Text(
                _isSending ? 'BROADCASTING VIA BLE...' : 'BROADCAST EMERGENCY ALERT',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
