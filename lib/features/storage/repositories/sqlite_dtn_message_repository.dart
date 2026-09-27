import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../mesh/models/mesh_message.dart';
import '../exceptions/storage_exceptions.dart';
import 'dtn_message_repository.dart';

/// SQLite implementation of [DtnMessageRepository] for local offline DTN message persistence.
class SqliteDtnMessageRepository implements DtnMessageRepository {
  static const int databaseVersion = 2;
  static const String databaseName = 'resqmesh_dtn.db';
  static const String tableName = 'dtn_messages';

  final DatabaseFactory? _factory;
  final String? _customPath;
  Database? _db;

  SqliteDtnMessageRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _factory = databaseFactory,
        _customPath = databasePath;

  bool get isOpen => _db != null && _db!.isOpen;

  void _ensureInitialized() {
    if (_db == null || !_db!.isOpen) {
      throw const DatabaseNotInitializedException();
    }
  }

  @override
  Future<void> init() async {
    if (_db != null && _db!.isOpen) return;

    try {
      final factory = _factory ?? databaseFactory;
      String fullPath;

      if (_customPath != null) {
        fullPath = _customPath;
      } else {
        final dirPath = await factory.getDatabasesPath();
        fullPath = p.join(dirPath, databaseName);
      }

      _db = await factory.openDatabase(
        fullPath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onCreate: (db, version) async {
            await _createSchema(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await db.execute('ALTER TABLE $tableName ADD COLUMN forwarding_history TEXT');
            }
          },
        ),
      );
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to initialize SQLite DTN database: $e', stack);
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        message_id TEXT PRIMARY KEY,
        origin_node_id TEXT NOT NULL,
        sender_node_id TEXT NOT NULL,
        destination_node_id TEXT NOT NULL,
        message_type TEXT NOT NULL,
        priority TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        ttl INTEGER NOT NULL,
        hop_count INTEGER NOT NULL DEFAULT 0,
        max_hops INTEGER NOT NULL DEFAULT 5,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_forwarded_at INTEGER,
        created_by_role TEXT NOT NULL,
        forwarding_history TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_dtn_messages_status ON $tableName(status)');
    await db.execute('CREATE INDEX idx_dtn_messages_priority ON $tableName(priority)');
    await db.execute('CREATE INDEX idx_dtn_messages_expires_at ON $tableName(expires_at)');
    await db.execute('CREATE INDEX idx_dtn_messages_origin_node_id ON $tableName(origin_node_id)');
  }

  @override
  Future<void> createMessage(MeshMessage message) async {
    _ensureInitialized();
    try {
      // Deduplication check: enforce rejection of existing message ID
      final existing = await _db!.query(
        tableName,
        columns: ['message_id'],
        where: 'message_id = ?',
        whereArgs: [message.messageId],
      );

      if (existing.isNotEmpty) {
        throw DuplicateMessageException(message.messageId);
      }

      await _db!.insert(
        tableName,
        message.toDatabaseMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to insert message ${message.messageId}: $e', stack);
    }
  }

  @override
  Future<MeshMessage?> getMessageById(String messageId) async {
    _ensureInitialized();
    try {
      final rows = await _db!.query(
        tableName,
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      if (rows.isEmpty) return null;
      return MeshMessage.fromDatabaseMap(rows.first);
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query message $messageId: $e', stack);
    }
  }

  @override
  Future<List<MeshMessage>> getAllMessages() async {
    _ensureInitialized();
    try {
      final rows = await _db!.query(
        tableName,
        orderBy: 'created_at DESC',
      );
      return rows.map(MeshMessage.fromDatabaseMap).toList();
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query all messages: $e', stack);
    }
  }

  @override
  Future<List<MeshMessage>> getMessagesByStatus(MessageStatus status) async {
    _ensureInitialized();
    try {
      final rows = await _db!.query(
        tableName,
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'created_at DESC',
      );
      return rows.map(MeshMessage.fromDatabaseMap).toList();
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query messages by status ${status.name}: $e', stack);
    }
  }

  @override
  Future<List<MeshMessage>> getMessagesByPriority(MessagePriority priority) async {
    _ensureInitialized();
    try {
      final rows = await _db!.query(
        tableName,
        where: 'priority = ?',
        whereArgs: [priority.name],
        orderBy: 'created_at DESC',
      );
      return rows.map(MeshMessage.fromDatabaseMap).toList();
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query messages by priority ${priority.name}: $e', stack);
    }
  }

  @override
  Future<List<MeshMessage>> getActiveMessages({DateTime? now}) async {
    _ensureInitialized();
    try {
      final refTime = (now ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;
      final rows = await _db!.query(
        tableName,
        where: 'expires_at >= ?',
        whereArgs: [refTime],
        orderBy: 'created_at DESC',
      );
      return rows.map(MeshMessage.fromDatabaseMap).toList();
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query active messages: $e', stack);
    }
  }

  @override
  Future<List<MeshMessage>> getExpiredMessages({DateTime? now}) async {
    _ensureInitialized();
    try {
      final refTime = (now ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;
      final rows = await _db!.query(
        tableName,
        where: 'expires_at < ?',
        whereArgs: [refTime],
        orderBy: 'created_at DESC',
      );
      return rows.map(MeshMessage.fromDatabaseMap).toList();
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to query expired messages: $e', stack);
    }
  }

  @override
  Future<void> updateMessage(MeshMessage message) async {
    _ensureInitialized();
    try {
      final count = await _db!.update(
        tableName,
        message.toDatabaseMap(),
        where: 'message_id = ?',
        whereArgs: [message.messageId],
      );

      if (count == 0) {
        throw MessageNotFoundException(message.messageId);
      }
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to update message ${message.messageId}: $e', stack);
    }
  }

  @override
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    _ensureInitialized();
    try {
      final count = await _db!.update(
        tableName,
        {'status': status.name},
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      if (count == 0) {
        throw MessageNotFoundException(messageId);
      }
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to update status for message $messageId: $e', stack);
    }
  }

  @override
  Future<void> incrementRetryCount(String messageId) async {
    _ensureInitialized();
    try {
      final count = await _db!.rawUpdate(
        'UPDATE $tableName SET retry_count = retry_count + 1 WHERE message_id = ?',
        [messageId],
      );

      if (count == 0) {
        throw MessageNotFoundException(messageId);
      }
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to increment retry count for $messageId: $e', stack);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    _ensureInitialized();
    try {
      await _db!.delete(
        tableName,
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to delete message $messageId: $e', stack);
    }
  }

  @override
  Future<int> deleteExpiredMessages({DateTime? now}) async {
    _ensureInitialized();
    try {
      final refTime = (now ?? DateTime.now().toUtc()).toUtc().millisecondsSinceEpoch;
      return await _db!.delete(
        tableName,
        where: 'expires_at < ?',
        whereArgs: [refTime],
      );
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to delete expired messages: $e', stack);
    }
  }

  @override
  Future<int> getMessageCount() async {
    _ensureInitialized();
    try {
      final result = await _db!.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stack) {
      if (e is DtnStorageException) rethrow;
      throw DtnStorageException('Failed to get message count: $e', stack);
    }
  }

  @override
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}
