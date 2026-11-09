import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/printing/printer_transport.dart';

/// اتصال Bluetooth LE عبر flutter_blue_plus
class BlePrinterTransport implements PrinterTransport {
  BlePrinterTransport(String remoteId) : _device = BluetoothDevice.fromId(remoteId);

  final BluetoothDevice _device;
  BluetoothCharacteristic? _char;
  bool _noResponse = false;
  int _chunk = 20;

  @override
  bool get isConnected => _device.isConnected && _char != null;

  @override
  Future<void> connect() async {
    await _device.connect(timeout: const Duration(seconds: 15));
    if (Platform.isAndroid) {
      try {
        await _device.requestMtu(247);
      } catch (_) {/* بعض الطابعات ترفض طلب MTU */}
    }
    final services = await _device.discoverServices();

    BluetoothCharacteristic? best;
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.writeWithoutResponse) {
          best = c; // نفضّل الكتابة بدون استجابة لأنها أسرع
          break;
        }
        if (best == null && c.properties.write) best = c;
      }
      if (best != null && best.properties.writeWithoutResponse) break;
    }
    if (best == null) {
      await _device.disconnect();
      throw Exception('لم يتم العثور على قناة كتابة في هذه الطابعة');
    }
    _char = best;
    _noResponse = best.properties.writeWithoutResponse;
    _chunk = math.max(20, math.min(_device.mtuNow - 3, 240));
  }

  @override
  Future<void> write(Uint8List data) async {
    final c = _char;
    if (c == null) throw Exception('الطابعة غير متصلة');
    for (var i = 0; i < data.length; i += _chunk) {
      final end = math.min(i + _chunk, data.length);
      await c.write(data.sublist(i, end), withoutResponse: _noResponse);
      if (_noResponse) await Future.delayed(const Duration(milliseconds: 6));
    }
  }

  @override
  Future<void> disconnect() async {
    _char = null;
    try {
      await _device.disconnect();
    } catch (_) {}
  }
}
