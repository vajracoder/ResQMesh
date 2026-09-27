import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/node_identity.dart';
import 'node_identity_repository.dart';

/// Implementation of [NodeIdentityRepository] backed by SharedPreferences (Android local storage).
class SharedPrefsNodeIdentityRepository implements NodeIdentityRepository {
  final SharedPreferences? _prefsInstance;

  SharedPrefsNodeIdentityRepository([this._prefsInstance]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  @override
  Future<NodeIdentity?> getIdentity() async {
    try {
      final prefs = await _getPrefs();
      final rawJson = prefs.getString(AppConstants.keyNodeIdentity);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return null;
      }
      return NodeIdentity.fromJson(rawJson);
    } catch (e, stack) {
      throw NodeIdentityStorageException(
        'Failed to read persistent node identity from local storage: $e',
        stack,
      );
    }
  }

  @override
  Future<void> saveIdentity(NodeIdentity identity) async {
    try {
      final prefs = await _getPrefs();
      final success = await prefs.setString(
        AppConstants.keyNodeIdentity,
        identity.toJson(),
      );

      if (!success) {
        throw const NodeIdentityStorageException('SharedPreferences write returned false');
      }

      // Sync secondary diagnostic keys
      await prefs.setString(AppConstants.keyNodeId, identity.nodeId);
      await prefs.setString(AppConstants.keyNodeName, identity.displayName);
    } catch (e, stack) {
      if (e is NodeIdentityStorageException) rethrow;
      throw NodeIdentityStorageException(
        'Failed to save node identity to local storage: $e',
        stack,
      );
    }
  }

  @override
  Future<void> clearIdentity() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(AppConstants.keyNodeIdentity);
      await prefs.remove(AppConstants.keyNodeId);
      await prefs.remove(AppConstants.keyNodeName);
    } catch (e, stack) {
      throw NodeIdentityStorageException('Failed to clear stored node identity: $e', stack);
    }
  }
}
