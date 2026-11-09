enum PrinterLink { classic, ble, usb }

/// وصف طابعة مكتشفة. id: عنوان MAC للبلوتوث أو اسم جهاز USB
class PrinterDevice {
  const PrinterDevice({required this.id, required this.name, required this.link});

  final String id;
  final String name;
  final PrinterLink link;

  String get key => '${link.name}:$id';

  String get linkLabel => switch (link) {
        PrinterLink.classic => 'Bluetooth Classic',
        PrinterLink.ble => 'Bluetooth LE',
        PrinterLink.usb => 'USB',
      };
}
