import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:green_house_2/bluetooth_service.dart';

class HomePage extends StatefulWidget {
const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BleStreamService _bleService = BleStreamService();
  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Подписываемся на потоки
    _bleService.devicesStream.listen((devices) {
      setState(() => _devices = devices);
    });
    
    _bleService.scanningStateStream.listen((isScanning) {
      setState(() => _isScanning = isScanning);
    });
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BLE Scanner (Stream)')),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Статус: ${_isScanning ? 'Сканирование...' : 'Остановлено'}'),
                if (_isScanning) CircularProgressIndicator(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) => InkWell(
                onTap: () {
                  _bleService.connectToDiscoveredDevice(_devices[index]);
                },
                child: Card(
                  child: Column(
                    children: [
                      Text(_devices[index].name),
                    ],
                  )
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isScanning) {
            _bleService.stopScan();
          } else {
            _bleService.startScan();
          }
        },
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }
}