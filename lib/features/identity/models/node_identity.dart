import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import 'node_role.dart';

/// Represents the persistent local cryptographic identity of a ResQMesh node.
class NodeIdentity {
  final String nodeId;
  final String displayName;
  final NodeRole role;
  final DateTime createdAt;
  final String protocolVersion;
  final bool isGateway;

  const NodeIdentity({
    required this.nodeId,
    this.displayName = 'ResQMesh Node',
    this.role = NodeRole.civilian,
    required this.createdAt,
    this.protocolVersion = AppConstants.protocolVersion,
    this.isGateway = false,
  });

  /// Creates a copy with specified fields updated while strictly preserving identity integrity.
  NodeIdentity copyWith({
    String? displayName,
    NodeRole? role,
    bool? isGateway,
    String? protocolVersion,
  }) {
    return NodeIdentity(
      nodeId: nodeId, // nodeId must never be altered via copyWith
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      createdAt: createdAt, // createdAt is immutable
      protocolVersion: protocolVersion ?? this.protocolVersion,
      isGateway: isGateway ?? this.isGateway,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nodeId': nodeId,
      'displayName': displayName,
      'role': role.displayName,
      'createdAt': createdAt.toIso8601String(),
      'protocolVersion': protocolVersion,
      'isGateway': isGateway,
    };
  }

  factory NodeIdentity.fromMap(Map<String, dynamic> map) {
    return NodeIdentity(
      nodeId: map['nodeId'] as String,
      displayName: map['displayName'] as String? ?? 'ResQMesh Node',
      role: NodeRole.fromString(map['role'] as String?),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now().toUtc(),
      protocolVersion: map['protocolVersion'] as String? ?? AppConstants.protocolVersion,
      isGateway: map['isGateway'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NodeIdentity.fromJson(String source) =>
      NodeIdentity.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NodeIdentity &&
        other.nodeId == nodeId &&
        other.displayName == displayName &&
        other.role == role &&
        other.createdAt == createdAt &&
        other.protocolVersion == protocolVersion &&
        other.isGateway == isGateway;
  }

  @override
  int get hashCode {
    return Object.hash(
      nodeId,
      displayName,
      role,
      createdAt,
      protocolVersion,
      isGateway,
    );
  }

  @override
  String toString() {
    return 'NodeIdentity(nodeId: $nodeId, displayName: $displayName, role: ${role.displayName}, isGateway: $isGateway)';
  }
}
