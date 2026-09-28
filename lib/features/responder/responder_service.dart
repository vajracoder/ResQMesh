import 'package:flutter/foundation.dart';
import '../mesh/models/emergency_type.dart';
import '../mesh/models/mesh_message.dart';
import '../storage/repositories/dtn_message_repository.dart';

/// Status of an emergency within the responder triage workflow.
enum ResponderTriageState {
  newAlert,
  acknowledged,
  inProgress,
  resolved,
}

/// Information tracking responder actions taken on a received emergency bundle.
class ResponderEmergencyEntry {
  final MeshMessage message;
  final ResponderTriageState triageState;
  final DateTime receivedAt;
  final DateTime? acknowledgedAt;
  final String? responderNotes;

  const ResponderEmergencyEntry({
    required this.message,
    this.triageState = ResponderTriageState.newAlert,
    required this.receivedAt,
    this.acknowledgedAt,
    this.responderNotes,
  });

  ResponderEmergencyEntry copyWith({
    MeshMessage? message,
    ResponderTriageState? triageState,
    DateTime? receivedAt,
    DateTime? acknowledgedAt,
    String? responderNotes,
  }) {
    return ResponderEmergencyEntry(
      message: message ?? this.message,
      triageState: triageState ?? this.triageState,
      receivedAt: receivedAt ?? this.receivedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      responderNotes: responderNotes ?? this.responderNotes,
    );
  }
}

/// Service managing emergency bundles received by a Responder node.
///
/// Provides filtering, triage state tracking, and operator acknowledgment hooks.
/// Does not simulate network results or external authorities.
class ResponderService with ChangeNotifier {
  final DtnMessageRepository repository;
  final Map<String, ResponderEmergencyEntry> _emergencies = {};

  EmergencyType? _filterType;
  MessagePriority? _filterPriority;
  ResponderTriageState? _filterState;

  ResponderService({
    required this.repository,
  });

  // Getters
  List<ResponderEmergencyEntry> get allEmergencies =>
      List.unmodifiable(_emergencies.values.toList()..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)));

  List<ResponderEmergencyEntry> get filteredEmergencies {
    return _emergencies.values.where((entry) {
      if (_filterType != null && entry.message.emergencyType != _filterType) {
        return false;
      }
      if (_filterPriority != null && entry.message.priority != _filterPriority) {
        return false;
      }
      if (_filterState != null && entry.triageState != _filterState) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        // High urgency first, then newest
        final aUrgent = a.message.emergencyType.isHighUrgency ? 1 : 0;
        final bUrgent = b.message.emergencyType.isHighUrgency ? 1 : 0;
        if (aUrgent != bUrgent) return bUrgent.compareTo(aUrgent);
        return b.receivedAt.compareTo(a.receivedAt);
      });
  }

  int get totalCount => _emergencies.length;
  int get activeEmergencyCount =>
      _emergencies.values.where((e) => e.triageState != ResponderTriageState.resolved).length;
  int get highUrgencyCount =>
      _emergencies.values.where((e) => e.message.emergencyType.isHighUrgency && e.triageState != ResponderTriageState.resolved).length;
  int get acknowledgedCount =>
      _emergencies.values.where((e) => e.triageState == ResponderTriageState.acknowledged || e.acknowledgedAt != null).length;

  EmergencyType? get filterType => _filterType;
  MessagePriority? get filterPriority => _filterPriority;
  ResponderTriageState? get filterState => _filterState;

  void setFilterType(EmergencyType? type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterPriority(MessagePriority? priority) {
    _filterPriority = priority;
    notifyListeners();
  }

  void setFilterState(ResponderTriageState? state) {
    _filterState = state;
    notifyListeners();
  }

  void clearFilters() {
    _filterType = null;
    _filterPriority = null;
    _filterState = null;
    notifyListeners();
  }

  /// Ingests an incoming emergency message into the responder queue.
  void ingestEmergency(MeshMessage message) {
    if (_emergencies.containsKey(message.messageId)) {
      // Update message content if existing
      final existing = _emergencies[message.messageId]!;
      _emergencies[message.messageId] = existing.copyWith(message: message);
    } else {
      _emergencies[message.messageId] = ResponderEmergencyEntry(
        message: message,
        triageState: ResponderTriageState.newAlert,
        receivedAt: DateTime.now().toUtc(),
      );
    }
    notifyListeners();
  }

  /// Sets the triage state of an emergency bundle.
  void updateTriageState(String messageId, ResponderTriageState newState, {String? notes}) {
    final existing = _emergencies[messageId];
    if (existing == null) return;

    DateTime? ackTime = existing.acknowledgedAt;
    if (newState == ResponderTriageState.acknowledged && ackTime == null) {
      ackTime = DateTime.now().toUtc();
    }

    _emergencies[messageId] = existing.copyWith(
      triageState: newState,
      acknowledgedAt: ackTime,
      responderNotes: notes ?? existing.responderNotes,
    );
    notifyListeners();
  }

  /// Marks the emergency as acknowledged by the responder operator.
  void acknowledgeEmergency(String messageId, {String? notes}) {
    updateTriageState(messageId, ResponderTriageState.acknowledged, notes: notes);
  }

  /// Loads existing emergency messages from repository on startup.
  Future<void> loadExistingEmergencies() async {
    try {
      final messages = await repository.getAllMessages();
      for (final msg in messages) {
        if (msg.isSos || msg.emergencyType.isHighUrgency || msg.priority == MessagePriority.critical) {
          if (!_emergencies.containsKey(msg.messageId)) {
            _emergencies[msg.messageId] = ResponderEmergencyEntry(
              message: msg,
              triageState: ResponderTriageState.newAlert,
              receivedAt: msg.createdAt,
            );
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }
}
