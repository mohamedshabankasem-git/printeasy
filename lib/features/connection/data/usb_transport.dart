import 'dart:math' as math;
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import '../../../core/printing/printer_transport.dart';

/// اتصال USB عبر OTG باستخدام usb_serial.
/// ملاحظة: يعمل مع الطابعات التي تظهر كمنفذ تسلسلي (CDC/FTDI/CH34x...).
class UsbPrinterTransport implements PrinterTransport {
  UsbPrinterTransport(this.deviceName);

  final String deviceName;
  UsbPort? _port;

  @override
  bool get isConnected => _port != null;

  @override
  Future<void> connect() async {
    final devices = await UsbSerial.listDevices();
    final matches = devices.where((d) => d.deviceName == deviceName);
    if (matches.isEmpty) throw Exception('جهاز USB غير موجود');
    final port = await matches.first.create();
    if (port == null) throw Exception('تعذر إنشاء منفذ USB');
    final opened = await port.open();
    if (!opened) throw Exception('تعذر فتح منفذ USB (تحقق من إذن الوصول)');
    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    _port = port;
  }

  @override
  Future<void> write(Uint8List data) async {
    final p = _port;
    if (p == null) throw Exception('الطابعة غير متصلة');
    const chunk = 4096;
    for (var i = 0; i < data.length; i += chunk) {
      await p.write(data.sublist(i, math.min(i + chunk, data.length)));
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _port?.close();
    } catch (_) {}
    _port = null;
  }
}
