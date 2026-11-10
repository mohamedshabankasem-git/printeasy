import 'dart:math' as math;
import 'dart:typed_data';

import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/printing/printer_transport.dart';

/// Bluetooth Classic (SPP). The printer must be paired in Android settings.
class ClassicPrinterTransport implements PrinterTransport {
  ClassicPrinterTransport(this.mac);

  final String mac;
  bool _connected = false;
  Future<void> _writeQueue = Future<void>.value();

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    if (!ok) {
      throw Exception('فشل الاتصال بالطابعة (تأكد أنها مقترنة ومفعّلة)');
    }
    _connected = true;
  }

  @override
  Future<void> write(Uint8List data) {
    final next = _writeQueue.then((_) => _writeChunks(data));
    _writeQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<void> _writeChunks(Uint8List data) async {
    if (!_connected) {
      throw Exception('الطابعة غير متصلة عبر Bluetooth Classic');
    }

    // Larger SPP writes reduce per-call overhead. Each write is awaited,
    // so chunks remain ordered and the printer's socket applies backpressure.
    const chunkSize = 1024;
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      if (!_connected) {
        throw Exception('انقطع الاتصال أثناء الإرسال');
      }

      final end = math.min(offset + chunkSize, data.length);
      final ok = await PrintBluetoothThermal.writeBytes(
        data.sublist(offset, end).toList(),
      );
      if (!ok) {
        _connected = false;
        throw Exception('انقطع الاتصال أثناء الإرسال');
      }
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
