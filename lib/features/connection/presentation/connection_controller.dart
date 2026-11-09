import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/printing/printer_transport.dart';
import '../../../core/utils/permissions.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/ble_transport.dart';
import '../data/classic_transport.dart';
import '../data/discovery_service.dart';
import '../data/usb_transport.dart';
import '../domain/printer_device.dart';

enum LinkStatus { disconnected, connecting, connected, error }

class PrinterConnectionState {
  const PrinterConnectionState({
    this.status = LinkStatus.disconnected,
    this.device,
    this.lastPrinter,
    this.found = const [],
    this.scanning = false,
    this.error,
  });

  final LinkStatus status;
  final PrinterDevice? device; // الطابعة المتصلة حالياً
  final PrinterDevice? lastPrinter; // آخر طابعة محفوظة
  final List<PrinterDevice> found;
  final bool scanning;
  final String? error;

  bool get isConnected => status == LinkStatus.connected;

  PrinterConnectionState copyWith({
    LinkStatus? status,
    PrinterDevice? device,
    bool clearDevice = false,
    PrinterDevice? lastPrinter,
    List<PrinterDevice>? found,
    bool? scanning,
    String? error,
    bool clearError = false,
  }) =>
      PrinterConnectionState(
        status: status ?? this.status,
        device: clearDevice ? null : (device ?? this.device),
        lastPrinter: lastPrinter ?? this.lastPrinter,
        found: found ?? this.found,
        scanning: scanning ?? this.scanning,
        error: clearError ? null : (error ?? this.error),
      );
}

final connectionControllerProvider =
    NotifierProvider<ConnectionController, PrinterConnectionState>(ConnectionController.new);

class ConnectionController extends Notifier<PrinterConnectionState> {
  final DiscoveryService _discovery = DiscoveryService();
  PrinterTransport? _transport;
  StreamSubscription<List<PrinterDevice>>? _sub;

  /// الناقل الحالي للاستخدام من خدمة الطباعة
  PrinterTransport? get transport => _transport;

  @override
  PrinterConnectionState build() {
    ref.onDispose(() => _sub?.cancel());
    return PrinterConnectionState(lastPrinter: _loadLast());
  }

  // ---------- حفظ آخر طابعة ----------
  PrinterDevice? _loadLast() {
    final p = ref.read(sharedPrefsProvider);
    final id = p.getString('last_printer_id');
    final name = p.getString('last_printer_name');
    final link = p.getString('last_printer_link');
    if (id == null || name == null || link == null) return null;
    final l = PrinterLink.values.where((e) => e.name == link);
    if (l.isEmpty) return null;
    return PrinterDevice(id: id, name: name, link: l.first);
  }

  Future<void> _saveLast(PrinterDevice d) async {
    final p = ref.read(sharedPrefsProvider);
    await p.setString('last_printer_id', d.id);
    await p.setString('last_printer_name', d.name);
    await p.setString('last_printer_link', d.link.name);
  }

  Future<void> forgetLast() async {
    final p = ref.read(sharedPrefsProvider);
    await p.remove('last_printer_id');
    await p.remove('last_printer_name');
    await p.remove('last_printer_link');
    state = PrinterConnectionState(
      status: state.status,
      device: state.device,
      found: state.found,
      scanning: state.scanning,
    );
  }

  // ---------- البحث ----------
  Future<void> scan() async {
    if (state.scanning) return;
    final ok = await AppPermissions.ensureBluetooth();
    if (!ok) {
      state = state.copyWith(error: 'يلزم منح أذونات البلوتوث من إعدادات الجهاز');
      return;
    }
    state = state.copyWith(scanning: true, found: [], clearError: true);
    try {
      final base = <PrinterDevice>[
        ...await _discovery.classicPaired(),
        ...await _discovery.usbDevices(),
      ];
      state = state.copyWith(found: base);

      final done = Completer<void>();
      await _sub?.cancel();
      _sub = _discovery.scanBle(timeout: const Duration(seconds: 8)).listen(
        (ble) {
          final map = {for (final d in base) d.key: d};
          for (final d in ble) {
            map[d.key] = d;
          }
          state = state.copyWith(found: map.values.toList());
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
    } catch (e) {
      state = state.copyWith(error: 'تعذر البحث: $e');
    }
    state = state.copyWith(scanning: false);
  }

  // ---------- الاتصال ----------
  PrinterTransport _create(PrinterDevice d) => switch (d.link) {
        PrinterLink.ble => BlePrinterTransport(d.id),
        PrinterLink.classic => ClassicPrinterTransport(d.id),
        PrinterLink.usb => UsbPrinterTransport(d.id),
      };

  Future<bool> connect(PrinterDevice d) async {
    state = state.copyWith(status: LinkStatus.connecting, clearError: true);
    try {
      await _transport?.disconnect();
      final t = _create(d);
      await t.connect();
      _transport = t;
      await _saveLast(d);
      state = state.copyWith(status: LinkStatus.connected, device: d, lastPrinter: d);
      return true;
    } catch (e) {
      _transport = null;
      state = state.copyWith(
        status: LinkStatus.error,
        clearDevice: true,
        error: 'تعذر الاتصال: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      return false;
    }
  }

  Future<bool> reconnectLast() async {
    final d = state.lastPrinter;
    if (d == null) return false;
    return connect(d);
  }

  Future<void> disconnect() async {
    await _transport?.disconnect();
    _transport = null;
    state = state.copyWith(status: LinkStatus.disconnected, clearDevice: true);
  }
}
