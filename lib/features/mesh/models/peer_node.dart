/// Represents another discovered node in the ResQMesh network.
class PeerNode {
  final String id;
  final String name;
  final int rssi; // Signal strength in dBm (e.g. -70)
  final DateTime lastSeen;
  final bool isDirectNeighbor;

  const PeerNode({
    required this.id,
    required this.name,
    required this.rssi,
    required this.lastSeen,
    this.isDirectNeighbor = true,
  });

  String get shortId => id.length > 8 ? id.substring(0, 8) : id;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rssi': rssi,
      'lastSeen': lastSeen.toIso8601String(),
      'isDirectNeighbor': isDirectNeighbor,
    };
  }

  factory PeerNode.fromMap(Map<String, dynamic> map) {
    return PeerNode(
      id: map['id'] as String,
      name: map['name'] as String,
      rssi: map['rssi'] as int? ?? -100,
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      isDirectNeighbor: map['isDirectNeighbor'] as bool? ?? true,
    );
  }
}
