/// Classified emergency types supported in ResQMesh emergency mesh bundles.
///
/// Emergency type is stored in [MeshMessage] and used for responder filtering
/// and routing priority decisions. It never confers authoritative trust — trust
/// model is documented as prototype-only.
enum EmergencyType {
  sos,
  medical,
  fire,
  trapped,
  missingPerson,
  hazard,
  generalEmergency,
  info;

  String get displayName {
    switch (this) {
      case EmergencyType.sos:
        return 'SOS';
      case EmergencyType.medical:
        return 'MEDICAL';
      case EmergencyType.fire:
        return 'FIRE';
      case EmergencyType.trapped:
        return 'TRAPPED';
      case EmergencyType.missingPerson:
        return 'MISSING PERSON';
      case EmergencyType.hazard:
        return 'HAZARD';
      case EmergencyType.generalEmergency:
        return 'GENERAL EMERGENCY';
      case EmergencyType.info:
        return 'INFO';
    }
  }

  /// Returns true if this is a high-urgency emergency type requiring
  /// priority routing consideration.
  bool get isHighUrgency {
    switch (this) {
      case EmergencyType.sos:
      case EmergencyType.trapped:
      case EmergencyType.medical:
      case EmergencyType.fire:
        return true;
      default:
        return false;
    }
  }

  static EmergencyType fromString(String? value) {
    if (value == null) return EmergencyType.info;
    return EmergencyType.values.firstWhere(
      (t) => t.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EmergencyType.info,
    );
  }
}

/// Distinguishes the semantic meaning of a BLE-layer ACK.
///
/// PEER_ACK:      A neighboring node has stored the bundle.
/// RESPONDER_ACK: A responder device/operator has acknowledged receipt.
/// GATEWAY_ACK:   A gateway node has stored the bundle in its inbox.
///
/// These are distinct acknowledgement semantics and must never be conflated.
/// None of these imply that external emergency services were notified.
enum AckType {
  peerAck,
  responderAck,
  gatewayAck;

  String get displayName {
    switch (this) {
      case AckType.peerAck:
        return 'PEER ACK';
      case AckType.responderAck:
        return 'RESPONDER ACK';
      case AckType.gatewayAck:
        return 'GATEWAY ACK';
    }
  }

  static AckType fromString(String? value) {
    if (value == null) return AckType.peerAck;
    return AckType.values.firstWhere(
      (t) => t.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AckType.peerAck,
    );
  }
}
