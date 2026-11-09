import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:usb_serial/usb_serial.dart';
import '../domain/printer_device.dart';

/// البحث عن الطابعات: Classic (المقترنة) + USB (OTG) + BLE (مسح مباشر)
class DiscoveryService {
  Future<List<PrinterDevice>> classicPaired() async {
    try {
      final list = await PrintBluetoothThermal.pairedBluetooths;
      return list
          .map((b) => PrinterDevice(id: b.macAdress, name: b.name, link: PrinterLink.classic))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PrinterDevice>> usbDevices() async {
    try {
      final list = await UsbSerial.listDevices();
      return list
          .map((d) => PrinterDevice(
                id: d.deviceName,
                name: (d.productName?.isNotEmpty ?? false)
                    ? d.productName!
                    : 'USB ${d.vid?.toRadixString(16)}:${d.pid?.toRadixString(16)}',
                link: PrinterLink.usb,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// مسح BLE؛ يُصدر قائمة متراكمة ويُغلق بعد انتهاء المهلة
  Stream<List<PrinterDevice>> scanBle({required Duration timeout}) {
    final controller = StreamController<List<PrinterDevice>>();
    () async {
      StreamSubscription<List<ScanResult>>? sub;
      try {
        sub = FlutterBluePlus.scanResults.listen((results) {
          controller.add(results
              .where((r) => r.device.platformName.isNotEmpty)
              .map((r) => PrinterDevice(
                    id: r.device.remoteId.str,
                    name: r.device.platformName,
                    link: PrinterLink.ble,
                  ))
              .toList());
        });
        await FlutterBluePlus.startScan(timeout: timeout);
        await Future.delayed(timeout + const Duration(milliseconds: 300));
      } catch (e) {
        controller.addError(e);
      } finally {
        await sub?.cancel();
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
        await controller.close();
      }
    }();
    return controller.stream;
  }
}
