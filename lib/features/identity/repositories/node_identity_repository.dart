import '../models/node_identity.dart';

/// Exception thrown when low-level storage operations fail.
class NodeIdentityStorageException implements Exception {
  final String message;
  final dynamic cause;

  const NodeIdentityStorageException(this.message, [this.cause]);

  @override
  String toString() => 'NodeIdentityStorageException: $message ${cause != null ? '($cause)' : ''}';
}

/// Abstract contract for persisting and retrieving local Node Identity.
abstract class NodeIdentityRepository {
  /// Loads saved identity from local persistence.
  /// Returns null if this is a first-time launch and no identity exists yet.
  /// Throws [NodeIdentityStorageException] if storage is corrupted or unreadable.
  Future<NodeIdentity?> getIdentity();

  /// Persists [identity] to local storage.
  /// Throws [NodeIdentityStorageException] if writing fails.
  Future<void> saveIdentity(NodeIdentity identity);

  /// Clears stored identity (used primarily in tests or factory reset).
  Future<void> clearIdentity();
}
