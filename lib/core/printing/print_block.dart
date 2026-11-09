import 'dart:typed_data';
import 'escpos_commands.dart';

/// عناصر الإيصال المجردة. تُنتجها TemplateDsl وتُرسم بواسطة ReceiptRenderer.
sealed class PrintBlock {
  const PrintBlock();
}

/// سطر نص. align=null تعني تلقائي (العربية يمين، غيرها يسار)
class TextBlock extends PrintBlock {
  final String text;
  final PrintAlign? align;
  final bool bold;
  final int size; // 1..4
  const TextBlock(this.text, {this.align, this.bold = false, this.size = 1});
}

/// صف بعمودين: النص الأول عند بداية السطر والثاني عند نهايته
class RowBlock extends PrintBlock {
  final String first;
  final String second;
  final bool bold;
  final int size;
  const RowBlock(this.first, this.second, {this.bold = false, this.size = 1});
}

/// خط فاصل متقطع
class SeparatorBlock extends PrintBlock {
  const SeparatorBlock();
}

class QrBlock extends PrintBlock {
  final String data;
  final int sizeDots;
  final PrintAlign align;
  const QrBlock(this.data, {this.sizeDots = 200, this.align = PrintAlign.center});
}

class BarcodeBlock extends PrintBlock {
  final String data;
  final int heightDots;
  final PrintAlign align;
  const BarcodeBlock(this.data, {this.heightDots = 80, this.align = PrintAlign.center});
}

class ImageBlock extends PrintBlock {
  final Uint8List bytes;
  final PrintAlign align;
  const ImageBlock(this.bytes, {this.align = PrintAlign.center});
}

/// تغذية ورق فارغة بالنقاط
class FeedBlock extends PrintBlock {
  final int dots;
  const FeedBlock(this.dots);
}

/// قص الورق عند هذه النقطة
class CutBlock extends PrintBlock {
  const CutBlock();
}
