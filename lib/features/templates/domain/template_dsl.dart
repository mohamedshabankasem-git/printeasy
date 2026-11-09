import '../../../core/printing/escpos_commands.dart';
import '../../../core/printing/print_block.dart';

/// لغة القوالب النصية البسيطة.
///
/// كل سطر إما أمر يبدأ بـ # أو نص عادي. الأوامر:
///   #align:center|left|right   محاذاة (تبقى حتى تغييرها)
///   #bold  /  #bold:off        خط عريض
///   #size:1..4                 حجم الخط
///   #sep                       خط فاصل
///   #row:نص|قيمة               صف بعمودين (اسم الصنف | السعر)
///   #qr:بيانات                 رمز QR
///   #barcode:بيانات            باركود Code128
///   #feed:n                    تغذية n سطر
///   #cut                       قص الورق
/// المتغيرات: {customer_name} تُستبدل من خريطة المتغيرات.
/// لكتابة سطر يبدأ بعلامة # حرفياً اسبقه بـ \
class TemplateDsl {
  static final RegExp _varRe = RegExp(r'\{([A-Za-z0-9_\u0600-\u06FF]+)\}');

  /// استبدال المتغيرات (غير الموجودة تبقى كما هي)
  static String fill(String source, Map<String, String> vars) =>
      source.replaceAllMapped(_varRe, (m) => vars[m[1]] ?? m[0]!);

  /// أسماء المتغيرات المستخدمة في القالب بدون تكرار
  static List<String> variablesOf(String source) =>
      _varRe.allMatches(source).map((m) => m[1]!).toSet().toList();

  static List<PrintBlock> parse(String source, {Map<String, String> vars = const {}}) {
    final filled = fill(source, vars);
    final blocks = <PrintBlock>[];
    PrintAlign? align;
    var bold = false;
    var size = 1;

    for (final raw in filled.split('\n')) {
      final line = raw.replaceAll('\r', '');
      final trimmed = line.trim();

      if (trimmed.startsWith(r'\#')) {
        blocks.add(TextBlock(trimmed.substring(1), align: align, bold: bold, size: size));
        continue;
      }
      if (!trimmed.startsWith('#')) {
        blocks.add(TextBlock(line, align: align, bold: bold, size: size));
        continue;
      }

      final body = trimmed.substring(1);
      final idx = body.indexOf(':');
      final cmd = (idx < 0 ? body : body.substring(0, idx)).trim().toLowerCase();
      final arg = idx < 0 ? '' : body.substring(idx + 1).trim();

      switch (cmd) {
        case 'align':
          align = switch (arg.toLowerCase()) {
            'center' => PrintAlign.center,
            'right' => PrintAlign.right,
            'left' => PrintAlign.left,
            _ => null,
          };
        case 'bold':
          bold = arg.toLowerCase() != 'off';
        case 'size':
          size = (int.tryParse(arg) ?? 1).clamp(1, 4);
        case 'sep':
          blocks.add(const SeparatorBlock());
        case 'row':
          final parts = arg.split('|');
          final first = parts.first.trim();
          final second = parts.length > 1 ? parts.sublist(1).join('|').trim() : '';
          blocks.add(RowBlock(first, second, bold: bold, size: size));
        case 'qr':
          if (arg.isNotEmpty) blocks.add(QrBlock(arg, align: align ?? PrintAlign.center));
        case 'barcode':
          if (arg.isNotEmpty) blocks.add(BarcodeBlock(arg, align: align ?? PrintAlign.center));
        case 'feed':
          final n = (int.tryParse(arg) ?? 1).clamp(0, 20);
          blocks.add(FeedBlock(n * 26));
        case 'cut':
          blocks.add(const CutBlock());
        default:
          break; // أمر غير معروف يُتجاهل
      }
    }
    return blocks;
  }
}
