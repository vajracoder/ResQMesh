import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../mesh/message_manager.dart';
import '../../mesh/models/emergency_type.dart';
import '../../mesh/models/mesh_message.dart';
import '../../responder/responder_service.dart';

/// Operational dashboard for Responder role nodes.
///
/// Visualizes incoming emergency bundles, triage states, and allows the operator
/// to dispatch authenticated RESPONDER_ACK signals across the mesh.
class ResponderDashboardScreen extends StatefulWidget {
  const ResponderDashboardScreen({super.key});

  @override
  State<ResponderDashboardScreen> createState() => _ResponderDashboardScreenState();
}

class _ResponderDashboardScreenState extends State<ResponderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ResponderService>(context, listen: false).loadExistingEmergencies();
    });
  }

  void _showTriageDialog(BuildContext context, ResponderEmergencyEntry entry) {
    final service = Provider.of<ResponderService>(context, listen: false);
    final notesController = TextEditingController(text: entry.responderNotes ?? '');
    ResponderTriageState selectedState = entry.triageState;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Triage: ${entry.message.emergencyType.displayName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Origin: ${entry.message.originNodeId}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 12),
                    const Text('Update Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButton<ResponderTriageState>(
                      value: selectedState,
                      isExpanded: true,
                      items: ResponderTriageState.values.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text(s.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedState = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Responder Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter field observations, units dispatched, etc.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    service.updateTriageState(
                      entry.message.messageId,
                      selectedState,
                      notes: notesController.text.trim(),
                    );
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _acknowledgeEmergency(ResponderEmergencyEntry entry) async {
    final messageManager = Provider.of<MessageManager>(context, listen: false);
    final responderService = Provider.of<ResponderService>(context, listen: false);

    try {
      // 1. Dispatch RESPONDER_ACK message across mesh
      await messageManager.sendResponderAck(
        targetMessageId: entry.message.messageId,
        originNodeId: entry.message.originNodeId,
      );

      // 2. Mark as acknowledged locally
      responderService.acknowledgeEmergency(
        entry.message.messageId,
        notes: 'Operator acknowledged at ${DateTime.now().toUtc().toIso8601String()}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal.shade800,
            content: Text('Dispatched RESPONDER_ACK to ${entry.message.originNodeId}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send ACK: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ResponderService>(
      builder: (context, service, _) {
        final emergencies = service.filteredEmergencies;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Responder Triage'),
            backgroundColor: Colors.blueGrey.shade900,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.loadExistingEmergencies(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Operator status banner
              Container(
                color: Colors.blueGrey.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'RESPONDER OPERATOR MODE — Active Mesh Monitoring',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Text(
                      '${service.highUrgencyCount} URGENT',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),

              // KPI Stats Header
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    _buildKpiCard('TOTAL', service.totalCount.toString(), Colors.blueGrey),
                    const SizedBox(width: 8),
                    _buildKpiCard('HIGH URGENCY', service.highUrgencyCount.toString(), Colors.red.shade800),
                    const SizedBox(width: 8),
                    _buildKpiCard('ACKNOWLEDGED', service.acknowledgedCount.toString(), Colors.teal.shade800),
                  ],
                ),
              ),

              // Filters Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: service.filterType == null && service.filterState == null,
                      onSelected: (_) => service.clearFilters(),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('SOS / Urgent'),
                      selected: service.filterType == EmergencyType.sos,
                      onSelected: (sel) => service.setFilterType(sel ? EmergencyType.sos : null),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('New Alerts'),
                      selected: service.filterState == ResponderTriageState.newAlert,
                      onSelected: (sel) => service.setFilterState(sel ? ResponderTriageState.newAlert : null),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('In Progress'),
                      selected: service.filterState == ResponderTriageState.inProgress,
                      onSelected: (sel) => service.setFilterState(sel ? ResponderTriageState.inProgress : null),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('Resolved'),
                      selected: service.filterState == ResponderTriageState.resolved,
                      onSelected: (sel) => service.setFilterState(sel ? ResponderTriageState.resolved : null),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // Emergencies List
              Expanded(
                child: emergencies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 12),
                            const Text(
                              'No active emergency alerts in queue',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Listening for incoming BLE mesh emergency broadcasts...',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: emergencies.length,
                        itemBuilder: (context, index) {
                          final entry = emergencies[index];
                          final msg = entry.message;
                          final isUrgent = msg.emergencyType.isHighUrgency;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: isUrgent ? 3 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isUrgent ? Colors.red.shade700 : Colors.grey.shade800,
                                width: isUrgent ? 1.5 : 0.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row with type, priority, and triage status
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isUrgent ? Colors.red.shade900 : Colors.blueGrey.shade800,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          msg.emergencyType.displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        msg.priority.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: msg.priority == MessagePriority.critical ? Colors.redAccent : Colors.grey,
                                        ),
                                      ),
                                      const Spacer(),
                                      _buildTriageChip(entry.triageState),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Emergency message payload
                                  Text(
                                    msg.payload,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),

                                  // Origin and metadata
                                  Row(
                                    children: [
                                      Icon(Icons.person_pin_circle_outlined, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        msg.originNodeId,
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.route, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hops: ${msg.hopCount}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                                      ),
                                    ],
                                  ),

                                  if (entry.responderNotes != null && entry.responderNotes!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Notes: ${entry.responderNotes}',
                                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.cyan.shade300),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Action buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => _showTriageDialog(context, entry),
                                        child: const Text('UPDATE STATUS'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: entry.triageState == ResponderTriageState.acknowledged
                                            ? null
                                            : () => _acknowledgeEmergency(entry),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal.shade800,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: Text(
                                          entry.triageState == ResponderTriageState.acknowledged ? 'ACKNOWLEDGED' : 'SEND ACK',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTriageChip(ResponderTriageState state) {
    Color color;
    switch (state) {
      case ResponderTriageState.newAlert:
        color = Colors.amber;
        break;
      case ResponderTriageState.acknowledged:
        color = Colors.teal;
        break;
      case ResponderTriageState.inProgress:
        color = Colors.blue;
        break;
      case ResponderTriageState.resolved:
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        state.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
