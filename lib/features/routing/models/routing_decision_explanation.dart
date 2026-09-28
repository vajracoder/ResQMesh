import '../models/relay_decision.dart';
import '../scoring/message_urgency_calculator.dart';
import '../scoring/peer_scoring_model.dart';

/// Explicit explanation of an intelligent DTN routing decision.
///
/// Designed for research auditing, mesh field diagnostics, and verification
/// without cloud dependencies.
class RoutingDecisionExplanation {
  final String messageId;
  final String peerId;
  final RelayOutcome outcome;
  final String reason;
  final MessageUrgencyScore urgency;
  final PeerUtilityScore? peerUtility;
  final DateTime timestamp;

  RoutingDecisionExplanation({
    required this.messageId,
    required this.peerId,
    required this.outcome,
    required this.reason,
    required this.urgency,
    this.peerUtility,
    DateTime? timestamp,
  }) : timestamp = (timestamp ?? DateTime.now().toUtc()).toUtc();

  String toFormattedReport() {
    final buffer = StringBuffer();
    buffer.writeln('Message: $messageId');
    buffer.writeln('Target Peer: $peerId');
    buffer.writeln('Decision: ${outcome.name.toUpperCase()}');
    buffer.writeln('Reason: $reason');
    buffer.writeln('Urgency: ${urgency.summary}');
    if (peerUtility != null) {
      buffer.writeln('Peer Utility: ${peerUtility!.summary}');
    }
    return buffer.toString().trim();
  }

  @override
  String toString() =>
      'RoutingDecisionExplanation($messageId -> $peerId: ${outcome.name}, reason=$reason)';
}
