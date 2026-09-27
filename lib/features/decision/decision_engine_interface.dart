import '../mesh/models/mesh_message.dart';

enum DecisionOutcome {
  acceptImmediately,
  queueStoreAndForward,
  dropStaleOrDuplicated,
}

/// Abstract contract for ResQMesh Decision Engine (Step 8).
/// Responsible for prioritizing emergency traffic and regulating packet transmission.
abstract class DecisionEngine {
  /// Evaluates an outgoing or incoming message to determine the handling policy.
  DecisionOutcome evaluateMessage(MeshMessage message);
}
