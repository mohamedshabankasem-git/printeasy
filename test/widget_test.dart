import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printeasy/app.dart';
import 'package:printeasy/features/settings/presentation/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PrintEasy app builds its Arabic home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const PrintEasyApp(),
      ),
    );
    await tester.pump();

    expect(find.text('طباعة سريعة'), findsOneWidget);
    expect(find.text('طباعة ملفات'), findsOneWidget);
  });
}
