import 'dart:math' as math;
import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/printing/printer_transport.dart';

/// اتصال Bluetooth Classic (SPP) — الطابعة يجب أن تكون مقترنة من إعدادات الجهاز
class ClassicPrinterTransport implements PrinterTransport {
  ClassicPrinterTransport(this.mac);

  final String mac;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) throw Exception('فشل الاتصال بالطابعة (تأكد أنها مقترنة ومفعّلة)');
    _connected = true;
  }

  @override
  Future<void> write(Uint8List data) async {
    const chunk = 1024;
    for (var i = 0; i < data.length; i += chunk) {
      final end = math.min(i + chunk, data.length);
      final ok = await PrintBluetoothThermal.writeBytes(data.sublist(i, end).toList());
      if (!ok) {
        _connected = false;
        throw Exception('انقطع الاتصال أثناء الإرسال');
      }
      await Future.delayed(const Duration(milliseconds: 8));
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }
}
