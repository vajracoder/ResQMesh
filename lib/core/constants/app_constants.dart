/// Application wide constants for ResQMesh
class AppConstants {
  static const String appName = 'ResQMesh';
  static const String appTagline = 'Adaptive Offline Emergency Network';
  static const String appVersion = '1.0.0-foundation';

  // Network & Routing defaults
  static const int defaultTtlHops = 5;
  static const int defaultTtlHours = 24;
  static const String broadcastAddress = '*';

  // Storage keys (for Phase 2/3)
  static const String keyNodeId = 'resqmesh_node_id';
  static const String keyNodeName = 'resqmesh_node_name';
}
