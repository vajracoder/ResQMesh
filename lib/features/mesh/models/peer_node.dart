import '../../../core/constants/app_constants.dart';

/// State of local peer-to-peer BLE connection (Step 5).
enum PeerConnectionState {
  discovered,
  connecting,
  connected,
  discoveringServices,
  ready,
  sending,
  receiving,
  disconnecting,
  failed,
  disconnected,
}

/// Represents another physical node discovered via BLE in the ResQMesh network.
class PeerNode {
  final String nodeId;
  final String displayName;
  final int rssi; // Signal strength in dBm (e.g. -68)
  final DateTime lastSeen;
  final String protocolVersion;
  final PeerConnectionState connectionState;
  final bool isResQMeshPeer;
  final bool isDirectNeighbor;
  final String? deviceAddress; // Bluetooth MAC or system identifier for GATT connection

  PeerNode({
    String? nodeId,
    String? displayName,
    required this.rssi,
    required DateTime lastSeen,
    String? protocolVersion,
    this.connectionState = PeerConnectionState.discovered,
    this.isResQMeshPeer = true,
    this.isDirectNeighbor = true,
    this.deviceAddress,
    // Step 1 backwards-compatibility alias parameters:
    String? id,
    String? name,
  })  : nodeId = nodeId ?? id ?? '',
        displayName = displayName ?? name ?? '',
        lastSeen = lastSeen.toUtc(),
        protocolVersion = protocolVersion ?? AppConstants.protocolVersion;

  // Step 1 backwards-compatibility getters
  String get id => nodeId;
  String get name => displayName;
  String get shortId => nodeId.length > 12 ? '${nodeId.substring(0, 8)}...' : nodeId;

  /// Returns true if the peer has not been seen within [timeoutSeconds].
  bool isStale({DateTime? now, int timeoutSeconds = AppConstants.peerStaleTimeoutSeconds}) {
    if (timeoutSeconds <= 0) return true;
    final ref = (now ?? DateTime.now().toUtc()).toUtc();
    return ref.difference(lastSeen).inSeconds >= timeoutSeconds;
  }

  /// Evaluates whether the peer advertises an incompatible protocol version.
  bool hasProtocolMismatch({String expectedVersion = AppConstants.protocolVersion}) {
    return protocolVersion != expectedVersion;
  }

  PeerNode copyWith({
    String? nodeId,
    String? displayName,
    int? rssi,
    DateTime? lastSeen,
    String? protocolVersion,
    PeerConnectionState? connectionState,
    bool? isResQMeshPeer,
    bool? isDirectNeighbor,
    String? deviceAddress,
    // Legacy parameter aliases
    String? id,
    String? name,
  }) {
    return PeerNode(
      nodeId: nodeId ?? id ?? this.nodeId,
      displayName: displayName ?? name ?? this.displayName,
      rssi: rssi ?? this.rssi,
      lastSeen: lastSeen ?? this.lastSeen,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      connectionState: connectionState ?? this.connectionState,
      isResQMeshPeer: isResQMeshPeer ?? this.isResQMeshPeer,
      isDirectNeighbor: isDirectNeighbor ?? this.isDirectNeighbor,
      deviceAddress: deviceAddress ?? this.deviceAddress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': nodeId,
      'nodeId': nodeId,
      'name': displayName,
      'displayName': displayName,
      'rssi': rssi,
      'lastSeen': lastSeen.toIso8601String(),
      'protocolVersion': protocolVersion,
      'connectionState': connectionState.name,
      'isResQMeshPeer': isResQMeshPeer,
      'isDirectNeighbor': isDirectNeighbor,
      'deviceAddress': deviceAddress,
    };
  }

  factory PeerNode.fromMap(Map<String, dynamic> map) {
    return PeerNode(
      nodeId: (map['nodeId'] ?? map['id'] ?? '') as String,
      displayName: (map['displayName'] ?? map['name'] ?? '') as String,
      rssi: map['rssi'] as int? ?? -100,
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      protocolVersion: map['protocolVersion'] as String? ?? AppConstants.protocolVersion,
      connectionState: PeerConnectionState.values.firstWhere(
        (s) => s.name == map['connectionState'],
        orElse: () => PeerConnectionState.discovered,
      ),
      isResQMeshPeer: map['isResQMeshPeer'] as bool? ?? true,
      isDirectNeighbor: map['isDirectNeighbor'] as bool? ?? true,
      deviceAddress: map['deviceAddress'] as String?,
    );
  }
}
