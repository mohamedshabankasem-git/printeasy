import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  /// طلب أذونات البلوتوث (أندرويد 12+: SCAN/CONNECT، الأقدم: الموقع)
  static Future<bool> ensureBluetooth() async {
    if (!Platform.isAndroid) return true;
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    final connect = result[Permission.bluetoothConnect]?.isGranted ?? false;
    final scan = result[Permission.bluetoothScan]?.isGranted ?? false;
    final loc = result[Permission.locationWhenInUse]?.isGranted ?? false;
    return (connect && scan) || loc;
  }
}
