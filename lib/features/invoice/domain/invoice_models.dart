class InvoiceItem {
  const InvoiceItem({required this.name, required this.qty, required this.price});

  final String name;
  final double qty;
  final double price;

  double get lineTotal => qty * price;

  /// إزالة الفاصل | من الاسم حتى لا يكسر أمر #row
  String get safeName => name.replaceAll('|', '/').replaceAll('\n', ' ');
}

String fmtNum(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
