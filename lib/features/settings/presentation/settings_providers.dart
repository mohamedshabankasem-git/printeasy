import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/app_settings.dart';

/// يُستبدل في main.dart بنسخة SharedPreferences الحقيقية
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  late SharedPreferences _p;

  @override
  AppSettings build() {
    _p = ref.read(sharedPrefsProvider);
    return AppSettings(
      paperWidthMm: _p.getInt('paper_width') ?? 58,
      density: _p.getInt('density') ?? 1,
      autoCut: _p.getBool('auto_cut') ?? true,
      tailFeedMm: _p.getInt('tail_feed') ?? 20,
      themeMode: ThemeMode.values[_p.getInt('theme_mode') ?? 0],
      shopName: _p.getString('shop_name') ?? 'متجري',
      shareAutoPrint: _p.getBool('share_auto_print') ?? false,
    );
  }

  Future<void> setPaperWidth(int mm) async {
    state = state.copyWith(paperWidthMm: mm);
    await _p.setInt('paper_width', mm);
  }

  Future<void> setDensity(int v) async {
    state = state.copyWith(density: v);
    await _p.setInt('density', v);
  }

  Future<void> setAutoCut(bool v) async {
    state = state.copyWith(autoCut: v);
    await _p.setBool('auto_cut', v);
  }

  Future<void> setTailFeed(int mm) async {
    state = state.copyWith(tailFeedMm: mm);
    await _p.setInt('tail_feed', mm);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _p.setInt('theme_mode', m.index);
  }

  Future<void> setShareAutoPrint(bool v) async {
    state = state.copyWith(shareAutoPrint: v);
    await _p.setBool('share_auto_print', v);
  }

  Future<void> setShopName(String n) async {
    state = state.copyWith(shopName: n);
    await _p.setString('shop_name', n);
  }
}
