import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/printing/printer_transport.dart';

/// اتصال Bluetooth LE.
///
/// طابعات الإيصالات BLE كثيراً ما يكون مخزن استقبالها صغيراً؛ لذلك نستخدم
/// حزم GATT محافظة ومتتابعة بدلاً من إرسال كتل كبيرة بسرعة قد تُفقد منها بايتات.
class BlePrinterTransport implements PrinterTransport {
  BlePrinterTransport(String remoteId)
      : _device = BluetoothDevice.fromId(remoteId);

  final BluetoothDevice _device;
  BluetoothCharacteristic? _char;
  bool _noResponse = false;
  int _chunk = 20;
  Future<void> _writeQueue = Future<void>.value();

  @override
  bool get isConnected => _device.isConnected && _char != null;

  @override
  Future<void> connect() async {
    await _device.connect(timeout: const Duration(seconds: 20));

    try {
      if (Platform.isAndroid) {
        try {
          await _device.requestMtu(247);
        } catch (_) {
          // بعض طابعات BLE لا تدعم تغيير MTU؛ نستخدم الحجم الآمن 20 بايت.
        }
      }

      final services = await _device.discoverServices();
      final candidates = <_WritableCandidate>[];

      for (final service in services) {
        for (final characteristic in service.characteristics) {
          final canWrite = characteristic.properties.write;
          final canWriteNoResponse =
              characteristic.properties.writeWithoutResponse;
          if (!canWrite && !canWriteNoResponse) continue;

          candidates.add(
            _WritableCandidate(
              characteristic: characteristic,
              score: _candidateScore(
                service.uuid.str,
                characteristic.uuid.str,
                canWrite,
                canWriteNoResponse,
              ),
            ),
          );
        }
      }

      if (candidates.isEmpty) {
        throw Exception('لم يتم العثور على قناة كتابة في طابعة BLE');
      }

      candidates.sort((a, b) => b.score.compareTo(a.score));
      final selected = candidates.first.characteristic;
      _char = selected;

      // عند توفر الخيارين نفضّل write-with-response لتأكيد استلام الحزمة
      // وتقليل فقد البيانات. نستخدم no-response فقط إذا كان هو المدعوم وحده.
      _noResponse = !selected.properties.write && 
          selected.properties.writeWithoutResponse;

      // لا نفترض أن MTU الكبير يعني أن مخزن الطابعة كبير.
      // 20 بايت هو الحجم الأكثر تحفظاً وتوافقاً مع طابعات BLE الحرارية.
      _chunk = 20;
    } catch (_) {
      _char = null;
      try {
        await _device.disconnect();
      } catch (_) {}
      rethrow;
    }
  }

  int _candidateScore(
    String serviceUuid,
    String characteristicUuid,
    bool canWrite,
    bool canWriteNoResponse,
  ) {
    final service = serviceUuid.toLowerCase();
    final characteristic = characteristicUuid.toLowerCase();
    var score = 0;

    // UUIDs شائعة في وحدات طابعات BLE الحرارية. هذه مجرد أولوية
    // للاختيار وليست ادعاءً بأن كل الطابعات تستخدمها.
    if (service.contains('18f0') || service.contains('ff00') ||
        service.contains('ae00') || service.contains('49535343')) {
      score += 100;
    }
    if (characteristic.contains('2af1') || characteristic.contains('ff02') ||
        characteristic.contains('ae01') ||
        characteristic.contains('49535343')) {
      score += 80;
    }

    if (canWrite) score += 10;
    if (canWriteNoResponse) score += 5;
    return score;
  }

  @override
  Future<void> write(Uint8List data) {
    final next = _writeQueue.then((_) => _writeChunks(data));
    // فشل إرسال سابق لا يمنع محاولة المهمة التالية بعد إعادة الاتصال.
    _writeQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<void> _writeChunks(Uint8List data) async {
    final characteristic = _char;
    if (characteristic == null || !_device.isConnected) {
      throw Exception('الطابعة غير متصلة عبر BLE');
    }

    for (var offset = 0; offset < data.length; offset += _chunk) {
      if (!_device.isConnected || _char == null) {
        throw Exception('انقطع اتصال BLE أثناء الطباعة');
      }

      final end = math.min(offset + _chunk, data.length);
      await characteristic.write(
        data.sublist(offset, end),
        withoutResponse: _noResponse,
        timeout: 15,
      );

      // الكتابة دون استجابة لا توفر تأكيداً من GATT؛ نعطي الطابعة وقتاً
      // لمعالجة كل حزمة قبل إرسال التالية لتقليل امتلاء مخزن الاستقبال.
      if (_noResponse) {
        await Future.delayed(const Duration(milliseconds: 12));
      }
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

class _WritableCandidate {
  const _WritableCandidate({
    required this.characteristic,
    required this.score,
  });

  final BluetoothCharacteristic characteristic;
  final int score;
}
