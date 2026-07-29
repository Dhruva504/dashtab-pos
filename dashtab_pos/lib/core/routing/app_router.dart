import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/kitchen/screens/kitchen_display_screen.dart';
import '../../features/payment/screens/payment_screen.dart';
import '../../features/floor_plan/screens/floor_plan_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/user_management_screen.dart';
import '../../features/reports/screens/reports_screen.dart';

class AppRouter {
  static GoRouter createRouter(ProviderContainer container) {
    return GoRouter(
      initialLocation: '/login',
      // Auth guard: redirect to /login if not authenticated
      redirect: (context, state) {
        final authState = container.read(authProvider);
        final isAuthenticated = authState.isAuthenticated;
        final isGoingToLogin = state.matchedLocation == '/login';

        if (!isAuthenticated && !isGoingToLogin) {
          return '/login';
        }
        // If already authenticated and going to login, redirect to floor plan
        if (isAuthenticated && isGoingToLogin) {
          return '/floor';
        }
        return null; // No redirect
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/floor',
          builder: (context, state) => const FloorPlanScreen(),
        ),
        GoRoute(
          path: '/pos',
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: '/kitchen',
          builder: (context, state) => const KitchenDisplayScreen(),
        ),
        GoRoute(
          path: '/payment',
          builder: (context, state) => const PaymentScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
      ],
    );
  }

  // Legacy static router for backward compat — replaced by createRouter
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/floor',
          builder: (context, state) => const FloorPlanScreen()),
      GoRoute(
          path: '/pos', builder: (context, state) => const PosScreen()),
      GoRoute(
          path: '/kitchen',
          builder: (context, state) => const KitchenDisplayScreen()),
      GoRoute(
          path: '/payment',
          builder: (context, state) => const PaymentScreen()),
      GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen()),
      GoRoute(
          path: '/users',
          builder: (context, state) => const UserManagementScreen()),
      GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen()),
    ],
  );
}
