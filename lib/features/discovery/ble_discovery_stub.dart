import 'dart:async';
import '../mesh/models/peer_node.dart';
import 'peer_discovery_interface.dart';

/// Baseline stub for Peer Discovery in Step 1.
/// In accordance with project requirements:
/// - No fake BLE functionality or fake peers are generated.
/// - Full BLE advertising & scanning will be implemented in Step 4.
class BleDiscoveryStub implements PeerDiscoveryService {
  final _peersController = StreamController<List<PeerNode>>.broadcast();
  bool _isDiscovering = false;

  @override
  Stream<List<PeerNode>> get peersStream => _peersController.stream;

  @override
  List<PeerNode> get currentPeers => const [];

  @override
  bool get isDiscovering => _isDiscovering;

  @override
  Future<void> startDiscovery() async {
    // BLE scanning will be implemented in Step 4 with flutter_reactive_ble or flutter_blue_plus.
    // For now, keep scanner disabled without faking nodes.
    _isDiscovering = false;
    _peersController.add(const []);
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _peersController.add(const []);
  }

  @override
  void dispose() {
    _peersController.close();
  }
}
