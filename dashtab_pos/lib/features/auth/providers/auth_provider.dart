import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/storage/local_storage.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? fullName;
  final String? tenantSlug;
  final String? tenantId;
  final String? tenantName;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.fullName,
    this.tenantSlug,
    this.tenantId,
    this.tenantName,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? fullName,
    String? tenantSlug,
    String? tenantId,
    String? tenantName,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Check for persisted token on startup
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final hasToken = await SecureStorage.hasValidToken();
    if (hasToken) {
      final userId = await SecureStorage.getUserId();
      final fullName = await SecureStorage.getFullName();
      final tenantId = await SecureStorage.getTenantId();
      final tenantName = await SecureStorage.getTenantName();
      final tenantSlug = await SecureStorage.getTenantSlug();
      state = AuthState(
        isAuthenticated: true,
        userId: userId,
        fullName: fullName,
        tenantId: tenantId,
        tenantName: tenantName,
        tenantSlug: tenantSlug,
      );
    }
  }

  Future<String?> login(
      String username, String password, String tenantSlug) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await ref.read(apiClientProvider).dio.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          'tenantSlug': tenantSlug,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userId = data['userId'] as String;
      final fullName = data['fullName'] as String;
      final tenantId = data['tenantId'] as String;
      final tenantNameResp = data['tenantName'] as String;

      await SecureStorage.saveAuthData(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        fullName: fullName,
        tenantId: tenantId,
        tenantName: tenantNameResp,
        tenantSlug: tenantSlug,
      );

      state = AuthState(
        isAuthenticated: true,
        userId: userId,
        fullName: fullName,
        tenantId: tenantId,
        tenantName: tenantNameResp,
        tenantSlug: tenantSlug,
      );

      return null; // null means success
    } on DioException catch (e) {
      String errorMsg = 'Login failed. Please try again.';
      if (e.response?.data != null) {
        final errorData = e.response!.data;
        if (errorData is Map && errorData.containsKey('error')) {
          errorMsg = errorData['error'] as String;
        } else if (errorData is Map && errorData.containsKey('Error')) {
          errorMsg = errorData['Error'] as String;
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
      return errorMsg;
    } catch (e) {
      final msg = 'Unexpected error: ${e.toString()}';
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return msg;
    }
  }

  Future<void> logout() async {
    await SecureStorage.clearAll();
    state = const AuthState();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
