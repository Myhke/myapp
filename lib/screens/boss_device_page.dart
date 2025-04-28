import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../services/bluetooth_service.dart';

class BossDevicePage extends StatefulWidget {
  const BossDevicePage({super.key});

  @override
  _BossDevicePageState createState() => _BossDevicePageState();
}

class _BossDevicePageState extends State<BossDevicePage> {
  final NetworkService _networkService = NetworkService();
  final BluetoothService _bluetoothService = BluetoothService();
  final List<DeviceInfo> _discoveredDevices = [];
  final List<BluetoothDeviceInfo> _discoveredBluetoothDevices = [];
  DeviceInfo? _selectedDevice;
  BluetoothDeviceInfo? _selectedBluetoothDevice;
  double _currentVolume = 0;
  final int _maxVolume = 15; // Assuming a default max volume for the slider
  bool _useBluetoothMode = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Inicializar Bluetooth
    bool bluetoothEnabled = await _bluetoothService.initBluetooth();
    if (bluetoothEnabled) {
      setState(() {
        // Bluetooth está disponible, pero dejamos que el usuario elija el modo
      });
    }
    
    // Iniciar descubrimiento de red por defecto
    _startDiscovery();
  }

  void _startDiscovery() {
    if (_useBluetoothMode) {
      // Descubrir dispositivos Bluetooth
      _bluetoothService.discoverDevices().listen((device) {
        if (!_discoveredBluetoothDevices.contains(device)) {
          setState(() {
            _discoveredBluetoothDevices.add(device);
          });
        }
      });
    } else {
      // Descubrir dispositivos por red (código existente)
      _networkService.listenForDevices().listen((device) {
        if (!_discoveredDevices.contains(device)) {
          setState(() {
            _discoveredDevices.add(device);
          });
        }
      });
    }
  }

  void _toggleConnectionMode() {
    setState(() {
      _useBluetoothMode = !_useBluetoothMode;
      _selectedDevice = null;
      _selectedBluetoothDevice = null;
      
      // Limpiar listas de dispositivos al cambiar de modo
      if (_useBluetoothMode) {
        _discoveredDevices.clear();
        _bluetoothService.stopDiscovery(); // Por si acaso estaba en progreso
      } else {
        _discoveredBluetoothDevices.clear();
        _bluetoothService.disconnect(); // Desconectar Bluetooth si estaba conectado
      }
    });
    
    // Iniciar descubrimiento en el nuevo modo
    _startDiscovery();
  }

  void _connectToDevice(DeviceInfo device) async {
    // Código existente para conexión por red
    setState(() {
      _selectedDevice = device;
    });
    bool connected = await _networkService.connectToDevice(device.ipAddress);
    if (!connected) {
       setState(() {
        _selectedDevice = null;
      });
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect to ${device.id}')),
      );
    }
  }

  void _connectToBluetoothDevice(BluetoothDeviceInfo device) async {
    setState(() {
      _selectedBluetoothDevice = device;
    });
    bool connected = await _bluetoothService.connectToDevice(device.address);
    if (!connected) {
      setState(() {
        _selectedBluetoothDevice = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al conectar con ${device.name}')),
      );
    }
  }

  void _sendCommand(String command) {
    if (_useBluetoothMode) {
      _bluetoothService.sendCommand(command);
    } else {
      _networkService.sendCommand(command);
    }
  }

  void _setVolume(double volume) {
    _currentVolume = volume;
    _sendCommand('setVolume:${volume.round()}');
    setState(() {});
  }

   void _setVolumePreset(String preset) {
    int volume = 0;
    switch (preset) {
      case 'low':
        volume = (_maxVolume * 0.25).round();
        break;
      case 'medium':
        volume = (_maxVolume * 0.5).round();
        break;
      case 'high':
        volume = (_maxVolume * 0.75).round();
        break;
      case 'mute':
        volume = 0;
        break;
    }
    _currentVolume = volume.toDouble();
    _sendCommand('setVolume:$preset'); // Send preset command
    setState(() {});
  }

  void _terminateControl() {
    _networkService.disconnectFromDevice();
     setState(() {
        _selectedDevice = null;
        _currentVolume = 0;
     });
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Control terminated.')),
      );
  }

  @override
  void dispose() {
    _networkService.dispose(); // Dispose the network service
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dispositivo Controlador'),
        actions: [
          Switch(
            value: _useBluetoothMode,
            onChanged: (value) => _toggleConnectionMode(),
          ),
          Text(_useBluetoothMode ? 'Bluetooth' : 'Red', 
               style: TextStyle(fontSize: 12)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _useBluetoothMode 
                ? 'Dispositivos Bluetooth Descubiertos:' 
                : 'Dispositivos en Red Descubiertos:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: _useBluetoothMode
                  ? (_discoveredBluetoothDevices.isEmpty
                      ? Center(child: Text('Buscando dispositivos Bluetooth...'))
                      : ListView.builder(
                          itemCount: _discoveredBluetoothDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredBluetoothDevices[index];
                            return ListTile(
                              title: Text(device.name),
                              subtitle: Text(device.address),
                              onTap: () => _connectToBluetoothDevice(device),
                              selected: _selectedBluetoothDevice?.address == device.address,
                            );
                          },
                        ))
                  : (_discoveredDevices.isEmpty
                      ? Center(child: Text('Buscando dispositivos en red...'))
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final device = _discoveredDevices[index];
                            return ListTile(
                              title: Text(device.id),
                              subtitle: Text(device.ipAddress),
                              onTap: () => _connectToDevice(device),
                              selected: _selectedDevice?.id == device.id,
                            );
                          },
                        )),
            ),
            SizedBox(height: 20),
            if ((_useBluetoothMode && _bluetoothService.isConnected) || 
                (!_useBluetoothMode && _networkService.isConnected()))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Controlando: ${_useBluetoothMode ? _selectedBluetoothDevice?.name : _selectedDevice?.id}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text('Volume Control'),
                  Slider(
                    value: _currentVolume,
                    max: _maxVolume.toDouble(),
                    divisions: _maxVolume,
                    label: _currentVolume.round().toString(),
                    onChanged: _setVolume,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: () => _setVolumePreset('low'), child: Text('Low')),
                      ElevatedButton(onPressed: () => _setVolumePreset('medium'), child: Text('Medium')),
                      ElevatedButton(onPressed: () => _setVolumePreset('high'), child: Text('High')),
                      ElevatedButton(onPressed: () => _setVolumePreset('mute'), child: Text('Mute')),
                    ],
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _terminateControl,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Terminate Control'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
