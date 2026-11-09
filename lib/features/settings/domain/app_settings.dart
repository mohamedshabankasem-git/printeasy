import 'package:flutter/material.dart';
import '../../../core/printing/print_service.dart';

class AppSettings {
  const AppSettings({
    this.paperWidthMm = 58,
    this.density = 1,
    this.autoCut = true,
    this.tailFeedMm = 20,
    this.themeMode = ThemeMode.system,
    this.shopName = 'متجري',
    this.shareAutoPrint = false,
  });

  final int paperWidthMm;
  final int density;
  final bool autoCut;
  final int tailFeedMm;
  final ThemeMode themeMode;
  final String shopName;
  final bool shareAutoPrint; // طباعة مباشرة عند المشاركة من تطبيق آخر

  AppSettings copyWith({
    int? paperWidthMm,
    int? density,
    bool? autoCut,
    int? tailFeedMm,
    ThemeMode? themeMode,
    String? shopName,
    bool? shareAutoPrint,
  }) =>
      AppSettings(
        paperWidthMm: paperWidthMm ?? this.paperWidthMm,
        density: density ?? this.density,
        autoCut: autoCut ?? this.autoCut,
        tailFeedMm: tailFeedMm ?? this.tailFeedMm,
        themeMode: themeMode ?? this.themeMode,
        shopName: shopName ?? this.shopName,
        shareAutoPrint: shareAutoPrint ?? this.shareAutoPrint,
      );

  PrintSettings toPrintSettings() => PrintSettings(
        paperWidthMm: paperWidthMm,
        density: density,
        autoCut: autoCut,
        tailFeedMm: tailFeedMm,
      );
}
