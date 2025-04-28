import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class DeviceInfo {
  final String ipAddress;
  final String id;

  DeviceInfo({required this.ipAddress, required this.id});

  Map<String, dynamic> toJson() => {
    'ip': ipAddress,
    'id': id,
  };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    ipAddress: json['ip'],
    id: json['id'],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo && runtimeType == other.runtimeType && ipAddress == other.ipAddress && id == other.id;

  @override
  int get hashCode => ipAddress.hashCode ^ id.hashCode;
}

class NetworkService with ChangeNotifier {
  static const int DISCOVERY_PORT = 5000;
  static const int COMMAND_PORT = 5001;
  static const String DISCOVERY_MESSAGE = 'remote_volume_control_discovery';

  RawDatagramSocket? _discoverySocket;
  ServerSocket? _commandServerSocket;
  Socket? _commandClientSocket;
  bool _useBluetooth = false;

  // Getter para determinar si se está usando Bluetooth
  bool get useBluetooth => _useBluetooth;

  // Setter para cambiar entre Bluetooth y red
  set useBluetooth(bool value) {
    _useBluetooth = value;
    notifyListeners();
  }
  
  // Para controlled device to broadcast its presence
  Future<void> startBroadcasting(String deviceId) async {
    _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    Timer.periodic(Duration(seconds: 5), (Timer t) {
      final message = '$DISCOVERY_MESSAGE:$deviceId';
      final Uint8List dataToSend = utf8.encode(message);
      final Uint8List broadcastAddress = Uint8List.fromList([255, 255, 255, 255]);
      _discoverySocket?.broadcastEnabled = true;
      
      _discoverySocket?.send(dataToSend, InternetAddress.fromRawAddress(broadcastAddress), DISCOVERY_PORT);
      
      print('Broadcasting: $message');
    });    
  }

  void stopBroadcasting() {
    _discoverySocket?.close();
    _discoverySocket = null;
  }

  // For boss device to listen for broadcasts
  Stream<DeviceInfo> listenForDevices() async* {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, DISCOVERY_PORT);
    print('Listening for devices on port $DISCOVERY_PORT');

    await for (RawSocketEvent event in socket) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram != null) {
          final message = utf8.decode(datagram.data);
          // print('Received broadcast: $message from ${datagram.address.host}');
          if (message.startsWith(DISCOVERY_MESSAGE)) {
            final parts = message.split(':');
            if (parts.length == 2) {
              final deviceId = parts[1];
              final ipAddress = datagram.address.host;
              yield DeviceInfo(ipAddress: ipAddress, id: deviceId);
            }
          }
        }
      }
    }
  }

  // For controlled device to start listening for commands
  Future<void> startCommandServer(Function(String) onCommandReceived) async {
    _commandServerSocket = await ServerSocket.bind(InternetAddress.anyIPv4, COMMAND_PORT);
    print('Command server listening on port $COMMAND_PORT');

    _commandServerSocket?.listen((Socket client) {
      _commandClientSocket = client;
      print('Client connected: ${client.remoteAddress.host}');
      client.listen(
        (data) {
          final command = utf8.decode(data);
          print('Received command: $command');
          onCommandReceived(command);
        },
        onError: (error) {
          print('Error on client socket: $error');
          client.close();
        },
        onDone: () {
          print('Client disconnected');
          _commandClientSocket = null;
          client.close();
        },
      );
    });
  }

  void stopCommandServer() {
    _commandClientSocket?.close();
    _commandServerSocket?.close();
    _commandServerSocket = null;
  }

  // For boss device to connect to a controlled device
  Future<bool> connectToDevice(String ipAddress) async {
    try {
      _commandClientSocket = await Socket.connect(ipAddress, COMMAND_PORT, timeout: Duration(seconds: 5));
      print('Connected to $ipAddress:$COMMAND_PORT');
       // Start listening for responses (optional, but good practice)
      _commandClientSocket?.listen(
        (data) {
          // Handle response if necessary
          print('Received response: ${utf8.decode(data)}');
        },
        onError: (error) {
          print('Error on boss socket: $error');
           _commandClientSocket?.close();
           _commandClientSocket = null;
           notifyListeners();
        },
        onDone: () {
          print('Boss socket disconnected');
          _commandClientSocket?.close();
          _commandClientSocket = null;
          notifyListeners();
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      print('Failed to connect to $ipAddress: $e');
      _commandClientSocket?.close();
      _commandClientSocket = null;
      notifyListeners();
      return false;
    }
  }

  void disconnectFromDevice(){
    _commandClientSocket?.close();
    _commandClientSocket = null;
    notifyListeners();
  }

  // For boss device to send a command
  void sendCommand(String command) {
    if (_commandClientSocket != null) {
      print('Sending command: $command');
      _commandClientSocket?.write(command);
    } else {
      print('No client connected to send command');
    }
  }

  bool isConnected(){
    return _commandClientSocket != null;
  }

  @override
  void dispose() {
    stopBroadcasting();
    stopCommandServer();
    disconnectFromDevice();
    super.dispose();
  }
}
