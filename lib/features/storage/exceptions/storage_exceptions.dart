/// Base exception for ResQMesh DTN local storage operations.
class DtnStorageException implements Exception {
  final String message;
  final dynamic cause;

  const DtnStorageException(this.message, [this.cause]);

  @override
  String toString() => 'DtnStorageException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when attempting to insert a bundle or message with an ID that already exists.
class DuplicateMessageException extends DtnStorageException {
  final String messageId;

  const DuplicateMessageException(this.messageId)
      : super('Message with ID "$messageId" already exists in local storage.');
}

/// Thrown when a message requested by ID does not exist in storage.
class MessageNotFoundException extends DtnStorageException {
  final String messageId;

  const MessageNotFoundException(this.messageId)
      : super('Message with ID "$messageId" was not found in local storage.');
}

/// Thrown when a storage operation is attempted before database initialization.
class DatabaseNotInitializedException extends DtnStorageException {
  const DatabaseNotInitializedException()
      : super('Database has not been initialized. Call init() first.');
}
