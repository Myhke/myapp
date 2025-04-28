import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothDeviceInfo {
  final String address;
  final String name;

  BluetoothDeviceInfo({required this.address, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDeviceInfo && 
      runtimeType == other.runtimeType && 
      address == other.address;

  @override
  int get hashCode => address.hashCode;
}

class BluetoothService with ChangeNotifier {
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  StreamSubscription? _discoveryStreamSubscription;
  StreamSubscription? _dataStreamSubscription;
  
  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;
  
  bool get isConnected => _connection != null;
  
  // Para el dispositivo controlado
  Function(String)? _onCommandReceived;

  // Inicializar Bluetooth
  Future<bool> initBluetooth() async {
    try {
      // Verificar si el Bluetooth está habilitado
      bool? isEnabled = await _bluetooth.isEnabled;
      if (isEnabled != true) {
        // Solicitar al usuario que active el Bluetooth
        await _bluetooth.requestEnable();
      }
      return await _bluetooth.isEnabled ?? false;
    } catch (e) {
      print('Error al inicializar Bluetooth: $e');
      return false;
    }
  }

  // Descubrir dispositivos Bluetooth (para el dispositivo controlador)
  Stream<BluetoothDeviceInfo> discoverDevices() async* {
    _isDiscovering = true;
    notifyListeners();
    
    try {
      _discoveryStreamSubscription = _bluetooth.startDiscovery().listen((result) {
        if (result.device.name != null) {
          final deviceInfo = BluetoothDeviceInfo(
            address: result.device.address,
            name: result.device.name ?? 'Desconocido'
          );
          
          // No podemos usar yield dentro de un listener, así que usamos un controlador
        }
      });
      
      // Crear un StreamController para manejar los dispositivos descubiertos
      final controller = StreamController<BluetoothDeviceInfo>();
      
      _discoveryStreamSubscription = _bluetooth.startDiscovery().listen((result) {
        if (result.device.name != null) {
          final deviceInfo = BluetoothDeviceInfo(
            address: result.device.address,
            name: result.device.name ?? 'Desconocido'
          );
          controller.add(deviceInfo);
        }
      });
      
      // Cuando se complete la búsqueda
      _discoveryStreamSubscription?.onDone(() {
        _isDiscovering = false;
        notifyListeners();
        controller.close();
      });
      
      // Devolver el stream del controlador
      yield* controller.stream;
    } catch (e) {
      print('Error al descubrir dispositivos Bluetooth: $e');
      _isDiscovering = false;
      notifyListeners();
    }
  }

  // Detener la búsqueda de dispositivos
  void stopDiscovery() {
    _discoveryStreamSubscription?.cancel();
    _isDiscovering = false;
    notifyListeners();
  }

  // Conectar a un dispositivo (para el dispositivo controlador)
  Future<bool> connectToDevice(String address) async {
    try {
      _connection = await BluetoothConnection.toAddress(address);
      print('Conectado a dispositivo Bluetooth: $address');
      
      // Configurar listener para recibir datos
      _dataStreamSubscription = _connection!.input?.listen((Uint8List data) {
        // Procesar datos recibidos si es necesario
        final String message = utf8.decode(data);
        print('Mensaje recibido: $message');
      });
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Error al conectar con dispositivo Bluetooth: $e');
      return false;
    }
  }

  // Iniciar servidor Bluetooth (para el dispositivo controlado)
  Future<void> startBluetoothServer(Function(String) onCommandReceived) async {
    _onCommandReceived = onCommandReceived;
    
    // Hacer que el dispositivo sea visible para otros
    await _bluetooth.requestDiscoverable(60); // Visible por 60 segundos
    
    // Obtener el adaptador Bluetooth
    BluetoothDevice? localDevice = await _bluetooth.getBondedDevices()
        .then((List<BluetoothDevice> devices) {
      return devices.firstWhere((device) => device.isLocalDevice, orElse: () => devices.first);
    });
    
    print('Dispositivo local: ${localDevice?.name}, ${localDevice?.address}');
    
    // Nota: Flutter Bluetooth Serial no tiene un método directo para actuar como servidor
    // En una implementación real, necesitarías usar un plugin más avanzado o
    // implementar la funcionalidad específica para cada plataforma
  }

  // Enviar comando (para el dispositivo controlador)
  void sendCommand(String command) {
    if (_connection != null && _connection!.isConnected) {
      print('Enviando comando Bluetooth: $command');
      _connection!.output.add(utf8.encode(command));
      _connection!.output.allSent.then((_) {
        print('Comando enviado');
      });
    } else {
      print('No hay conexión Bluetooth para enviar comando');
    }
  }

  // Desconectar
  void disconnect() {
    _dataStreamSubscription?.cancel();
    _connection?.close();
    _connection = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    disconnect();
    super.dispose();
  }
}