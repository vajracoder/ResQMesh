import 'package:flutter/foundation.dart';
import '../mesh/models/mesh_message.dart';
import '../responder/emergency_handoff_service.dart';
import '../storage/repositories/dtn_message_repository.dart';

/// Explicit lifecycle states for bundles received at a ResQMesh Gateway node.
enum GatewayMessageState {
  newBundle,
  acknowledged,
  inReview,
  forwarded,
  resolved;

  String get displayName {
    switch (this) {
      case GatewayMessageState.newBundle:
        return 'NEW';
      case GatewayMessageState.acknowledged:
        return 'ACKNOWLEDGED';
      case GatewayMessageState.inReview:
        return 'IN REVIEW';
      case GatewayMessageState.forwarded:
        return 'FORWARDED';
      case GatewayMessageState.resolved:
        return 'RESOLVED';
    }
  }
}

/// Represents an emergency bundle stored within the Gateway inbox.
class GatewayInboxEntry {
  final MeshMessage message;
  final GatewayMessageState state;
  final DateTime receivedAt;
  final DateTime? stateUpdatedAt;
  final String? operatorNotes;
  final HandoffStatus handoffStatus;

  const GatewayInboxEntry({
    required this.message,
    this.state = GatewayMessageState.newBundle,
    required this.receivedAt,
    this.stateUpdatedAt,
    this.operatorNotes,
    this.handoffStatus = HandoffStatus.externalNotConnected,
  });

  GatewayInboxEntry copyWith({
    MeshMessage? message,
    GatewayMessageState? state,
    DateTime? receivedAt,
    DateTime? stateUpdatedAt,
    String? operatorNotes,
    HandoffStatus? handoffStatus,
  }) {
    return GatewayInboxEntry(
      message: message ?? this.message,
      state: state ?? this.state,
      receivedAt: receivedAt ?? this.receivedAt,
      stateUpdatedAt: stateUpdatedAt ?? this.stateUpdatedAt,
      operatorNotes: operatorNotes ?? this.operatorNotes,
      handoffStatus: handoffStatus ?? this.handoffStatus,
    );
  }
}

/// Service managing the Gateway node inbox and bundle lifecycle states.
///
/// Ensures transparent status tracking for messages reaching edge gateways.
/// Reminds operators that prototype handoffs remain offline ("external authorities NOT notified").
class GatewayInboxService with ChangeNotifier {
  final DtnMessageRepository repository;
  final EmergencyHandoffService handoffService;
  final Map<String, GatewayInboxEntry> _inbox = {};

  GatewayInboxService({
    required this.repository,
    required this.handoffService,
  });

  List<GatewayInboxEntry> get entries =>
      List.unmodifiable(_inbox.values.toList()..sort((a, b) => b.receivedAt.compareTo(a.receivedAt)));

  int get totalCount => _inbox.length;
  int get newCount => _inbox.values.where((e) => e.state == GatewayMessageState.newBundle).length;
  int get inReviewCount => _inbox.values.where((e) => e.state == GatewayMessageState.inReview).length;
  int get resolvedCount => _inbox.values.where((e) => e.state == GatewayMessageState.resolved).length;

  List<GatewayInboxEntry> getEntriesByState(GatewayMessageState state) {
    return _inbox.values.where((e) => e.state == state).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  /// Ingests a message received by the gateway node.
  void ingestMessage(MeshMessage message) {
    if (_inbox.containsKey(message.messageId)) {
      final existing = _inbox[message.messageId]!;
      _inbox[message.messageId] = existing.copyWith(message: message);
    } else {
      _inbox[message.messageId] = GatewayInboxEntry(
        message: message,
        state: GatewayMessageState.newBundle,
        receivedAt: DateTime.now().toUtc(),
        handoffStatus: HandoffStatus.externalNotConnected,
        operatorNotes: 'Ready for external handoff — external dispatch NOT connected',
      );
      // Register with handoff service
      handoffService.prepareHandoff(message, notes: 'Ingested at gateway');
    }
    notifyListeners();
  }

  /// Updates the workflow state of a gateway bundle.
  void updateState(String messageId, GatewayMessageState newState, {String? notes}) {
    final existing = _inbox[messageId];
    if (existing == null) return;

    _inbox[messageId] = existing.copyWith(
      state: newState,
      stateUpdatedAt: DateTime.now().toUtc(),
      operatorNotes: notes ?? existing.operatorNotes,
    );
    notifyListeners();
  }

  /// Loads existing messages from repository into gateway inbox.
  Future<void> loadExistingMessages() async {
    try {
      final messages = await repository.getAllMessages();
      for (final msg in messages) {
        if (!_inbox.containsKey(msg.messageId)) {
          _inbox[msg.messageId] = GatewayInboxEntry(
            message: msg,
            state: GatewayMessageState.newBundle,
            receivedAt: msg.createdAt,
            handoffStatus: HandoffStatus.externalNotConnected,
            operatorNotes: 'Loaded from local storage — external dispatch NOT connected',
          );
        }
      }
      notifyListeners();
    } catch (_) {}
  }
}
