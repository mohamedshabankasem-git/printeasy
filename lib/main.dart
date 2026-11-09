import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/database/database_service.dart';
import 'features/settings/presentation/settings_providers.dart';
import 'features/templates/data/template_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await DatabaseService.instance.database;
  await TemplateRepository().ensureDefaults();

  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const PrintEasyApp(),
  ));
}
