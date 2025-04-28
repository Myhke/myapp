import 'package:flutter/services.dart';

class VolumeControlService {
  static const MethodChannel _channel = MethodChannel('com.example.myapp/volumecontrol');

  static Future<int> getVolume() async {
    try {
      final int volume = await _channel.invokeMethod('getVolume');
      return volume;
    } on PlatformException catch (e) {
      print("Failed to get volume: ${e.message}"); // Fixed escape character
      return 0;
    }
  }

  static Future<int> getMaxVolume() async {
    try {
      final int maxVolume = await _channel.invokeMethod('getMaxVolume');
      return maxVolume;
    } on PlatformException catch (e) {
      print("Failed to get max volume: ${e.message}"); // Fixed escape character
      return 15; // Default max volume if fetching fails
    }
  }

  static Future<void> setVolume(int volume) async {
    try {
      await _channel.invokeMethod('setVolume', {'volume': volume});
    } on PlatformException catch (e) {
      print("Failed to set volume: ${e.message}"); // Fixed escape character
    }
  }
}
