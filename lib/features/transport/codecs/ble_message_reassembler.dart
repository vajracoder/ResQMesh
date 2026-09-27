import 'dart:typed_data';
import '../../../core/constants/app_constants.dart';
import '../models/ble_packet.dart';

class _InFlightAssembly {
  final String messageId;
  final int totalFragments;
  final DateTime createdAt;
  final Map<int, Uint8List> fragments = {};

  _InFlightAssembly({
    required this.messageId,
    required this.totalFragments,
    required this.createdAt,
  });

  bool isComplete() => fragments.length == totalFragments;

  bool isStale({required DateTime referenceTime, required int timeoutSeconds}) {
    return referenceTime.difference(createdAt).inSeconds >= timeoutSeconds;
  }
}

/// Reconstructs divided [BleMessageFragment] packets into a complete message payload.
/// Protects against duplicate fragments, missing fragments, and prunes stale incomplete assemblies.
class BleMessageReassembler {
  final Map<String, _InFlightAssembly> _assemblies = {};

  int get activeAssemblyCount => _assemblies.length;

  bool hasAssembly(String messageId) => _assemblies.containsKey(messageId);

  int getReceivedFragmentCount(String messageId) =>
      _assemblies[messageId]?.fragments.length ?? 0;

  /// Ingests a [BleMessageFragment].
  /// Returns the complete reconstructed [Uint8List] if this fragment completes the message,
  /// or `null` if more fragments are needed or the fragment was invalid.
  Uint8List? addFragment(BleMessageFragment fragment, {DateTime? now}) {
    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();

    // Sanity checks on fragment parameters
    if (fragment.totalFragments <= 0 ||
        fragment.fragmentIndex < 0 ||
        fragment.fragmentIndex >= fragment.totalFragments) {
      return null;
    }

    final assembly = _assemblies.putIfAbsent(
      fragment.messageId,
      () => _InFlightAssembly(
        messageId: fragment.messageId,
        totalFragments: fragment.totalFragments,
        createdAt: timestamp,
      ),
    );

    // Mismatched total fragments for the same messageId indicates corruption
    if (assembly.totalFragments != fragment.totalFragments) {
      return null;
    }

    // Store fragment (idempotent, deduplicates repeat arrivals)
    assembly.fragments[fragment.fragmentIndex] = fragment.data;

    // Check if all fragments have arrived
    if (assembly.isComplete()) {
      // Verify all indices from 0 to totalFragments - 1 are present
      final builder = BytesBuilder();
      for (int i = 0; i < assembly.totalFragments; i++) {
        final chunk = assembly.fragments[i];
        if (chunk == null) {
          // Missing an index
          return null;
        }
        builder.add(chunk);
      }

      // Cleanup completed assembly from buffer
      _assemblies.remove(fragment.messageId);
      return builder.toBytes();
    }

    return null;
  }

  /// Removes incomplete fragment assemblies that have exceeded the retention timeout.
  int pruneStaleAssemblies({
    DateTime? now,
    int timeoutSeconds = AppConstants.fragmentAssemblyTimeoutSeconds,
  }) {
    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();
    final initialCount = _assemblies.length;

    _assemblies.removeWhere((_, assembly) {
      return assembly.isStale(referenceTime: timestamp, timeoutSeconds: timeoutSeconds);
    });

    return initialCount - _assemblies.length;
  }

  void clear() {
    _assemblies.clear();
  }
}
