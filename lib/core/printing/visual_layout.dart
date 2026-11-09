import 'dart:convert';
import 'escpos_commands.dart';

enum VisualType { text, qr, image, line }

/// عنصر في القالب المرئي. الإحداثيات بالنقاط (نفس وحدات عرض الورق)
class VisualElement {
  VisualElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.text = '',
    this.bold = false,
    this.size = 1,
    this.align = PrintAlign.right,
    this.imageB64,
  });

  final String id;
  final VisualType type;
  double x, y, w, h;
  String text; // النص، أو بيانات QR
  bool bold;
  int size; // 1..4
  PrintAlign align;
  String? imageB64;

  VisualElement copy() => VisualElement(
        id: id, type: type, x: x, y: y, w: w, h: h,
        text: text, bold: bold, size: size, align: align, imageB64: imageB64,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'text': text,
        'bold': bold,
        'size': size,
        'align': align.name,
        if (imageB64 != null) 'img': imageB64,
      };

  factory VisualElement.fromJson(Map<String, dynamic> j) => VisualElement(
        id: j['id'] as String,
        type: VisualType.values.firstWhere((t) => t.name == j['type'], orElse: () => VisualType.text),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        w: (j['w'] as num).toDouble(),
        h: (j['h'] as num).toDouble(),
        text: (j['text'] as String?) ?? '',
        bold: (j['bold'] as bool?) ?? false,
        size: (j['size'] as int?) ?? 1,
        align: PrintAlign.values.firstWhere((a) => a.name == j['align'], orElse: () => PrintAlign.right),
        imageB64: j['img'] as String?,
      );
}

/// القالب المرئي كاملاً؛ يُحفظ كـ JSON في عمود content
class VisualLayout {
  VisualLayout({this.height = 420, List<VisualElement>? elements}) : elements = elements ?? [];

  double height;
  final List<VisualElement> elements;

  static final RegExp _varRe = RegExp(r'\{([A-Za-z0-9_\u0600-\u06FF]+)\}');

  String toJsonString() => jsonEncode({
        'v': 1,
        'height': height,
        'elements': elements.map((e) => e.toJson()).toList(),
      });

  /// يُرجع null إن لم يكن النص قالباً مرئياً (أي هو DSL عادي)
  static VisualLayout? tryParse(String source) {
    final t = source.trimLeft();
    if (!t.startsWith('{')) return null;
    try {
      final m = jsonDecode(t);
      if (m is Map<String, dynamic> && m['elements'] is List) {
        return VisualLayout(
          height: (m['height'] as num?)?.toDouble() ?? 420,
          elements: (m['elements'] as List)
              .map((e) => VisualElement.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// المتغيرات {key} المستخدمة في نصوص العناصر وQR
  List<String> get variables {
    final out = <String>{};
    for (final e in elements) {
      if (e.type == VisualType.text || e.type == VisualType.qr) {
        for (final m in _varRe.allMatches(e.text)) {
          out.add(m[1]!);
        }
      }
    }
    return out.toList();
  }

  /// نسخة مع تعويض المتغيرات. أسطر #row: (من الفاتورة) تتحول لنص عادي
  VisualLayout filled(Map<String, String> vars) {
    String sub(String s) => s.replaceAllMapped(_varRe, (m) {
          final v = vars[m[1]];
          return v == null ? m[0]! : _plain(v);
        });
    return VisualLayout(
      height: height,
      elements: elements.map((e) {
        final c = e.copy();
        if (c.type == VisualType.text || c.type == VisualType.qr) c.text = sub(c.text);
        return c;
      }).toList(),
    );
  }

  static String _plain(String v) => v.split('\n').map((l) {
        if (l.startsWith('#row:')) return l.substring(5).split('|').join('   ');
        return l;
      }).join('\n');
}
