import '../mesh/models/mesh_message.dart';
import 'decision_engine_interface.dart';

/// Baseline Decision Engine for Step 1.
/// Prioritizes SOS emergency messages and admits valid messages into the store-and-forward queue.
class BasicDecisionEngine implements DecisionEngine {
  @override
  DecisionOutcome evaluateMessage(MeshMessage message) {
    // SOS messages always receive immediate acceptance
    if (message.isSos) {
      return DecisionOutcome.acceptImmediately;
    }

    // Check basic hop count sanity
    if (message.hopCount >= message.maxHops) {
      return DecisionOutcome.dropStaleOrDuplicated;
    }

    return DecisionOutcome.queueStoreAndForward;
  }
}
