import 'package:flutter/foundation.dart';
import '../mesh/models/mesh_message.dart';

/// Status of an emergency bundle handoff to external authorities.
///
/// In this prototype architecture, external systems are NEVER connected.
/// Handoffs remain in [externalNotConnected] or [readyForHandoff] status
/// to ensure complete transparency and prevent false safety assumptions.
enum HandoffStatus {
  notStarted,
  readyForHandoff,
  externalNotConnected,
  completed,
}

/// A persistent or memory record describing the external handoff state of an emergency bundle.
class HandoffRecord {
  final String messageId;
  final HandoffStatus status;
  final DateTime timestamp;
  final String targetSystem;
  final String notes;

  const HandoffRecord({
    required this.messageId,
    required this.status,
    required this.timestamp,
    required this.targetSystem,
    required this.notes,
  });

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
    'targetSystem': targetSystem,
    'notes': notes,
  };
}

/// Abstract contract for emergency bundle handoff services.
///
/// Designed so that in a production deployment, this interface can be implemented
/// by satellite backhaul, FirstNet cellular uplink, or municipal dispatch APIs
/// without modifying mesh routing or core DTN logic.
abstract class EmergencyHandoffService extends ChangeNotifier {
  /// Evaluates and prepares an emergency bundle for handoff.
  Future<bool> prepareHandoff(MeshMessage message, {String notes});

  /// Queries the current handoff status of a specific emergency bundle.
  HandoffStatus getHandoffStatus(String messageId);

  /// Retrieves all handoff records.
  List<HandoffRecord> getHandoffRecords();
}

/// Local offline prototype implementation of [EmergencyHandoffService].
///
/// Explicitly maintains an offline handoff buffer where bundles are marked
/// [HandoffStatus.externalNotConnected] or [HandoffStatus.readyForHandoff].
/// Never fakes delivery to police, fire, or EMS.
class LocalEmergencyHandoffService extends EmergencyHandoffService {
  final Map<String, HandoffRecord> _records = {};

  @override
  Future<bool> prepareHandoff(MeshMessage message, {String notes = 'Queued in local gateway buffer'}) async {
    _records[message.messageId] = HandoffRecord(
      messageId: message.messageId,
      status: HandoffStatus.readyForHandoff,
      timestamp: DateTime.now().toUtc(),
      targetSystem: 'LOCAL_OFFLINE_BUFFER',
      notes: '$notes (External dispatch NOT connected — mesh only)',
    );
    notifyListeners();
    return true;
  }

  @override
  HandoffStatus getHandoffStatus(String messageId) {
    final record = _records[messageId];
    if (record == null) return HandoffStatus.notStarted;
    return record.status;
  }

  @override
  List<HandoffRecord> getHandoffRecords() {
    return List.unmodifiable(_records.values.toList());
  }

  /// Marks a bundle as specifically noting that external networks are unavailable.
  void markExternalUnavailable(String messageId) {
    _records[messageId] = HandoffRecord(
      messageId: messageId,
      status: HandoffStatus.externalNotConnected,
      timestamp: DateTime.now().toUtc(),
      targetSystem: 'OFFLINE_GATEWAY',
      notes: 'No external uplink available (prototype mode)',
    );
    notifyListeners();
  }
}
