import '../../entities/user.dart';
import '../../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<User> call(String username, String password, String tenantSlug) async {
    // Business logic validations can happen here
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required');
    }
    
    return await _repository.login(username, password, tenantSlug);
  }
}
