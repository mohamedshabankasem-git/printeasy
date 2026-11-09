import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// محتوى مُشارَك من تطبيق آخر: نص أو صورة
class SharedPayload {
  const SharedPayload({this.text, this.imageBytes});
  final String? text;
  final Uint8List? imageBytes;
}

/// يستمع لعمليات المشاركة (واتساب، المعرض...) ويفتح شاشة /share
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
      // التطبيق مفتوح أصلاً
      _sub = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
      // التطبيق فُتح عن طريق المشاركة
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handle(files);
        ReceiveSharingIntent.instance.reset();
      });
    } catch (_) {}
  }

  Future<void> _handle(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    String? text;
    Uint8List? image;

    for (final f in files) {
      final kind = f.type.name; // image / text / url / video / file
      if (kind == 'text' || kind == 'url') {
        text ??= f.path; // في النص، path يحمل المحتوى نفسه
      } else if (kind == 'image' && image == null) {
        try {
          image = await File(f.path).readAsBytes();
        } catch (_) {}
      }
    }
    if (text == null && image == null) return;

    final payload = SharedPayload(text: text, imageBytes: image);
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
