import '../../mesh/models/mesh_message.dart';
import '../exceptions/storage_exceptions.dart';
import 'dtn_message_repository.dart';

/// In-memory implementation of [DtnMessageRepository] for testing and simulation.
class InMemoryDtnMessageRepository implements DtnMessageRepository {
  final Map<String, MeshMessage> _store = {};
  bool _isInitialized = false;

  /// Simulation flags for error handling tests
  bool shouldThrowOnInit = false;
  bool shouldThrowOnRead = false;
  bool shouldThrowOnWrite = false;

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw const DatabaseNotInitializedException();
    }
  }

  @override
  Future<void> init() async {
    if (shouldThrowOnInit) {
      throw const DtnStorageException('Simulated storage initialization failure');
    }
    _isInitialized = true;
  }

  @override
  Future<void> createMessage(MeshMessage message) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    if (_store.containsKey(message.messageId)) {
      throw DuplicateMessageException(message.messageId);
    }
    _store[message.messageId] = message;
  }

  @override
  Future<MeshMessage?> getMessageById(String messageId) async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    return _store[messageId];
  }

  @override
  Future<List<MeshMessage>> getAllMessages() async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    final list = _store.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MeshMessage>> getMessagesByStatus(MessageStatus status) async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    final list = _store.values.where((m) => m.status == status).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MeshMessage>> getMessagesByPriority(MessagePriority priority) async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    final list = _store.values.where((m) => m.priority == priority).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MeshMessage>> getActiveMessages({DateTime? now}) async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    final ref = (now ?? DateTime.now().toUtc()).toUtc();
    final list = _store.values.where((m) => !m.isExpired(referenceTime: ref)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<MeshMessage>> getExpiredMessages({DateTime? now}) async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    final ref = (now ?? DateTime.now().toUtc()).toUtc();
    final list = _store.values.where((m) => m.isExpired(referenceTime: ref)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> updateMessage(MeshMessage message) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    if (!_store.containsKey(message.messageId)) {
      throw MessageNotFoundException(message.messageId);
    }
    _store[message.messageId] = message;
  }

  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    final existing = _store[messageId];
    if (existing == null) {
      throw MessageNotFoundException(messageId);
    }
    _store[messageId] = existing.copyWith(status: status);
  }

  @override
  Future<void> incrementRetryCount(String messageId) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    final existing = _store[messageId];
    if (existing == null) {
      throw MessageNotFoundException(messageId);
    }
    _store[messageId] = existing.copyWith(retryCount: existing.retryCount + 1);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    _store.remove(messageId);
  }

  @override
  Future<int> deleteExpiredMessages({DateTime? now}) async {
    _ensureInitialized();
    if (shouldThrowOnWrite) {
      throw const DtnStorageException('Simulated storage write failure');
    }
    final ref = (now ?? DateTime.now().toUtc()).toUtc();
    final expiredKeys = _store.entries
        .where((e) => e.value.isExpired(referenceTime: ref))
        .map((e) => e.key)
        .toList();

    for (final key in expiredKeys) {
      _store.remove(key);
    }
    return expiredKeys.length;
  }

  @override
  Future<int> getMessageCount() async {
    _ensureInitialized();
    if (shouldThrowOnRead) {
      throw const DtnStorageException('Simulated storage read failure');
    }
    return _store.length;
  }

  @override
  Future<void> close() async {
    _isInitialized = false;
  }
}
