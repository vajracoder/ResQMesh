import 'package:flutter/foundation.dart';

/// Tracks runtime metrics and statistics for Delay/Disruption Tolerant
/// Multi-Hop Relay operations.
class RelayMetrics extends ChangeNotifier {
  int _messagesStored = 0;
  int _messagesWaiting = 0;
  int _messagesRelayed = 0;
  int _messagesDelivered = 0;
  int _messagesExpired = 0;
  int _duplicatesPrevented = 0;
  int _messagesFailed = 0;
  int _currentRelayPeers = 0;
  int _totalHopsRelayed = 0;
  int _maxHopObserved = 0;

  int get messagesStored => _messagesStored;
  int get messagesWaiting => _messagesWaiting;
  int get messagesRelayed => _messagesRelayed;
  int get messagesDelivered => _messagesDelivered;
  int get messagesExpired => _messagesExpired;
  int get duplicatesPrevented => _duplicatesPrevented;
  int get messagesFailed => _messagesFailed;
  int get currentRelayPeers => _currentRelayPeers;
  int get maxHopObserved => _maxHopObserved;

  double get averageHopCount => _messagesRelayed > 0
      ? _totalHopsRelayed / _messagesRelayed
      : 0.0;

  void recordStored() {
    _messagesStored++;
    notifyListeners();
  }

  void updateWaitingCount(int count) {
    if (_messagesWaiting != count) {
      _messagesWaiting = count;
      notifyListeners();
    }
  }

  void recordRelayed(int hopCount) {
    _messagesRelayed++;
    _totalHopsRelayed += hopCount;
    if (hopCount > _maxHopObserved) {
      _maxHopObserved = hopCount;
    }
    notifyListeners();
  }

  void recordDelivered() {
    _messagesDelivered++;
    notifyListeners();
  }

  void recordExpired() {
    _messagesExpired++;
    notifyListeners();
  }

  void recordDuplicatePrevented() {
    _duplicatesPrevented++;
    notifyListeners();
  }

  void recordFailed() {
    _messagesFailed++;
    notifyListeners();
  }

  void updateRelayPeerCount(int count) {
    if (_currentRelayPeers != count) {
      _currentRelayPeers = count;
      notifyListeners();
    }
  }

  void reset() {
    _messagesStored = 0;
    _messagesWaiting = 0;
    _messagesRelayed = 0;
    _messagesDelivered = 0;
    _messagesExpired = 0;
    _duplicatesPrevented = 0;
    _messagesFailed = 0;
    _currentRelayPeers = 0;
    _totalHopsRelayed = 0;
    _maxHopObserved = 0;
    notifyListeners();
  }

  Map<String, dynamic> toMap() => {
        'messagesStored': _messagesStored,
        'messagesWaiting': _messagesWaiting,
        'messagesRelayed': _messagesRelayed,
        'messagesDelivered': _messagesDelivered,
        'messagesExpired': _messagesExpired,
        'duplicatesPrevented': _duplicatesPrevented,
        'messagesFailed': _messagesFailed,
        'currentRelayPeers': _currentRelayPeers,
        'averageHopCount': averageHopCount,
        'maxHopObserved': _maxHopObserved,
      };
}
