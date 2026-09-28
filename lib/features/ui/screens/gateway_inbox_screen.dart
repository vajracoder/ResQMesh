import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../gateway/gateway_inbox_service.dart';
import '../../mesh/models/mesh_message.dart';
import '../../responder/emergency_handoff_service.dart';

/// Screen providing edge gateway operators with bundle inbox management,
/// workflow status transitions, and external handoff state monitoring.
class GatewayInboxScreen extends StatefulWidget {
  const GatewayInboxScreen({super.key});

  @override
  State<GatewayInboxScreen> createState() => _GatewayInboxScreenState();
}

class _GatewayInboxScreenState extends State<GatewayInboxScreen> {
  GatewayMessageState? _selectedFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GatewayInboxService>(context, listen: false).loadExistingMessages();
    });
  }

  void _showStateDialog(BuildContext context, GatewayInboxEntry entry) {
    final service = Provider.of<GatewayInboxService>(context, listen: false);
    final notesController = TextEditingController(text: entry.operatorNotes ?? '');
    GatewayMessageState selected = entry.state;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Gateway Bundle State'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bundle ID: ${entry.message.messageId.substring(0, 16)}...'),
                  const SizedBox(height: 12),
                  const Text('Workflow State:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<GatewayMessageState>(
                    value: selected,
                    isExpanded: true,
                    items: GatewayMessageState.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selected = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Operator / Handoff Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Notes regarding backhaul, radio dispatch, etc.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    service.updateState(
                      entry.message.messageId,
                      selected,
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

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayInboxService>(
      builder: (context, inboxService, _) {
        final entries = _selectedFilter == null
            ? inboxService.entries
            : inboxService.getEntriesByState(_selectedFilter!);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Gateway Inbox'),
            backgroundColor: Colors.indigo.shade900,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => inboxService.loadExistingMessages(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Mandatory external handoff status banner
              Container(
                color: Colors.indigo.shade800,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'EDGE GATEWAY OFFLINE BUFFER\nExternal authorities NOT notified. Bundles are stored in local SQLite DTN buffer awaiting physical backhaul or dispatch.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

              // KPI Bar
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    _buildKpi('TOTAL INBOX', inboxService.totalCount.toString(), Colors.indigo),
                    const SizedBox(width: 8),
                    _buildKpi('NEW', inboxService.newCount.toString(), Colors.amber.shade800),
                    const SizedBox(width: 8),
                    _buildKpi('IN REVIEW', inboxService.inReviewCount.toString(), Colors.blue.shade700),
                    const SizedBox(width: 8),
                    _buildKpi('RESOLVED', inboxService.resolvedCount.toString(), Colors.green.shade800),
                  ],
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _selectedFilter == null,
                      onSelected: (_) => setState(() => _selectedFilter = null),
                    ),
                    const SizedBox(width: 6),
                    ...GatewayMessageState.values.map((state) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: FilterChip(
                          label: Text(state.displayName),
                          selected: _selectedFilter == state,
                          onSelected: (sel) => setState(() => _selectedFilter = sel ? state : null),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(),

              // Entries List
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 12),
                            const Text(
                              'Gateway inbox is empty',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Incoming mesh bundles collected by this gateway will appear here.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final msg = entry.message;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row: Type badge, state chip
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: msg.isSos ? Colors.red.shade900 : Colors.indigo.shade900,
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
                                      _buildStateChip(entry.state),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Payload
                                  Text(
                                    msg.payload,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),

                                  // Metadata: Origin, Hops
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text(
                                        'From: ${msg.originNodeId}',
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
                                  const SizedBox(height: 8),

                                  // Handoff Status Tag
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade900.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.orange.shade800),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.radio_button_checked, size: 12, color: Colors.orange.shade300),
                                        const SizedBox(width: 6),
                                        Text(
                                          entry.handoffStatus == HandoffStatus.readyForHandoff
                                              ? 'READY FOR HANDOFF (Offline Buffer)'
                                              : 'EXTERNAL NOT CONNECTED (Mesh Only)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  if (entry.operatorNotes != null && entry.operatorNotes!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Notes: ${entry.operatorNotes}',
                                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blue.shade200),
                                    ),
                                  ],
                                  const SizedBox(height: 10),

                                  // Action
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showStateDialog(context, entry),
                                        icon: const Icon(Icons.edit, size: 14),
                                        label: const Text('MANAGE STATE'),
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

  Widget _buildKpi(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStateChip(GatewayMessageState state) {
    Color color;
    switch (state) {
      case GatewayMessageState.newBundle:
        color = Colors.amber;
        break;
      case GatewayMessageState.acknowledged:
        color = Colors.teal;
        break;
      case GatewayMessageState.inReview:
        color = Colors.blue;
        break;
      case GatewayMessageState.forwarded:
        color = Colors.purple;
        break;
      case GatewayMessageState.resolved:
        color = Colors.green;
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
        state.displayName,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
