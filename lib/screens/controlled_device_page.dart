import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:myapp/services/network_service.dart';
import 'package:myapp/services/volume_control_service.dart';
import 'package:uuid/uuid.dart'; // Import the Uuid class

class ControlledDevicePage extends StatefulWidget {
  const ControlledDevicePage({super.key});

  @override
  _ControlledDevicePageState createState() => _ControlledDevicePageState();
}

class _ControlledDevicePageState extends State<ControlledDevicePage> {
  final _storage = FlutterSecureStorage();
  final _passwordController = TextEditingController();
  final _disablePasswordController = TextEditingController();
  final NetworkService _networkService = NetworkService();
  final BluetoothService _bluetoothService = BluetoothService();
  String _deviceId = 'Unknown';
  String? _storedPassword;
  bool _isControlActive = false;
  bool _useBluetoothMode = false;

  @override
  void initState() {
    super.initState();
    _initDevice();
  }

  Future<void> _initDevice() async {
    // Inicializar Bluetooth
    bool bluetoothEnabled = await _bluetoothService.initBluetooth();
    
    // Obtener ID del dispositivo almacenado
    String? storedId = await _storage.read(key: 'device_id');
    if (storedId != null) {
      setState(() {
        _deviceId = storedId;
      });
    }

    // Verificar si hay una contraseña almacenada
    String? storedPassword = await _storage.read(key: 'control_password');
    if (storedPassword != null) {
      setState(() {
        _storedPassword = storedPassword;
      });
      // Si hay una contraseña, activar el control automáticamente
      _startControlledMode();
    }
  }

  void _startControlledMode() {
    if (_useBluetoothMode) {
      // Iniciar servidor Bluetooth
      _bluetoothService.startBluetoothServer(_handleCommand);
    } else {
      // Iniciar servidor de red (código existente)
      _networkService.startBroadcasting(_deviceId);
      _networkService.startCommandServer(_handleCommand);
    }
    setState(() {
      _isControlActive = true;
    });
  }

  void _stopControlledMode() {
    if (_useBluetoothMode) {
      // Detener servidor Bluetooth
      _bluetoothService.disconnect();
    } else {
      // Detener servidor de red (código existente)
      _networkService.stopBroadcasting();
      _networkService.stopCommandServer();
    }
    setState(() {
      _isControlActive = false;
      _storedPassword = null;
    });
    _storage.delete(key: 'control_password');
  }

  void _handleCommand(String command) {
    print('Controlled Device Received command: $command');
    if (!_isControlActive) {
        print('Control is inactive, ignoring command.');
        return; // Ignore commands if control is not active
    }

    if (command.startsWith('setVolume:')) {
      try {
        final volumeValue = command.split(':')[1];
        int? volume;
        switch(volumeValue) {
            case 'low': volume = 3; break;
            case 'medium': volume = 7; break;
            case 'high': volume = 12; break;
            case 'mute': volume = 0; break;
            default: volume = int.tryParse(volumeValue);
        }

        if (volume != null) {
           VolumeControlService.setVolume(volume);
           print('Volume set to: $volume');
        } else {
            print('Invalid volume value: $volumeValue');
        }

      } catch (e) {
        print('Error processing volume command: $e');
      }
    }
    // TODO: Add other commands if necessary (e.g., lock/unlock control)
  }

  Future<void> _setPassword() async {
    if (_passwordController.text.isNotEmpty) {
      await _storage.write(key: 'control_password', value: _passwordController.text);
      _storedPassword = _passwordController.text;
      _passwordController.clear();
      _startControlledMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password set and control activated.')),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a password.')),
      );
    }
    setState(() {});
  }

  Future<void> _disableControl() async {
    if (_disablePasswordController.text == _storedPassword) {
      _stopControlledMode();
      _disablePasswordController.clear();
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Control deactivated.')),
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Incorrect password.')),
      );
    }
     setState(() {});
  }

    @override
  void dispose() {
    _networkService.stopBroadcasting();
    _networkService.stopCommandServer();
    _passwordController.dispose();
    _disablePasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dispositivo Controlado'),
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
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('Device ID: '), // Display device ID for pairing
                SelectableText(
                  _deviceId,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 40),
                _storedPassword == null
                    ? Column(
                        children: [Text('Set a password to activate control:'),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Enter password',
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _setPassword,
                              child: Text('Set Password and Activate'),
                            ),
                        ],
                      )
                    : Column(
                        children: [
                           Text(
                            _isControlActive ? 'Control Status: Active' : 'Control Status: Inactive',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isControlActive ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(height: 20),
                           Text('Enter password to disable control:'),
                            TextField(
                              controller: _disablePasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: 'Enter password',
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _disableControl,
                              child: Text('Disable Control'),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
