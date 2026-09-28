import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../identity/services/node_identity_service.dart';
import '../mesh/models/peer_node.dart';
import 'ble_advertisement_codec.dart';
import 'peer_discovery_interface.dart';

enum BleHardwareState { unknown, unsupported, poweredOff, poweredOn, unauthorized }
enum BleScanStatus { idle, scanning, permissionDenied, error }

/// Gates BLE work on Android's actual, SDK-specific requirements before
/// starting the ResQMesh advertiser and scanner.
class BleDiscoveryService with ChangeNotifier implements PeerDiscoveryService {
  static const _androidChannel = MethodChannel('resqmesh/android');
  final NodeIdentityService? identityService;
  final StreamController<List<PeerNode>> _peersController = StreamController<List<PeerNode>>.broadcast();
  final Map<String, PeerNode> _discoveredPeers = {};
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  BleHardwareState _hardwareState = BleHardwareState.unknown;
  BleScanStatus _scanStatus = BleScanStatus.idle;
  bool _isDiscovering = false;
  bool _isAdvertising = false;
  bool _locationServiceEnabled = true;
  bool _advertisingSupported = true;
  int? _androidSdkInt;
  DateTime? _lastScanTimestamp;
  String? _errorMessage;
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  Set<Permission> _permanentlyDenied = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  Timer? _staleCleanupTimer;

  BleDiscoveryService({this.identityService});
  @override Stream<List<PeerNode>> get peersStream => _peersController.stream;
  @override List<PeerNode> get currentPeers => List.unmodifiable(_discoveredPeers.values.toList());
  @override bool get isDiscovering => _isDiscovering;
  bool get isScanning => _scanStatus == BleScanStatus.scanning;
  bool get isAdvertising => _isAdvertising;
  bool get nearbyPermissionsGranted => _requiredPermissions.every((p) => _permissionStatuses[p]?.isGranted ?? false);
  bool get locationServiceRequired => (_androidSdkInt ?? 0) >= 23 && (_androidSdkInt ?? 0) <= 30;
  bool get locationServiceEnabled => _locationServiceEnabled;
  bool get hasPermanentlyDeniedPermission => _permanentlyDenied.isNotEmpty;
  List<String> get missingPermissionNames => _requiredPermissions.where((p) => !(_permissionStatuses[p]?.isGranted ?? false)).map(_permissionName).toList();
  BleHardwareState get hardwareState => _hardwareState;
  BleScanStatus get scanStatus => _scanStatus;
  DateTime? get lastScanTimestamp => _lastScanTimestamp;
  String? get errorMessage => _errorMessage;
  int get peerCount => _discoveredPeers.length;
  int? get androidSdkInt => _androidSdkInt;
  String get localNodeId => identityService?.currentNodeId ?? '';
  String get localDisplayName => identityService?.identity?.displayName ?? 'ResQMesh Node';

  List<Permission> get _requiredPermissions {
    final sdk = _androidSdkInt;
    if (sdk == null) return const [];
    if (sdk >= 31) return [Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect];
    if (sdk >= 23) return [Permission.locationWhenInUse];
    return const [];
  }
  void _log(String text) => debugPrint('[ResQMesh][Permissions] $text');
  void _bluetoothLog(String text) => debugPrint('[ResQMesh][Bluetooth] $text');
  void _bleLog(String text) => debugPrint('[ResQMesh][BLE] $text');

  Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) {
      _hardwareState = BleHardwareState.unsupported;
      _errorMessage = 'BLE discovery is supported on physical Android devices.';
      notifyListeners();
      return;
    }
    try {
      _androidSdkInt = await _androidChannel.invokeMethod<int>('sdkInt');
      _log('Android SDK $_androidSdkInt; required: ${_permissionList(_requiredPermissions)}');
      final scannerSupported = await FlutterBluePlus.isSupported;
      _advertisingSupported = await _peripheral.isSupported;
      _bluetoothLog('Bluetooth available: $scannerSupported; advertiser available: $_advertisingSupported');
      if (!scannerSupported) {
        _hardwareState = BleHardwareState.unsupported;
        _errorMessage = 'Bluetooth Low Energy is not supported on this device.';
      }
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen(_onAdapterState, onError: (Object error) => _bluetoothLog('adapter-state error: $error'));
      _staleCleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) => pruneStalePeers());
      await refreshReadiness();
    } catch (e) {
      _errorMessage = 'BLE initialization error: $e';
      _bluetoothLog(_errorMessage!);
      notifyListeners();
    }
  }

  void _onAdapterState(BluetoothAdapterState state) {
    _bluetoothLog('adapter state: $state');
    _hardwareState = switch (state) {
      BluetoothAdapterState.on => BleHardwareState.poweredOn,
      BluetoothAdapterState.off => BleHardwareState.poweredOff,
      BluetoothAdapterState.unauthorized => BleHardwareState.unauthorized,
      _ => BleHardwareState.unknown,
    };
    if (_hardwareState == BleHardwareState.poweredOff) {
      _stopScanningInternal();
      _isAdvertising = false;
      _isDiscovering = false;
    }
    notifyListeners();
  }

  Future<void> refreshReadiness() async {
    if (kIsWeb || !Platform.isAndroid) return;
    _androidSdkInt ??= await _androidChannel.invokeMethod<int>('sdkInt');
    await _refreshPermissions();
    _locationServiceEnabled = !locationServiceRequired || await Permission.locationWhenInUse.serviceStatus.isEnabled;
    try { _onAdapterState(await FlutterBluePlus.adapterState.first); } catch (e) { _bluetoothLog('adapter state unavailable: $e'); }
    notifyListeners();
  }

  Future<void> _refreshPermissions() async {
    final statuses = <Permission, PermissionStatus>{};
    for (final permission in _requiredPermissions) { statuses[permission] = await permission.status; }
    _permissionStatuses = statuses;
    final granted = statuses.entries.where((e) => e.value.isGranted).map((e) => _permissionName(e.key)).join(', ');
    final denied = statuses.entries.where((e) => !e.value.isGranted).map((e) => _permissionName(e.key)).join(', ');
    _log('Android SDK $_androidSdkInt; required: ${_permissionList(_requiredPermissions)}; granted: ${granted.isEmpty ? 'none' : granted}; denied: ${denied.isEmpty ? 'none' : denied}; permanently denied: ${_permissionList(_permanentlyDenied)}');
  }

  Future<bool> checkAndRequestPermissions() async {
    await refreshReadiness();
    final missing = _requiredPermissions.where((p) => !(_permissionStatuses[p]?.isGranted ?? false)).toList();
    if (missing.isEmpty) return true;
    _log('requesting missing: ${missing.map(_permissionName).join(', ')}');
    final requested = await missing.request();
    _permanentlyDenied = requested.entries.where((e) => e.value.isPermanentlyDenied).map((e) => e.key).toSet();
    await _refreshPermissions(); // The OS result is verified, not assumed.
    if (!nearbyPermissionsGranted) {
      _scanStatus = BleScanStatus.permissionDenied;
      _errorMessage = hasPermanentlyDeniedPermission
          ? 'Nearby-device permission is required for ResQMesh device discovery. Please enable it in Android Settings.'
          : 'ResQMesh needs ${missingPermissionNames.join(', ')} permission to discover nearby devices and communicate with other ResQMesh devices.';
      notifyListeners();
      return false;
    }
    return true;
  }

  @override
  Future<void> startDiscovery() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await refreshReadiness();
    if (_hardwareState == BleHardwareState.unsupported) return;
    if (!await checkAndRequestPermissions()) return;
    await refreshReadiness();
    if (!_locationServiceEnabled) {
      _errorMessage = 'Location services must be enabled on this Android version for BLE discovery.';
      notifyListeners();
      return;
    }
    if (_hardwareState != BleHardwareState.poweredOn) {
      _errorMessage = 'Bluetooth is required for ResQMesh to discover nearby devices.';
      _bluetoothLog('Bluetooth enabled: false; discovery deferred');
      notifyListeners();
      return;
    }
    _errorMessage = null;
    await _startAdvertising();
    await _startScanning();
    _isDiscovering = _isAdvertising || isScanning;
    notifyListeners();
  }

  Future<void> turnOnBluetooth() async {
    try {
      _bluetoothLog('showing enable-Bluetooth dialog');
      await FlutterBluePlus.turnOn();
      await refreshReadiness();
      if (_hardwareState == BleHardwareState.poweredOn) await startDiscovery();
    } catch (e) {
      _errorMessage = 'Bluetooth was not enabled. Please turn it on to discover nearby devices.';
      _bluetoothLog('enable request failed: $e');
      notifyListeners();
    }
  }
  Future<bool> openSettings() => openAppSettings();
  Future<void> openLocationSettings() =>
      _androidChannel.invokeMethod<void>('openLocationSettings');

  Future<void> _startAdvertising() async {
    if (!_advertisingSupported) {
      _errorMessage = 'BLE advertising is not supported on this device. Scanning can still discover peers.';
      _bleLog('advertising unavailable: peripheral mode unsupported');
      return;
    }
    try {
      if (await _peripheral.isAdvertising) await _peripheral.stop();
      final state = await _peripheral.start(
        advertiseData: AdvertiseDataCore(serviceUuid: AppConstants.bleServiceUuid, manufacturerId: AppConstants.bleManufacturerId, manufacturerData: BleAdvertisementCodec.encode(nodeId: localNodeId, protocolVersion: AppConstants.protocolVersion, displayName: localDisplayName)),
        gattServer: GattServerSettings(serviceUuid: AppConstants.bleServiceUuid, txCharacteristicUuid: AppConstants.bleCharacteristicTxUuid, rxCharacteristicUuid: AppConstants.bleCharacteristicRxUuid),
      );
      _isAdvertising = state == PeripheralBluetoothState.ready || state == PeripheralBluetoothState.granted;
      _bleLog('advertising ${_isAdvertising ? 'started' : 'not started'}; state: $state');
      if (!_isAdvertising) _errorMessage = 'BLE advertising could not start ($state).';
    } catch (e) {
      _isAdvertising = false;
      _errorMessage = 'BLE advertiser initialization failure: $e';
      _bleLog('advertising failure: $e');
    }
  }

  Future<void> _startScanning() async {
    try {
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        _lastScanTimestamp = DateTime.now().toUtc();
        for (final result in results) { _processScanResult(result); }
      }, onError: (Object error) {
        _scanStatus = BleScanStatus.error;
        _errorMessage = 'BLE scan failure: $error';
        _bleLog('scanning failure: $error');
        notifyListeners();
      });
      await FlutterBluePlus.startScan(withServices: [Guid(AppConstants.bleServiceUuid)], timeout: const Duration(seconds: AppConstants.bleScanDurationSeconds), androidUsesFineLocation: false);
      _scanStatus = BleScanStatus.scanning;
      _bleLog('scanning started; service UUID: ${AppConstants.bleServiceUuid}');
    } catch (e) {
      _scanStatus = BleScanStatus.error;
      _errorMessage = 'BLE scanner initialization failure: $e';
      _bleLog('scanning failure: $e');
    }
  }

  void _processScanResult(ScanResult result) {
    List<int>? data = result.advertisementData.manufacturerData[AppConstants.bleManufacturerId];
    data ??= result.advertisementData.serviceData[Guid(AppConstants.bleServiceUuid)];
    if (data == null || data.isEmpty) return;
    _bleLog('discovered device id: ${result.device.remoteId.str}; RSSI: ${result.rssi}; service UUID: ${AppConstants.bleServiceUuid}');
    onAdvertisementReceived(rawData: data, rssi: result.rssi, deviceAddress: result.device.remoteId.str);
  }

  void onAdvertisementReceived({required List<int> rawData, required int rssi, String? deviceAddress}) {
    final decoded = BleAdvertisementCodec.decode(rawData);
    if (decoded == null || !BleAdvertisementCodec.isValidNodeId(decoded.nodeId) || (localNodeId.isNotEmpty && decoded.nodeId == localNodeId)) return;
    final now = DateTime.now().toUtc();
    final existing = _discoveredPeers[decoded.nodeId];
    _discoveredPeers[decoded.nodeId] = existing?.copyWith(rssi: rssi, lastSeen: now, displayName: decoded.displayName.isNotEmpty ? decoded.displayName : existing.displayName, protocolVersion: decoded.protocolVersion, deviceAddress: deviceAddress ?? existing.deviceAddress) ?? PeerNode(nodeId: decoded.nodeId, displayName: decoded.displayName.isNotEmpty ? decoded.displayName : 'ResQMesh Node', rssi: rssi, lastSeen: now, protocolVersion: decoded.protocolVersion, connectionState: PeerConnectionState.discovered, isResQMeshPeer: true, isDirectNeighbor: true, deviceAddress: deviceAddress);
    _bleLog(
      'ResQMesh peer name: ${decoded.displayName.isEmpty ? 'unnamed' : decoded.displayName}; '
      'id: ${decoded.nodeId}; RSSI: $rssi',
    );
    _emitPeers();
  }

  void pruneStalePeers({int timeoutSeconds = AppConstants.peerStaleTimeoutSeconds}) {
    final now = DateTime.now().toUtc(); final count = _discoveredPeers.length;
    _discoveredPeers.removeWhere((_, peer) => peer.isStale(now: now, timeoutSeconds: timeoutSeconds));
    if (_discoveredPeers.length != count) _emitPeers();
  }
  void _emitPeers() { _peersController.add(currentPeers); notifyListeners(); }
  @override Future<void> stopDiscovery() async {
    _isDiscovering = false; await _stopScanningInternal();
    try { if (await _peripheral.isAdvertising) await _peripheral.stop(); } catch (_) {}
    _isAdvertising = false; _bleLog('scanning stopped; advertising stopped'); notifyListeners();
  }
  Future<void> _stopScanningInternal() async {
    await _scanSubscription?.cancel(); _scanSubscription = null;
    try { if (await FlutterBluePlus.isScanning.first) await FlutterBluePlus.stopScan(); } catch (_) {}
    if (_scanStatus == BleScanStatus.scanning) _scanStatus = BleScanStatus.idle;
    _bleLog('scanning stopped');
  }
  void clearPeers() { _discoveredPeers.clear(); _emitPeers(); }
  String _permissionName(Permission p) => switch (p) { Permission.bluetoothScan => 'BLUETOOTH_SCAN', Permission.bluetoothAdvertise => 'BLUETOOTH_ADVERTISE', Permission.bluetoothConnect => 'BLUETOOTH_CONNECT', Permission.locationWhenInUse => 'ACCESS_FINE_LOCATION', _ => p.toString() };
  String _permissionList(Iterable<Permission> permissions) =>
      permissions.isEmpty ? 'none' : permissions.map(_permissionName).join(', ');
  @visibleForTesting void setHardwareStateForTest(BleHardwareState state) { _hardwareState = state; notifyListeners(); }
  @visibleForTesting void setScanStatusForTest(BleScanStatus state) { _scanStatus = state; notifyListeners(); }
  @override void dispose() { _staleCleanupTimer?.cancel(); _scanSubscription?.cancel(); _adapterStateSubscription?.cancel(); _peersController.close(); super.dispose(); }
}
