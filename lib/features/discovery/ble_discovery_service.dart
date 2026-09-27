import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../identity/services/node_identity_service.dart';
import '../mesh/models/peer_node.dart';
import 'ble_advertisement_codec.dart';
import 'peer_discovery_interface.dart';

/// Bluetooth hardware availability state.
enum BleHardwareState {
  unknown,
  unsupported,
  poweredOff,
  poweredOn,
  unauthorized,
}

/// Active status of BLE peer scanning.
enum BleScanStatus {
  idle,
  scanning,
  permissionDenied,
  error,
}

/// Production BLE Peer Discovery service implementing [PeerDiscoveryInterface].
/// Operates on physical Android devices using real Bluetooth Low Energy scanning and advertising.
/// Filters non-ResQMesh devices, enforces self-filtering, deduplicates peers, and evicts stale nodes.
class BleDiscoveryService with ChangeNotifier implements PeerDiscoveryService {
  final NodeIdentityService? identityService;

  final StreamController<List<PeerNode>> _peersController = StreamController<List<PeerNode>>.broadcast();
  final Map<String, PeerNode> _discoveredPeers = {};

  BleHardwareState _hardwareState = BleHardwareState.unknown;
  BleScanStatus _scanStatus = BleScanStatus.idle;
  bool _isDiscovering = false;
  DateTime? _lastScanTimestamp;
  String? _errorMessage;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  Timer? _staleCleanupTimer;
  Timer? _scanDutyCycleTimer;

  BleDiscoveryService({this.identityService});

  // --- Public Getters ---
  @override
  Stream<List<PeerNode>> get peersStream => _peersController.stream;

  @override
  List<PeerNode> get currentPeers => List.unmodifiable(_discoveredPeers.values.toList());

  @override
  bool get isDiscovering => _isDiscovering;

  BleHardwareState get hardwareState => _hardwareState;
  BleScanStatus get scanStatus => _scanStatus;
  DateTime? get lastScanTimestamp => _lastScanTimestamp;
  String? get errorMessage => _errorMessage;
  int get peerCount => _discoveredPeers.length;

  String get localNodeId => identityService?.currentNodeId ?? '';
  String get localDisplayName => identityService?.identity?.displayName ?? 'ResQMesh Node';

  /// Initializes BLE adapter monitoring and stale peer cleanup timer.
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) {
      _hardwareState = BleHardwareState.unsupported;
      _errorMessage = 'BLE discovery is supported on Android.';
      notifyListeners();
      return;
    }

    try {
      // Check initial adapter state
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _hardwareState = BleHardwareState.unsupported;
        _errorMessage = 'Bluetooth Low Energy is not supported on this device.';
        notifyListeners();
        return;
      }

      // Listen for Bluetooth power on/off changes
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          _hardwareState = BleHardwareState.poweredOn;
        } else if (state == BluetoothAdapterState.off) {
          _hardwareState = BleHardwareState.poweredOff;
          _stopScanningInternal();
        } else if (state == BluetoothAdapterState.unauthorized) {
          _hardwareState = BleHardwareState.unauthorized;
          _scanStatus = BleScanStatus.permissionDenied;
        } else {
          _hardwareState = BleHardwareState.unknown;
        }
        notifyListeners();
      });

      // Start periodic stale peer eviction timer (every 2 seconds)
      _staleCleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        pruneStalePeers();
      });
    } catch (e) {
      _hardwareState = BleHardwareState.unknown;
      _errorMessage = 'BLE initialization error: $e';
      notifyListeners();
    }
  }

  /// Checks and requests necessary runtime permissions on Android 12+ and earlier.
  Future<bool> checkAndRequestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return false;

    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      final advGranted = statuses[Permission.bluetoothAdvertise]?.isGranted ?? true;
      final connGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final locGranted = statuses[Permission.location]?.isGranted ?? true;

      final allGranted = scanGranted && advGranted && connGranted && locGranted;
      if (!allGranted) {
        _scanStatus = BleScanStatus.permissionDenied;
        _errorMessage = 'Bluetooth permissions are required for mesh discovery.';
        notifyListeners();
        return false;
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _scanStatus = BleScanStatus.permissionDenied;
      _errorMessage = 'Failed to request Bluetooth permissions: $e';
      notifyListeners();
      return false;
    }
  }

  /// Starts advertising local ResQMesh identity and scanning for nearby peers.
  @override
  Future<void> startDiscovery() async {
    if (kIsWeb || !Platform.isAndroid) {
      _errorMessage = 'BLE discovery is supported on Android.';
      notifyListeners();
      return;
    }

    final hasPermissions = await checkAndRequestPermissions();
    if (!hasPermissions) return;

    if (_hardwareState == BleHardwareState.poweredOff) {
      _errorMessage = 'Bluetooth is turned off. Please enable Bluetooth.';
      notifyListeners();
      return;
    }

    _isDiscovering = true;
    _scanStatus = BleScanStatus.scanning;
    _errorMessage = null;
    notifyListeners();

    await _startAdvertising();
    await _startScanning();
  }

  /// Starts BLE peripheral advertising of ResQMesh identity.
  Future<void> _startAdvertising() async {
    try {
      final payload = BleAdvertisementCodec.encode(
        nodeId: localNodeId,
        protocolVersion: AppConstants.protocolVersion,
        displayName: localDisplayName,
      );

      final advertiseData = AdvertiseDataCore(
        serviceUuid: AppConstants.bleServiceUuid,
        manufacturerId: AppConstants.bleManufacturerId,
        manufacturerData: payload,
      );

      final gattServer = GattServerSettings(
        serviceUuid: AppConstants.bleServiceUuid,
        txCharacteristicUuid: AppConstants.bleCharacteristicTxUuid,
        rxCharacteristicUuid: AppConstants.bleCharacteristicRxUuid,
      );

      final peripheral = FlutterBlePeripheral();
      if (await peripheral.isAdvertising) {
        await peripheral.stop();
      }
      await peripheral.start(
        advertiseData: advertiseData,
        gattServer: gattServer,
      );
    } catch (e) {
      debugPrint('ResQMesh: Peripheral advertising notice: $e');
    }
  }

  /// Starts BLE central scanning filtered by ResQMesh service UUID.
  Future<void> _startScanning() async {
    try {
      await _scanSubscription?.cancel();

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _lastScanTimestamp = DateTime.now().toUtc();
        for (final result in results) {
          _processScanResult(result);
        }
      });

      // Start scan with ResQMesh service filter
      await FlutterBluePlus.startScan(
        withServices: [Guid(AppConstants.bleServiceUuid)],
        timeout: const Duration(seconds: AppConstants.bleScanDurationSeconds),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _scanStatus = BleScanStatus.error;
      _errorMessage = 'Failed to start BLE scan: $e';
      notifyListeners();
    }
  }

  /// Processes a single BLE scan result.
  void _processScanResult(ScanResult result) {
    // 1. Extract raw advertisement payload from manufacturer data or service data
    List<int>? rawData;

    // Check manufacturer data under ResQMesh manufacturer ID
    if (result.advertisementData.manufacturerData.containsKey(AppConstants.bleManufacturerId)) {
      rawData = result.advertisementData.manufacturerData[AppConstants.bleManufacturerId];
    }

    // Check service data under ResQMesh service UUID
    if (rawData == null || rawData.isEmpty) {
      final serviceGuid = Guid(AppConstants.bleServiceUuid);
      if (result.advertisementData.serviceData.containsKey(serviceGuid)) {
        rawData = result.advertisementData.serviceData[serviceGuid];
      }
    }

    // Also check any manufacturer data if single entry exists
    if (rawData == null && result.advertisementData.manufacturerData.isNotEmpty) {
      rawData = result.advertisementData.manufacturerData.values.first;
    }

    if (rawData != null && rawData.isNotEmpty) {
      onAdvertisementReceived(
        rawData: rawData,
        rssi: result.rssi,
        deviceAddress: result.device.remoteId.str,
      );
    }
  }

  /// Core ingestion logic for decoded BLE advertisements.
  /// Validates format, applies self-filtering, deduplicates, and updates RSSI & lastSeen.
  void onAdvertisementReceived({
    required List<int> rawData,
    required int rssi,
    String? deviceAddress,
  }) {
    // 1. Decode advertisement payload
    final decoded = BleAdvertisementCodec.decode(rawData);
    if (decoded == null) {
      // Non-ResQMesh device: strictly ignore
      return;
    }

    // 2. Validate Node ID format
    if (!BleAdvertisementCodec.isValidNodeId(decoded.nodeId)) {
      // Malformed or invalid Node ID: strictly ignore
      return;
    }

    // 3. Self-filtering: Ignore advertisements from own Node ID
    if (localNodeId.isNotEmpty && decoded.nodeId == localNodeId) {
      return;
    }

    final now = DateTime.now().toUtc();
    final existing = _discoveredPeers[decoded.nodeId];

    if (existing != null) {
      // 4. Peer seen again: update RSSI, lastSeen, name and address without duplicating
      _discoveredPeers[decoded.nodeId] = existing.copyWith(
        rssi: rssi,
        lastSeen: now,
        displayName: decoded.displayName.isNotEmpty ? decoded.displayName : existing.displayName,
        protocolVersion: decoded.protocolVersion,
        deviceAddress: deviceAddress ?? existing.deviceAddress,
      );
    } else {
      // 5. First-time discovery of this peer
      final newPeer = PeerNode(
        nodeId: decoded.nodeId,
        displayName: decoded.displayName.isNotEmpty ? decoded.displayName : 'ResQMesh Node',
        rssi: rssi,
        lastSeen: now,
        protocolVersion: decoded.protocolVersion,
        connectionState: PeerConnectionState.discovered,
        isResQMeshPeer: true,
        isDirectNeighbor: true,
        deviceAddress: deviceAddress,
      );
      _discoveredPeers[decoded.nodeId] = newPeer;
    }

    _emitPeers();
  }

  /// Removes peers that have not been observed within [timeoutSeconds].
  void pruneStalePeers({int timeoutSeconds = AppConstants.peerStaleTimeoutSeconds}) {
    final now = DateTime.now().toUtc();
    final initialCount = _discoveredPeers.length;

    _discoveredPeers.removeWhere((_, peer) => peer.isStale(now: now, timeoutSeconds: timeoutSeconds));

    if (_discoveredPeers.length != initialCount) {
      _emitPeers();
    }
  }

  void _emitPeers() {
    final list = _discoveredPeers.values.toList();
    _peersController.add(list);
    notifyListeners();
  }

  /// Stops peer discovery scanning and advertising.
  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _scanStatus = BleScanStatus.idle;
    await _stopScanningInternal();
    try {
      final peripheral = FlutterBlePeripheral();
      if (await peripheral.isAdvertising) {
        await peripheral.stop();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _stopScanningInternal() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      if (Platform.isAndroid && await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
  }

  /// Manually clears discovered peer history (e.g. for testing).
  void clearPeers() {
    _discoveredPeers.clear();
    _emitPeers();
  }

  /// Directly sets hardware state for unit test verification.
  @visibleForTesting
  void setHardwareStateForTest(BleHardwareState state) {
    _hardwareState = state;
    notifyListeners();
  }

  /// Directly sets scan status for unit test verification.
  @visibleForTesting
  void setScanStatusForTest(BleScanStatus status) {
    _scanStatus = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _staleCleanupTimer?.cancel();
    _scanDutyCycleTimer?.cancel();
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _peersController.close();
    super.dispose();
  }
}
