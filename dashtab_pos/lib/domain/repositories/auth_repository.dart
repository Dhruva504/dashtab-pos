import '../entities/user.dart';

abstract class AuthRepository {
  Future<User> login(String username, String password, String tenantSlug);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<bool> isAuthenticated();
}
