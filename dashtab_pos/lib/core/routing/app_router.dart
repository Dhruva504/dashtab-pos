import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../shell/home_shell.dart';
import '../shell/shell_views.dart';

/// Router provider that creates a [GoRouter] with auth guard.
/// Reads [authProvider] to determine if the user is authenticated.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  // Wire the shell's content builder to the views registry.
  shellChildBuilder = (context, key) => ShellViews.build(context, key);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }
      // If already authenticated and going to login, redirect to shell
      if (isAuthenticated && isGoingToLogin) {
        return '/';
      }
      return null; // No redirect
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
  );
});
