import 'package:flutter/material.dart';
import 'package:myapp/services/network_service.dart';
import 'package:provider/provider.dart';

class BossDevicePage extends StatefulWidget {
  const BossDevicePage({super.key});

  @override
  _BossDevicePageState createState() => _BossDevicePageState();
}

class _BossDevicePageState extends State<BossDevicePage> {
  final NetworkService _networkService = NetworkService();
  final List<DeviceInfo> _discoveredDevices = [];
  DeviceInfo? _selectedDevice;
  double _currentVolume = 0;
  final int _maxVolume = 15; // Assuming a default max volume for the slider

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  void _startDiscovery() {
    _networkService.listenForDevices().listen((device) {
      if (!_discoveredDevices.contains(device)) {
        setState(() {
          _discoveredDevices.add(device);
        });
      }
    });
  }

  void _connectToDevice(DeviceInfo device) async {
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

  void _sendCommand(String command) {
    _networkService.sendCommand(command);
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
        title: Text('Boss Device'),
      ),
      body: ChangeNotifierProvider( // Use ChangeNotifierProvider here
        create: (context) => _networkService, // Provide the existing instance
        child: Consumer<NetworkService>( // Use Consumer to rebuild when notifyListeners is called
          builder: (context, networkService, child) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Discovered Devices:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: _discoveredDevices.isEmpty
                        ? Center(child: Text('Scanning for devices...'))
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
                          ),
                  ),
                  SizedBox(height: 20),
                   if (networkService.isConnected()) // Use networkService.isConnected()
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(
                          'Controlling: ${_selectedDevice?.id}',
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
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
