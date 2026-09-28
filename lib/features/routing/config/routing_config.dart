import '../../../core/constants/app_constants.dart';

/// Configurable transmission and relay policy for Intelligent DTN Routing.
enum ForwardingPolicy {
  /// Strictly forward only when candidate peer is the exact final destination.
  directOnly,

  /// Controlled multi-hop forwarding: evaluate peer utility scores and dispatch
  /// to the top-scoring candidate peers up to [RoutingConfig.maxRelayFanout].
  controlledRelay,

  /// Aggressive prioritization: prioritize CRITICAL and SOS messages, holding
  /// NORMAL and INFO messages when network/battery resources are constrained.
  priorityRelay,
}

/// Centralized configuration model for Step 7 Intelligent DTN Routing Engine.
///
/// Contains all tuning parameters, mathematical weights, thresholds, and limits
/// to avoid magic numbers scattered across the codebase.
class RoutingConfig {
  /// Active forwarding policy (directOnly, controlledRelay, priorityRelay).
  final ForwardingPolicy forwardingPolicy;

  /// Absolute maximum hops allowed before a bundle must be dropped.
  final int maximumHops;

  /// Default time-to-live for newly created bundles (seconds).
  final int defaultTTL;

  /// Minimum remaining TTL (seconds) required for a bundle to be considered for relay.
  final int minTtlForRelaySeconds;

  /// Maximum transmission retries per bundle per peer before deprioritizing.
  final int maxRetries;

  /// Base backoff delay between transmission retry attempts (milliseconds).
  final int retryBaseDelayMs;

  /// Maximum number of messages kept in storage before intelligent eviction.
  final int storageLimit;

  /// Maximum number of candidate peers to relay a single bundle to per sweep.
  final int maxRelayFanout;

  // --- Urgency Calculation Weights ---
  final int sosWeight;
  final int criticalWeight;
  final int highWeight;
  final int normalWeight;
  final int infoWeight;
  final double ttlUrgencyThresholdRatio;
  final int ttlMaxBoost;
  final int hopPenalty;

  // --- Peer Scoring Weights (must sum to ~1.0) ---
  /// Weight given to RF signal strength (RSSI).
  final double rssiWeight;

  /// Weight given to how recently the peer was encountered.
  final double recencyWeight;

  /// Weight given to historical delivery/ACK success rate with this peer.
  final double historyWeight;

  /// Weight given to peer node role and gateway capabilities.
  final double roleWeight;

  /// Minimum RSSI (dBm) threshold for a peer to be eligible.
  final int minRssiThreshold;

  /// Reference best RSSI (dBm) representing full signal quality (1.0).
  final int maxRssiReference;

  /// Bonus added to peer score if the peer is the direct intended recipient.
  final double destinationMatchBonus;

  /// Extra scoring bonus given to Responder nodes when evaluating emergency bundles.
  final double responderEmergencyBonus;

  /// Extra scoring bonus given to Gateway nodes when evaluating emergency bundles.
  final double gatewayEmergencyBonus;

  const RoutingConfig({
    this.forwardingPolicy = ForwardingPolicy.controlledRelay,
    this.maximumHops = AppConstants.maxHopCount,
    this.defaultTTL = 86400,
    this.minTtlForRelaySeconds = AppConstants.minTtlForRelaySeconds,
    this.maxRetries = AppConstants.maxRelayRetriesPerPeer,
    this.retryBaseDelayMs = 2000,
    this.storageLimit = 500,
    this.maxRelayFanout = 3,
    this.sosWeight = 1000,
    this.criticalWeight = 800,
    this.highWeight = 500,
    this.normalWeight = 200,
    this.infoWeight = 100,
    this.ttlUrgencyThresholdRatio = 0.25,
    this.ttlMaxBoost = 300,
    this.hopPenalty = 10,
    this.rssiWeight = 0.30,
    this.recencyWeight = 0.20,
    this.historyWeight = 0.25,
    this.roleWeight = 0.25,
    this.minRssiThreshold = AppConstants.minRelayRssi,
    this.maxRssiReference = -40,
    this.destinationMatchBonus = 50.0,
    this.responderEmergencyBonus = 25.0,
    this.gatewayEmergencyBonus = 20.0,
  });

  RoutingConfig copyWith({
    ForwardingPolicy? forwardingPolicy,
    int? maximumHops,
    int? defaultTTL,
    int? minTtlForRelaySeconds,
    int? maxRetries,
    int? retryBaseDelayMs,
    int? storageLimit,
    int? maxRelayFanout,
    int? sosWeight,
    int? criticalWeight,
    int? highWeight,
    int? normalWeight,
    int? infoWeight,
    double? ttlUrgencyThresholdRatio,
    int? ttlMaxBoost,
    int? hopPenalty,
    double? rssiWeight,
    double? recencyWeight,
    double? historyWeight,
    double? roleWeight,
    int? minRssiThreshold,
    int? maxRssiReference,
    double? destinationMatchBonus,
    double? responderEmergencyBonus,
    double? gatewayEmergencyBonus,
  }) {
    return RoutingConfig(
      forwardingPolicy: forwardingPolicy ?? this.forwardingPolicy,
      maximumHops: maximumHops ?? this.maximumHops,
      defaultTTL: defaultTTL ?? this.defaultTTL,
      minTtlForRelaySeconds:
          minTtlForRelaySeconds ?? this.minTtlForRelaySeconds,
      maxRetries: maxRetries ?? this.maxRetries,
      retryBaseDelayMs: retryBaseDelayMs ?? this.retryBaseDelayMs,
      storageLimit: storageLimit ?? this.storageLimit,
      maxRelayFanout: maxRelayFanout ?? this.maxRelayFanout,
      sosWeight: sosWeight ?? this.sosWeight,
      criticalWeight: criticalWeight ?? this.criticalWeight,
      highWeight: highWeight ?? this.highWeight,
      normalWeight: normalWeight ?? this.normalWeight,
      infoWeight: infoWeight ?? this.infoWeight,
      ttlUrgencyThresholdRatio:
          ttlUrgencyThresholdRatio ?? this.ttlUrgencyThresholdRatio,
      ttlMaxBoost: ttlMaxBoost ?? this.ttlMaxBoost,
      hopPenalty: hopPenalty ?? this.hopPenalty,
      rssiWeight: rssiWeight ?? this.rssiWeight,
      recencyWeight: recencyWeight ?? this.recencyWeight,
      historyWeight: historyWeight ?? this.historyWeight,
      roleWeight: roleWeight ?? this.roleWeight,
      minRssiThreshold: minRssiThreshold ?? this.minRssiThreshold,
      maxRssiReference: maxRssiReference ?? this.maxRssiReference,
      destinationMatchBonus:
          destinationMatchBonus ?? this.destinationMatchBonus,
      responderEmergencyBonus:
          responderEmergencyBonus ?? this.responderEmergencyBonus,
      gatewayEmergencyBonus:
          gatewayEmergencyBonus ?? this.gatewayEmergencyBonus,
    );
  }

  Map<String, dynamic> toMap() => {
        'forwardingPolicy': forwardingPolicy.name,
        'maximumHops': maximumHops,
        'defaultTTL': defaultTTL,
        'minTtlForRelaySeconds': minTtlForRelaySeconds,
        'maxRetries': maxRetries,
        'retryBaseDelayMs': retryBaseDelayMs,
        'storageLimit': storageLimit,
        'maxRelayFanout': maxRelayFanout,
        'sosWeight': sosWeight,
        'criticalWeight': criticalWeight,
        'highWeight': highWeight,
        'normalWeight': normalWeight,
        'infoWeight': infoWeight,
        'ttlUrgencyThresholdRatio': ttlUrgencyThresholdRatio,
        'ttlMaxBoost': ttlMaxBoost,
        'hopPenalty': hopPenalty,
        'rssiWeight': rssiWeight,
        'recencyWeight': recencyWeight,
        'historyWeight': historyWeight,
        'roleWeight': roleWeight,
        'minRssiThreshold': minRssiThreshold,
        'maxRssiReference': maxRssiReference,
        'destinationMatchBonus': destinationMatchBonus,
        'responderEmergencyBonus': responderEmergencyBonus,
        'gatewayEmergencyBonus': gatewayEmergencyBonus,
      };

  factory RoutingConfig.fromMap(Map<String, dynamic> map) {
    return RoutingConfig(
      forwardingPolicy: ForwardingPolicy.values.firstWhere(
        (p) => p.name == map['forwardingPolicy'],
        orElse: () => ForwardingPolicy.controlledRelay,
      ),
      maximumHops: map['maximumHops'] as int? ?? AppConstants.maxHopCount,
      defaultTTL: map['defaultTTL'] as int? ?? 86400,
      minTtlForRelaySeconds: map['minTtlForRelaySeconds'] as int? ??
          AppConstants.minTtlForRelaySeconds,
      maxRetries: map['maxRetries'] as int? ??
          AppConstants.maxRelayRetriesPerPeer,
      retryBaseDelayMs: map['retryBaseDelayMs'] as int? ?? 2000,
      storageLimit: map['storageLimit'] as int? ?? 500,
      maxRelayFanout: map['maxRelayFanout'] as int? ?? 3,
      sosWeight: map['sosWeight'] as int? ?? 1000,
      criticalWeight: map['criticalWeight'] as int? ?? 800,
      highWeight: map['highWeight'] as int? ?? 500,
      normalWeight: map['normalWeight'] as int? ?? 200,
      infoWeight: map['infoWeight'] as int? ?? 100,
      ttlUrgencyThresholdRatio:
          (map['ttlUrgencyThresholdRatio'] as num?)?.toDouble() ?? 0.25,
      ttlMaxBoost: map['ttlMaxBoost'] as int? ?? 300,
      hopPenalty: map['hopPenalty'] as int? ?? 10,
      rssiWeight: (map['rssiWeight'] as num?)?.toDouble() ?? 0.30,
      recencyWeight: (map['recencyWeight'] as num?)?.toDouble() ?? 0.20,
      historyWeight: (map['historyWeight'] as num?)?.toDouble() ?? 0.25,
      roleWeight: (map['roleWeight'] as num?)?.toDouble() ?? 0.25,
      minRssiThreshold:
          map['minRssiThreshold'] as int? ?? AppConstants.minRelayRssi,
      maxRssiReference: map['maxRssiReference'] as int? ?? -40,
      destinationMatchBonus:
          (map['destinationMatchBonus'] as num?)?.toDouble() ?? 50.0,
      responderEmergencyBonus:
          (map['responderEmergencyBonus'] as num?)?.toDouble() ?? 25.0,
      gatewayEmergencyBonus:
          (map['gatewayEmergencyBonus'] as num?)?.toDouble() ?? 20.0,
    );
  }
}
