/// Prototype role for a ResQMesh node.
/// Note: Role selection is a local configuration value and does not confer authoritative permissions.
enum NodeRole {
  civilian,
  responder,
  gateway,
  command;

  String get displayName {
    switch (this) {
      case NodeRole.civilian:
        return 'CIVILIAN';
      case NodeRole.responder:
        return 'RESPONDER';
      case NodeRole.gateway:
        return 'GATEWAY';
      case NodeRole.command:
        return 'COMMAND';
    }
  }

  static NodeRole fromString(String? value) {
    if (value == null) return NodeRole.civilian;
    return NodeRole.values.firstWhere(
      (r) => r.name.toUpperCase() == value.toUpperCase(),
      orElse: () => NodeRole.civilian,
    );
  }
}
