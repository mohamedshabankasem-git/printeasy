import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/batch/presentation/batch_screen.dart';
import 'features/connection/presentation/connect_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/invoice/presentation/invoice_screen.dart';
import 'features/settings/presentation/settings_providers.dart';
import 'features/share/presentation/share_listener.dart';
import 'features/share/presentation/share_screen.dart';
import 'features/visual_editor/presentation/visual_editor_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/templates/domain/template_model.dart';
import 'features/templates/presentation/template_editor_screen.dart';
import 'features/templates/presentation/templates_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/connect', builder: (_, __) => const ConnectScreen()),
      GoRoute(
        path: '/templates',
        builder: (_, __) => const TemplatesScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => TemplateEditorScreen(template: state.extra as TemplateModel?),
          ),
        ],
      ),
      GoRoute(path: '/invoice', builder: (_, __) => const InvoiceScreen()),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/batch', builder: (_, __) => const BatchScreen()),
      GoRoute(
        path: '/visual-editor',
        builder: (_, state) => VisualEditorScreen(template: state.extra as TemplateModel?),
      ),
      GoRoute(
        path: '/share',
        builder: (_, state) => ShareScreen(payload: state.extra as SharedPayload),
      ),
    ],
  );
});

class PrintEasyApp extends ConsumerWidget {
  const PrintEasyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'طباعة سريعة',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ShareIntentListener(
        router: ref.read(routerProvider),
        child: child ?? const SizedBox.shrink(),
      ),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
