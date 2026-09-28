import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Discrete logged routing event in the physical mesh.
class RoutingEvent {
  final DateTime timestamp;
  final String eventType;
  final String? messageId;
  final String? peerId;
  final String details;

  RoutingEvent({
    DateTime? timestamp,
    required this.eventType,
    this.messageId,
    this.peerId,
    required this.details,
  }) : timestamp = (timestamp ?? DateTime.now().toUtc()).toUtc();

  String get formattedTime => DateFormat('HH:mm:ss').format(timestamp.toLocal());

  String get summary {
    final target = peerId != null ? ' [Peer: $peerId]' : '';
    final msg = messageId != null ? ' ($messageId)' : '';
    return '$formattedTime $eventType$msg$target: $details';
  }

  @override
  String toString() => summary;
}

/// In-memory circular buffer for logging intelligent DTN routing events.
class RoutingEventLog extends ChangeNotifier {
  final int capacity;
  final List<RoutingEvent> _events = [];

  RoutingEventLog({this.capacity = 150});

  List<RoutingEvent> get events => List.unmodifiable(_events);
  int get count => _events.length;

  void log({
    required String eventType,
    String? messageId,
    String? peerId,
    required String details,
  }) {
    final event = RoutingEvent(
      eventType: eventType,
      messageId: messageId,
      peerId: peerId,
      details: details,
    );

    _events.insert(0, event);

    if (_events.length > capacity) {
      _events.removeRange(capacity, _events.length);
    }

    notifyListeners();
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }
}
