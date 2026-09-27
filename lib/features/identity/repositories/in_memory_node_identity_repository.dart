import '../models/node_identity.dart';
import 'node_identity_repository.dart';

/// In-memory implementation of [NodeIdentityRepository] for testing and transient isolation.
class InMemoryNodeIdentityRepository implements NodeIdentityRepository {
  NodeIdentity? _storedIdentity;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;

  InMemoryNodeIdentityRepository([this._storedIdentity]);

  @override
  Future<NodeIdentity?> getIdentity() async {
    if (shouldThrowOnRead) {
      throw const NodeIdentityStorageException('Simulated storage read failure');
    }
    return _storedIdentity;
  }

  @override
  Future<void> saveIdentity(NodeIdentity identity) async {
    if (shouldThrowOnWrite) {
      throw const NodeIdentityStorageException('Simulated storage write failure');
    }
    _storedIdentity = identity;
  }

  @override
  Future<void> clearIdentity() async {
    _storedIdentity = null;
  }
}
