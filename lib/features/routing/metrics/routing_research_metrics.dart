import 'package:flutter/foundation.dart';

/// Real-time metrics collector for DTN routing research and field telemetry.
class RoutingResearchMetrics extends ChangeNotifier {
  int _messagesGenerated = 0;
  int _messagesForwarded = 0;
  int _messagesDelivered = 0;
  int _messagesExpired = 0;
  int _messagesDropped = 0;
  int _duplicateTransmissionsPrevented = 0;
  int _totalRetries = 0;
  int _currentQueueSize = 0;

  int _totalDecisionTimeMs = 0;
  int _decisionCount = 0;

  int _totalRelayDelayMs = 0;
  int _relayDelaySampleCount = 0;

  int _totalHops = 0;
  int _hopSampleCount = 0;

  int _totalRssi = 0;
  int _rssiSampleCount = 0;

  // Step 8: Emergency-specific DTN telemetry
  int _emergenciesCreated = 0;
  int _emergenciesReceivedByResponder = 0;
  int _gatewayReceipts = 0;
  int _responderAcknowledgements = 0;
  int _emergencyRelayCount = 0;
  int _emergencyExpirationCount = 0;
  int _totalEmergencyDeliveryDelayMs = 0;
  int _emergencyDeliveryDelayCount = 0;

  // Getters
  int get messagesGenerated => _messagesGenerated;
  int get messagesForwarded => _messagesForwarded;
  int get messagesDelivered => _messagesDelivered;
  int get messagesExpired => _messagesExpired;
  int get messagesDropped => _messagesDropped;
  int get duplicateTransmissionsPrevented => _duplicateTransmissionsPrevented;
  int get totalRetries => _totalRetries;
  int get currentQueueSize => _currentQueueSize;

  double get deliverySuccessRate => _messagesGenerated > 0
      ? _messagesDelivered / _messagesGenerated
      : 0.0;

  double get forwardingSuccessRate {
    final totalAttempts = _messagesForwarded + _messagesDropped;
    return totalAttempts > 0 ? _messagesForwarded / totalAttempts : 0.0;
  }

  double get averageDecisionTimeMs =>
      _decisionCount > 0 ? _totalDecisionTimeMs / _decisionCount : 0.0;

  double get averageRelayDelayMs => _relayDelaySampleCount > 0
      ? _totalRelayDelayMs / _relayDelaySampleCount
      : 0.0;

  double get averageHopCount =>
      _hopSampleCount > 0 ? _totalHops / _hopSampleCount : 0.0;

  double get averageRssi =>
      _rssiSampleCount > 0 ? _totalRssi / _rssiSampleCount : 0.0;

  double get duplicateSuppressionRate {
    final totalInquiries =
        _messagesForwarded + _duplicateTransmissionsPrevented;
    return totalInquiries > 0
        ? _duplicateTransmissionsPrevented / totalInquiries
        : 0.0;
  }

  double get expirationRate => _messagesGenerated > 0
      ? _messagesExpired / _messagesGenerated
      : 0.0;

  // Step 8 emergency telemetry getters
  int get emergenciesCreated => _emergenciesCreated;
  int get emergenciesReceivedByResponder => _emergenciesReceivedByResponder;
  int get gatewayReceipts => _gatewayReceipts;
  int get responderAcknowledgements => _responderAcknowledgements;
  int get emergencyRelayCount => _emergencyRelayCount;
  int get emergencyExpirationCount => _emergencyExpirationCount;

  double get averageEmergencyDeliveryDelayMs => _emergencyDeliveryDelayCount > 0
      ? _totalEmergencyDeliveryDelayMs / _emergencyDeliveryDelayCount
      : 0.0;

  // Mutators
  void recordGenerated() {
    _messagesGenerated++;
    notifyListeners();
  }

  void recordEmergencyCreated() {
    _emergenciesCreated++;
    notifyListeners();
  }

  void recordEmergencyReceivedByResponder() {
    _emergenciesReceivedByResponder++;
    notifyListeners();
  }

  void recordGatewayReceipt() {
    _gatewayReceipts++;
    notifyListeners();
  }

  void recordResponderAck() {
    _responderAcknowledgements++;
    notifyListeners();
  }

  void recordEmergencyRelayed() {
    _emergencyRelayCount++;
    notifyListeners();
  }

  void recordEmergencyExpired() {
    _emergencyExpirationCount++;
    notifyListeners();
  }

  void recordEmergencyDeliveryDelay(int delayMs) {
    if (delayMs >= 0) {
      _totalEmergencyDeliveryDelayMs += delayMs;
      _emergencyDeliveryDelayCount++;
      notifyListeners();
    }
  }

  void recordForwarded(int hopCount, {int? rssi}) {
    _messagesForwarded++;
    _totalHops += hopCount;
    _hopSampleCount++;
    if (rssi != null) {
      _totalRssi += rssi;
      _rssiSampleCount++;
    }
    notifyListeners();
  }

  void recordDelivered({int? delayMs}) {
    _messagesDelivered++;
    if (delayMs != null && delayMs >= 0) {
      _totalRelayDelayMs += delayMs;
      _relayDelaySampleCount++;
    }
    notifyListeners();
  }

  void recordExpired() {
    _messagesExpired++;
    notifyListeners();
  }

  void recordDropped() {
    _messagesDropped++;
    notifyListeners();
  }

  void recordDuplicatePrevented() {
    _duplicateTransmissionsPrevented++;
    notifyListeners();
  }

  void recordRetry() {
    _totalRetries++;
    notifyListeners();
  }

  void updateQueueSize(int size) {
    if (_currentQueueSize != size) {
      _currentQueueSize = size;
      notifyListeners();
    }
  }

  void recordDecisionTime(int elapsedMs) {
    _totalDecisionTimeMs += elapsedMs;
    _decisionCount++;
    notifyListeners();
  }

  void reset() {
    _messagesGenerated = 0;
    _messagesForwarded = 0;
    _messagesDelivered = 0;
    _messagesExpired = 0;
    _messagesDropped = 0;
    _duplicateTransmissionsPrevented = 0;
    _totalRetries = 0;
    _currentQueueSize = 0;
    _totalDecisionTimeMs = 0;
    _decisionCount = 0;
    _totalRelayDelayMs = 0;
    _relayDelaySampleCount = 0;
    _totalHops = 0;
    _hopSampleCount = 0;
    _totalRssi = 0;
    _rssiSampleCount = 0;
    _emergenciesCreated = 0;
    _emergenciesReceivedByResponder = 0;
    _gatewayReceipts = 0;
    _responderAcknowledgements = 0;
    _emergencyRelayCount = 0;
    _emergencyExpirationCount = 0;
    _totalEmergencyDeliveryDelayMs = 0;
    _emergencyDeliveryDelayCount = 0;
    notifyListeners();
  }

  Map<String, dynamic> toMap() => {
        'messagesGenerated': _messagesGenerated,
        'messagesForwarded': _messagesForwarded,
        'messagesDelivered': _messagesDelivered,
        'messagesExpired': _messagesExpired,
        'messagesDropped': _messagesDropped,
        'duplicateTransmissionsPrevented': _duplicateTransmissionsPrevented,
        'totalRetries': _totalRetries,
        'currentQueueSize': _currentQueueSize,
        'deliverySuccessRate': deliverySuccessRate,
        'forwardingSuccessRate': forwardingSuccessRate,
        'averageDecisionTimeMs': averageDecisionTimeMs,
        'averageRelayDelayMs': averageRelayDelayMs,
        'averageHopCount': averageHopCount,
        'averageRssi': averageRssi,
        'duplicateSuppressionRate': duplicateSuppressionRate,
        'expirationRate': expirationRate,
        'emergenciesCreated': _emergenciesCreated,
        'emergenciesReceivedByResponder': _emergenciesReceivedByResponder,
        'gatewayReceipts': _gatewayReceipts,
        'responderAcknowledgements': _responderAcknowledgements,
        'emergencyRelayCount': _emergencyRelayCount,
        'emergencyExpirationCount': _emergencyExpirationCount,
        'averageEmergencyDeliveryDelayMs': averageEmergencyDeliveryDelayMs,
      };
}
