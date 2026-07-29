import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: DashTabApp()));
}

class DashTabApp extends ConsumerWidget {
  const DashTabApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using AppRouter.router (with static redirect doesn't have access to
    // Riverpod; the redirect reads from SecureStorage directly in auth_provider)
    return MaterialApp.router(
      title: 'DashTab POS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
