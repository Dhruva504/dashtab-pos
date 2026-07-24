import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_remote_source.dart';
// import '../../../core/storage/local_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteSource _remoteSource;
  
  AuthRepositoryImpl(this._remoteSource);

  @override
  Future<User> login(String username, String password, String tenantSlug) async {
    final userModel = await _remoteSource.login(username, password, tenantSlug);
    // Save tokens and current user to secure storage
    return userModel;
  }

  @override
  Future<void> logout() async {
    // Clear tokens from secure storage
  }

  @override
  Future<User?> getCurrentUser() async {
    // Read user from storage
    return null;
  }

  @override
  Future<bool> isAuthenticated() async {
    // Check if valid token exists
    return false;
  }
}
