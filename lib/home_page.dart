import 'package:flutter/material.dart';
import 'bluetooth_service.dart';

class BluetoothPage extends StatefulWidget {
  @override
  _BluetoothPageState createState() => _BluetoothPageState();
}

class _BluetoothPageState extends State<BluetoothPage> {
  final HC06BluetoothService _bluetoothService = HC06BluetoothService();
  String _lastReceivedData = '';

  @override
  void initState() {
    super.initState();
    // Подписываемся на получение данных
    _bluetoothService.dataStream.listen((data) {
      setState(() {
        _lastReceivedData = data;
      });
    });
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HC-06 Bluetooth'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<ConnectionStateUpdate>(
              stream: _bluetoothService.connectionStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data?.connectionState;
                return Text(
                  'Статус: ${_getConnectionStatusText(state)}',
                  style: TextStyle(fontSize: 18),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Последние данные: $_lastReceivedData',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _bluetoothService.startScanAndConnect(),
              child: Text('Найти и подключить HC-06'),
            ),
          ],
        ),
      ),
    );
  }

  String _getConnectionStatusText(DeviceConnectionState? state) {
    switch (state) {
      case DeviceConnectionState.connected:
        return 'Подключено';
      case DeviceConnectionState.connecting:
        return 'Подключение...';
      case DeviceConnectionState.disconnecting:
        return 'Отключение...';
      case DeviceConnectionState.disconnected:
        return 'Отключено';
      default:
        return 'Неизвестно';
    }
  }
}
