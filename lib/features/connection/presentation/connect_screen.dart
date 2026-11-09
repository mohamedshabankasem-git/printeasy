import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/printer_device.dart';
import 'connection_controller.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(connectionControllerProvider.notifier).scan());
  }

  IconData _icon(PrinterLink l) => switch (l) {
        PrinterLink.classic => Icons.bluetooth,
        PrinterLink.ble => Icons.bluetooth_searching,
        PrinterLink.usb => Icons.usb,
      };

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(connectionControllerProvider);
    final ctrl = ref.read(connectionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاتصال بالطابعة'),
        actions: [
          IconButton(
            tooltip: 'بحث',
            onPressed: st.scanning ? null : ctrl.scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (st.scanning || st.status == LinkStatus.connecting) const LinearProgressIndicator(),
          if (st.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(st.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: st.found.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        st.scanning
                            ? 'جارٍ البحث عن الطابعات...'
                            : 'لا توجد طابعات.\nاقرن طابعة Classic من إعدادات الجهاز، أو وصّل طابعة USB عبر OTG ثم أعد البحث.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: st.found.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = st.found[i];
                      final connected = st.device?.key == d.key && st.isConnected;
                      return ListTile(
                        leading: Icon(_icon(d.link)),
                        title: Text(d.name),
                        subtitle: Text('${d.linkLabel} • ${d.id}'),
                        trailing: connected
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: st.status == LinkStatus.connecting
                            ? null
                            : () async {
                                final ok = await ctrl.connect(d);
                                if (ok && context.mounted) context.pop();
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
