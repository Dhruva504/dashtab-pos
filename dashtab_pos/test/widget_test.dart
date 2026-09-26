import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dashtab_pos/main.dart';
import 'package:dashtab_pos/data/services/supabase_auth_service.dart';
import 'package:dashtab_pos/data/services/supabase_services.dart';

/// Stub auth service so the app can render without a Supabase backend.
class _FakeAuthService implements SupabaseAuthService {
  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Future<Session?> restoreSession() async => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Future<Session?> refreshSession() async => null;

  @override
  Future<User?> updateUserMetadata(Map<String, dynamic> data) async => null;
}

void main() {
  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    // Desktop POS — test at a real desktop viewport.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supabaseAuthServiceProvider
              .overrideWithValue(_FakeAuthService()),
        ],
        child: const DashTabApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify that the design-matched login screen renders.
    expect(find.text('Welcome back 👋'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });
}
