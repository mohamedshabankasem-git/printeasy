import 'dart:typed_data';
import 'dart:ui' as ui;

import 'escpos_commands.dart';
import 'print_block.dart';
import 'printer_transport.dart';
import 'raster_encoder.dart';
import 'receipt_renderer.dart';

/// إعدادات ESC/POS القياسية للطباعة الحرارية.
class PrintSettings {
  const PrintSettings({
    this.paperWidthMm = 58,
    this.density = 1,
    this.autoCut = true,
    this.tailFeedMm = 20,
    this.fontFamily,
  });

  final int paperWidthMm;
  final int density;
  final bool autoCut;
  final int tailFeedMm;
  final String? fontFamily;

  /// عرض الصورة القياسي عند 203 DPI.
  int get widthDots => paperWidthMm >= 80 ? 576 : 384;
  int get threshold => const [105, 128, 165][density.clamp(0, 2)];
}

class PrintCancelled implements Exception {
  @override
  String toString() => 'تم إلغاء الطباعة';
}

class PrintService {
  PrintService(this.transport, this.settings);

  final PrinterTransport transport;
  final PrintSettings settings;
  Future<void> _queue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return next;
  }

  Future<void> printBlocks(
    List<PrintBlock> blocks, {
    bool Function()? isCancelled,
  }) =>
      _enqueue(() => _printBlocks(blocks, isCancelled: isCancelled));

  /// كل جزء من الفاتورة يرسل كدفعة ESC/POS منطقية واحدة:
  /// ESC @ + أمر GS v 0 للصورة كاملة + تغذية + قص.
  /// طبقة Bluetooth فقط تجزئ بايتات الدفعة حسب حدود البروتوكول.
  Future<void> _printBlocks(
    List<PrintBlock> blocks, {
    bool Function()? isCancelled,
  }) async {
    final segments = <List<PrintBlock>>[[]];
    final cutAfter = <bool>[];
    for (final block in blocks) {
      if (block is CutBlock) {
        cutAfter.add(true);
        segments.add([]);
      } else {
        segments.last.add(block);
      }
    }
    cutAfter.add(false);

    final renderer = ReceiptRenderer(
      widthDots: settings.widthDots,
      fontFamily: settings.fontFamily,
    );

    for (var i = 0; i < segments.length; i++) {
      if (isCancelled?.call() ?? false) throw PrintCancelled();
      final segment = segments[i];
      if (segment.isEmpty) {
        if (cutAfter[i]) {
          await transport.write(EscPos().initialize().cut().build());
        }
        continue;
      }

      final image = await renderer.render(segment);
      try {
        final raster = await RasterEncoder.encode(
          image,
          threshold: settings.threshold,
        );
        final batch = BytesBuilder(copy: false)
          ..add(EscPos().initialize().build())
          ..add(raster)
          ..add(EscPos().feedDots(settings.tailFeedMm * 8).build());

        final isLast = i == segments.length - 1;
        if (cutAfter[i] || (isLast && settings.autoCut)) {
          batch.add(EscPos().cut().build());
        }
        await transport.write(batch.takeBytes());
      } finally {
        image.dispose();
      }
    }
  }

  Future<void> printImageJob(ui.Image image) => _enqueue(() async {
        final raster = await RasterEncoder.encode(
          image,
          threshold: settings.threshold,
        );
        final batch = BytesBuilder(copy: false)
          ..add(EscPos().initialize().build())
          ..add(raster)
          ..add(EscPos().feedDots(settings.tailFeedMm * 8).build());
        if (settings.autoCut) batch.add(EscPos().cut().build());
        await transport.write(batch.takeBytes());
      });

  Future<void> printImage(ui.Image image) => _enqueue(() async {
        final raster = await RasterEncoder.encode(
          image,
          threshold: settings.threshold,
        );
        await transport.write(raster);
      });

  Future<void> printRawText(
    String text, {
    PrintAlign align = PrintAlign.left,
    bool bold = false,
    int size = 1,
  }) =>
      _enqueue(() async {
        final command =
            EscPos().align(align).bold(bold).textSize(size, size).text(text);
        command.bold(false).textSize(1, 1);
        await transport.write(command.build());
      });

  Future<void> printQrNative(String data, {int moduleSize = 6}) =>
      _enqueue(() => transport.write(
            EscPos()
                .align(PrintAlign.center)
                .qrNative(data, moduleSize: moduleSize)
                .newLine()
                .build(),
          ));

  Future<void> printBarcodeNative(String data) =>
      _enqueue(() => transport.write(
            EscPos()
                .align(PrintAlign.center)
                .barcodeNative(data)
                .newLine()
                .build(),
          ));

  Future<void> feedMm(int mm) => _enqueue(() async {
        if (mm > 0) {
          await transport.write(EscPos().feedDots(mm * 8).build());
        }
      });

  Future<void> feedLines(int n) =>
      _enqueue(() => transport.write(EscPos().feedLines(n).build()));

  Future<void> cutPaper({bool partial = true}) =>
      _enqueue(() => transport.write(EscPos().cut(partial: partial).build()));

  Future<void> sendRaw(Uint8List bytes) =>
      _enqueue(() => transport.write(bytes));
}
