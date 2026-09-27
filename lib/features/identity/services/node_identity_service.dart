import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../models/node_identity.dart';
import '../models/node_role.dart';
import '../repositories/node_identity_repository.dart';

/// Service managing the local persistent node identity for ResQMesh.
/// Ensures Node ID is generated once and strictly preserved across app/device restarts.
class NodeIdentityService extends ChangeNotifier {
  final NodeIdentityRepository repository;
  final Uuid _uuid;

  NodeIdentity? _identity;
  bool _isInitialized = false;
  String? _errorMessage;

  NodeIdentityService({
    required this.repository,
    Uuid? uuid,
  })  : _uuid = uuid ?? const Uuid();

  // --- Public State Getters ---

  /// Whether the identity has finished loading from persistent storage.
  bool get isInitialized => _isInitialized;

  /// Whether an unrecoverable storage error occurred while loading identity.
  bool get hasError => _errorMessage != null;

  /// Diagnostic error description if loading failed.
  String? get errorMessage => _errorMessage;

  /// The active [NodeIdentity], or null if not yet initialized or in error state.
  NodeIdentity? get identity => _identity;

  /// Current persistent Node ID formatted as `RQM-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
  /// Returns empty string if not yet initialized.
  String get currentNodeId => _identity?.nodeId ?? '';

  /// Loads stored identity or generates a fresh local identity on first launch.
  /// Strictly preserves existing identity and never silently regenerates on read failure.
  Future<NodeIdentity> initialize() async {
    _errorMessage = null;

    try {
      final existing = await repository.getIdentity();

      if (existing != null) {
        _identity = existing;
        _isInitialized = true;
        notifyListeners();
        return existing;
      }

      // First-time launch: generate new persistent identity
      final rawUuid = _uuid.v4();
      final generatedNodeId = 'RQM-$rawUuid';

      final freshIdentity = NodeIdentity(
        nodeId: generatedNodeId,
        displayName: 'ResQMesh Node',
        role: NodeRole.civilian,
        createdAt: DateTime.now().toUtc(),
        protocolVersion: AppConstants.protocolVersion,
        isGateway: false,
      );

      await repository.saveIdentity(freshIdentity);

      _identity = freshIdentity;
      _isInitialized = true;
      notifyListeners();
      return freshIdentity;
    } catch (e) {
      _errorMessage = 'Failed to load local node identity: $e';
      _isInitialized = false;
      notifyListeners();
      // Rethrow to allow callers/UI to handle error explicitly without silent data corruption
      rethrow;
    }
  }

  /// Updates the node's local display name.
  /// Crucially: does NOT alter the persistent Node ID.
  Future<void> updateDisplayName(String newName) async {
    final current = _identity;
    if (current == null) {
      throw StateError('Cannot update display name before NodeIdentityService is initialized.');
    }

    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }

    final updated = current.copyWith(displayName: trimmed);
    await repository.saveIdentity(updated);

    _identity = updated;
    notifyListeners();
  }

  /// Updates the node's prototype role.
  /// Crucially: does NOT alter the persistent Node ID.
  Future<void> updateRole(NodeRole newRole) async {
    final current = _identity;
    if (current == null) {
      throw StateError('Cannot update role before NodeIdentityService is initialized.');
    }

    final updated = current.copyWith(role: newRole);
    await repository.saveIdentity(updated);

    _identity = updated;
    notifyListeners();
  }

  /// Updates whether this node acts as a gateway.
  /// Crucially: does NOT alter the persistent Node ID.
  Future<void> updateGatewayStatus(bool isGateway) async {
    final current = _identity;
    if (current == null) {
      throw StateError('Cannot update gateway status before NodeIdentityService is initialized.');
    }

    final updated = current.copyWith(isGateway: isGateway);
    await repository.saveIdentity(updated);

    _identity = updated;
    notifyListeners();
  }
}
