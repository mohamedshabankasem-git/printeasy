import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// عنصر واحد وصل من قائمة المشاركة.
class SharedItem {
  const SharedItem({
    required this.name,
    required this.kind,
    this.bytes,
    this.text,
  });

  final String name;
  final String kind; // image, text, file, other
  final Uint8List? bytes;
  final String? text;

  bool get isImage {
    final n = name.toLowerCase();
    return kind == 'image' ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp');
  }
}

/// محتوى المشاركة، مع الاحتفاظ بكل العناصر بدلاً من إسقاط الملفات الإضافية.
class SharedPayload {
  const SharedPayload({required this.items});
  final List<SharedItem> items;
}

/// يستمع لعمليات المشاركة ويفتح شاشة المعاينة والطباعة.
class ShareIntentListener extends StatefulWidget {
  const ShareIntentListener({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  @override
  State<ShareIntentListener> createState() => _ShareIntentListenerState();
}

class _ShareIntentListenerState extends State<ShareIntentListener> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handle(files);
        ReceiveSharingIntent.instance.reset();
      });
    } catch (_) {}
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final items = <SharedItem>[];

    for (final f in files) {
      final kind = f.type.name;
      final path = f.path;
      final name = path.replaceAll('\\\\', '/').split('/').last;
      if (kind == 'text' || kind == 'url') {
        items.add(SharedItem(name: name.isEmpty ? 'نص مشترك' : name, kind: 'text', text: path));
        continue;
      }
      if (kind == 'image' || kind == 'file') {
        try {
          final bytes = await File(path).readAsBytes();
          items.add(SharedItem(name: name, kind: kind, bytes: bytes));
        } catch (_) {
          items.add(SharedItem(name: name, kind: 'other'));
        }
      } else {
        items.add(SharedItem(name: name, kind: 'other'));
      }
    }

    if (items.isEmpty) return;
    final payload = SharedPayload(items: List.unmodifiable(items));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.router.push('/share', extra: payload);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
