import 'dart:typed_data';

/// واجهة موحّدة لأي وسيلة اتصال بالطابعة (BLE / Classic / USB)
abstract class PrinterTransport {
  Future<void> connect();
  Future<void> write(Uint8List data);
  Future<void> disconnect();
  bool get isConnected;
}
