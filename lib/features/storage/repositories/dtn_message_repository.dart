import '../../mesh/models/mesh_message.dart';

/// Abstract storage repository interface for ResQMesh DTN message bundles.
/// Completely decoupled from UI, BLE, Gateway, Internet, or cloud backends.
abstract class DtnMessageRepository {
  /// Initializes the underlying database storage and ensures table & index creation.
  Future<void> init();

  /// Inserts a newly created DTN message bundle.
  /// Throws [DuplicateMessageException] if a message with the given messageId already exists.
  Future<void> createMessage(MeshMessage message);

  /// Retrieves a specific message by its unique [messageId], or null if not found.
  Future<MeshMessage?> getMessageById(String messageId);

  /// Retrieves all stored messages, ordered by creation date descending.
  Future<List<MeshMessage>> getAllMessages();

  /// Retrieves messages matching a specific [MessageStatus].
  Future<List<MeshMessage>> getMessagesByStatus(MessageStatus status);

  /// Retrieves messages matching a specific [MessagePriority].
  Future<List<MeshMessage>> getMessagesByPriority(MessagePriority priority);

  /// Retrieves active (non-expired) messages (`expiresAt >= now`).
  Future<List<MeshMessage>> getActiveMessages({DateTime? now});

  /// Retrieves expired messages (`expiresAt < now`).
  Future<List<MeshMessage>> getExpiredMessages({DateTime? now});

  /// Updates all mutable fields of an existing message in storage.
  /// Throws [MessageNotFoundException] if the message does not exist.
  Future<void> updateMessage(MeshMessage message);

  /// Updates only the [MessageStatus] of an existing message.
  /// Throws [MessageNotFoundException] if the message does not exist.
  Future<void> updateMessageStatus(String messageId, MessageStatus status);

  /// Increments the retry transmission count of a message by 1.
  /// Throws [MessageNotFoundException] if the message does not exist.
  Future<void> incrementRetryCount(String messageId);

  /// Deletes a specific message by its [messageId].
  Future<void> deleteMessage(String messageId);

  /// Deletes all expired messages (`expiresAt < now`) and returns count of deleted rows.
  Future<int> deleteExpiredMessages({DateTime? now});

  /// Returns the total count of stored messages.
  Future<int> getMessageCount();

  /// Closes the database connection.
  Future<void> close();
}
