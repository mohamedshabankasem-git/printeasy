import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/printing/printer_transport.dart';

/// Bluetooth LE transport optimized for thermal-printer raster jobs.
class BlePrinterTransport implements PrinterTransport {
  BlePrinterTransport(String remoteId)
      : _device = BluetoothDevice.fromId(remoteId);

  final BluetoothDevice _device;
  BluetoothCharacteristic? _char;
  bool _noResponse = false;
  int _chunk = 20;
  int _delayMs = 2;
  Future<void> _writeQueue = Future<void>.value();

  @override
  bool get isConnected => _device.isConnected && _char != null;

  @override
  Future<void> connect() async {
    await _device.connect(timeout: const Duration(seconds: 20));

    try {
      var negotiatedMtu = 23;
      if (Platform.isAndroid) {
        try {
          negotiatedMtu = await _device.requestMtu(247);
        } catch (_) {
          // Keep the BLE default MTU when the printer rejects MTU negotiation.
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

      // Prefer no-response for high-volume raster data when supported.
      // GATT packet size is bounded by the negotiated MTU minus its 3-byte header.
      _noResponse = selected.properties.writeWithoutResponse;
      final negotiatedPayload = math.max(20, negotiatedMtu - 3);
      _chunk = math.min(180, negotiatedPayload);

      // A short pacing interval protects printer buffers without imposing
      // the large delay previously applied to every 20-byte packet.
      _delayMs = _noResponse ? 2 : 0;
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

    if (service.contains('18f0') ||
        service.contains('ff00') ||
        service.contains('ae00') ||
        service.contains('49535343')) {
      score += 100;
    }
    if (characteristic.contains('2af1') ||
        characteristic.contains('ff02') ||
        characteristic.contains('ae01') ||
        characteristic.contains('49535343')) {
      score += 80;
    }

    if (canWriteNoResponse) score += 10;
    if (canWrite) score += 5;
    return score;
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

      if (_delayMs > 0) {
        await Future.delayed(Duration(milliseconds: _delayMs));
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
