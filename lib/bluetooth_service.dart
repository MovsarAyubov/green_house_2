import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';

class HC06BluetoothService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final _connectionStateController = StreamController<ConnectionStateUpdate>();
  final _dataStreamController = StreamController<String>.broadcast();

  StreamSubscription? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _dataSubscription;

  DiscoveredDevice? _connectedDevice;
  
  // HC-06 обычно использует этот UUID для сервиса и характеристики
  final Uuid _serviceUuid = Uuid.parse('00001101-0000-1000-8000-00805F9B34FB');
  final Uuid _characteristicUuid = Uuid.parse('00001101-0000-1000-8000-00805F9B34FB');

  // Стримы для UI
  Stream<ConnectionStateUpdate> get connectionStateStream => 
      _connectionStateController.stream;
  Stream<String> get dataStream => _dataStreamController.stream;

  bool get isConnected => _connectedDevice != null;

  // Начать поиск и подключение к HC-06
  Future<void> startScanAndConnect() async {
    print('Начинаем поиск HC-06...');
    
    _scanSubscription?.cancel();
    _scanSubscription = _ble.scanForDevices(
      withServices: [], // Можно оставить пустым, так как HC-06 может не рекламировать сервисы
    ).listen((device) {
      // Проверяем, является ли устройство HC-06
      if (device.name.contains('HC-06') || device.name.contains('HC06')) {
        print('Найден HC-06: ${device.name}');
        stopScan();
        connectToDevice(device);
      }
    }, onError: (error) {
      print('Ошибка сканирования: $error');
    });

    // Автоматически останавливаем сканирование через 10 секунд
    Timer(Duration(seconds: 10), () {
      if (_connectedDevice == null) {
        stopScan();
        print('HC-06 не найден за отведенное время');
      }
    });
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // Подключение к HC-06
  void connectToDevice(DiscoveredDevice device) {
    print('Подключаемся к HC-06...');
    
    _connectionSubscription?.cancel();
    _connectionSubscription = _ble.connectToDevice(
      id: device.id,
      connectionTimeout: const Duration(seconds: 10),
    ).listen((connectionState) {
      _connectionStateController.add(connectionState);
      
      switch (connectionState.connectionState) {
        case DeviceConnectionState.connected:
          _connectedDevice = device;
          print('Подключено к HC-06');
          _startListeningToData(device.id);
          break;
        case DeviceConnectionState.disconnected:
          _connectedDevice = null;
          print('Отключено от HC-06');
          break;
        default:
          break;
      }
    }, onError: (error) {
      print('Ошибка подключения: $error');
      _connectedDevice = null;
    });
  }

  // Начать прослушивание данных
  void _startListeningToData(String deviceId) async {
    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: _serviceUuid,
        characteristicId: _characteristicUuid,
        deviceId: deviceId,
      );

      _dataSubscription = _ble.subscribeToCharacteristic(characteristic).listen(
        (data) {
          // Конвертируем полученные байты в строку
          final stringData = String.fromCharCodes(data);
          _dataStreamController.add(stringData);
          print('Получены данные: $stringData');
        },
        onError: (error) {
          print('Ошибка при получении данных: $error');
        }
      );
    } catch (e) {
      print('Ошибка при подписке на характеристику: $e');
    }
  }

  // Отправка данных на HC-06
  Future<void> sendData(String data) async {
    if (_connectedDevice == null) {
      print('Устройство не подключено');
      return;
    }

    try {
      final characteristic = QualifiedCharacteristic(
        serviceId: _serviceUuid,
        characteristicId: _characteristicUuid,
        deviceId: _connectedDevice!.id,
      );

      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: data.codeUnits,
      );
      print('Данные успешно отправлены: $data');
    } catch (e) {
      print('Ошибка при отправке данных: $e');
    }
  }

  void disconnect() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _connectedDevice = null;
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _dataStreamController.close();
  }
}
