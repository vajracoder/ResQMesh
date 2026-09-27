/// Application wide constants for ResQMesh
class AppConstants {
  static const String appName = 'ResQMesh';
  static const String appTagline = 'Adaptive Offline Emergency Network';
  static const String appVersion = '1.0.0-foundation';
  static const String protocolVersion = '1.0';

  // Network & Routing defaults
  static const int defaultTtlHops = 5;
  static const int defaultTtlHours = 24;
  static const String broadcastAddress = '*';

  // Storage keys
  static const String keyNodeIdentity = 'resqmesh_node_identity';
  static const String keyNodeId = 'resqmesh_node_id';
  static const String keyNodeName = 'resqmesh_node_name';

  // BLE Protocol & Discovery constants (Step 4 & Step 5)
  /// Dedicated 128-bit BLE Service UUID for ResQMesh network discovery and transport.
  static const String bleServiceUuid = 'a7e4b9d0-3f12-4c6e-8d5a-1b8f6c4e2a01';

  /// ResQMesh BLE Characteristic for Outgoing / Message TX (central writes, peripheral receives)
  static const String bleCharacteristicTxUuid = 'a7e4b9d0-3f12-4c6e-8d5a-1b8f6c4e2a02';

  /// ResQMesh BLE Characteristic for Incoming / Message RX (peripheral notifies central)
  static const String bleCharacteristicRxUuid = 'a7e4b9d0-3f12-4c6e-8d5a-1b8f6c4e2a03';

  /// Manufacturer identifier prefix (ASCII 'R', 'Q' = 0x5251)
  static const int bleManufacturerId = 0x5251;

  /// Duration after which an unseen peer is considered stale and removed from active list.
  static const int peerStaleTimeoutSeconds = 15;

  /// Scanning active cycle duration in seconds to balance discovery and battery consumption.
  static const int bleScanDurationSeconds = 10;

  /// Max payload size per BLE fragment to guarantee fitting within negotiated MTU (typically 128-256).
  static const int bleMaxFragmentPayloadSize = 128;

  /// Timeout after which incomplete fragment assemblies are evicted from memory to prevent leaks.
  static const int fragmentAssemblyTimeoutSeconds = 30;

  /// Timeout for establishing a BLE GATT connection.
  static const int bleConnectionTimeoutSeconds = 15;

  /// Timeout for awaiting an application-level ACK after transmission.
  static const int bleAckTimeoutSeconds = 8;
}
