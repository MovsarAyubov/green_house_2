import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';

class BleStreamService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final _devicesStreamController = StreamController<List<DiscoveredDevice>>();
  final _scanningStateController = StreamController<bool>();
  final _connectionStateController = StreamController<ConnectionStateUpdate>();
  final _connectedDeviceController = StreamController<DiscoveredDevice?>();
  
  List<DiscoveredDevice> _foundDevices = [];
  StreamSubscription? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  DiscoveredDevice? _connectedDevice;

  // Потоки для UI
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesStreamController.stream;
  Stream<bool> get scanningStateStream => _scanningStateController.stream;
  Stream<ConnectionStateUpdate> get connectionStateStream => _connectionStateController.stream;
  Stream<DiscoveredDevice?> get connectedDeviceStream => _connectedDeviceController.stream;

  // Геттеры для текущего состояния
  DiscoveredDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  DeviceConnectionState? get currentConnectionState => 
      _connectionSubscription != null ? _getCurrentConnectionState() : null;

  void startScan() {
    _foundDevices.clear();
    _scanningStateController.add(true);
    
    _scanSubscription = _ble.scanForDevices(withServices: []).listen((device) {
      if (_foundDevices.any((d) => d.id == device.id)) {
        _foundDevices.add(device);
        _devicesStreamController.add(List.from(_foundDevices));
      }
    }, onError: (error) {
      _scanningStateController.add(false);
      print('Ошибка сканирования: $error');
    });
    Timer(Duration(seconds: 5), () => stopScan());
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _scanningStateController.add(false);
  }

  /// Подключение к устройству
  void connectToDiscoveredDevice(DiscoveredDevice device, {
    Map<Uuid, List<Uuid>>? servicesWithCharacteristicsToDiscover,
    Duration connectionTimeout = const Duration(seconds: 10),
  }) {
    // Отменяем предыдущее подключение если есть
    _connectionSubscription?.cancel();
    
    print('Подключаемся к устройству: ${device.name} (${device.id})');
    
    _connectionSubscription = _ble.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: servicesWithCharacteristicsToDiscover,
      connectionTimeout: connectionTimeout,
    ).listen((connectionStateUpdate) {
      print('Состояние подключения: ${connectionStateUpdate.connectionState}');
      _connectionStateController.add(connectionStateUpdate);
      
      switch (connectionStateUpdate.connectionState) {
        case DeviceConnectionState.connected:
          _connectedDevice = device;
          _connectedDeviceController.add(device);
          print('Успешно подключились к ${device.name}');
          break;
        case DeviceConnectionState.disconnected:
          if (_connectedDevice?.id == device.id) {
            _connectedDevice = null;
            _connectedDeviceController.add(null);
            print('Отключились от ${device.name}');
          }
          break;
        case DeviceConnectionState.connecting:
          print('Идет подключение...');
          break;
        case DeviceConnectionState.disconnecting:
          print('Идет отключение...');
          break;
      }
    }, onError: (error) {
      print('Ошибка подключения к ${device.name}: $error');
      _connectionStateController.addError(error);
      _connectedDevice = null;
      _connectedDeviceController.add(null);
    });
  }

  /// Отключение от текущего устройства
  void disconnect() {
    print('Отключаемся от устройства...');
    _connectionSubscription?.cancel();
    _connectedDevice = null;
    _connectedDeviceController.add(null);
    
    // Создаем финальное состояние отключения
    final disconnectedState = ConnectionStateUpdate(
      deviceId: _connectedDevice?.id ?? '',
      connectionState: DeviceConnectionState.disconnected,
      failure: null,
    );
    _connectionStateController.add(disconnectedState);
  }

  /// Вспомогательный метод для получения текущего состояния подключения
  DeviceConnectionState _getCurrentConnectionState() {
    // В реальном приложении здесь нужно хранить последнее состояние
    return DeviceConnectionState.disconnected;
  }

  void dispose() {
    stopScan();
    disconnect();
    _devicesStreamController.close();
    _scanningStateController.close();
    _connectionStateController.close();
    _connectedDeviceController.close();
  }
}