import 'package:dio/dio.dart';
import '../../models/user_model.dart';
import '../../../core/network/api_client.dart';

class AuthRemoteSource {
  final ApiClient _apiClient;

  AuthRemoteSource(this._apiClient);

  Future<UserModel> login(String username, String password, String tenantSlug) async {
    try {
      final response = await _apiClient.dio.post('/auth/login', data: {
        'username': username,
        'password': password,
        'tenantSlug': tenantSlug,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        // In a real app, save the tokens here or in the repository
        // final accessToken = data['accessToken'];
        // final refreshToken = data['refreshToken'];
        
        return UserModel.fromJson(data);
      } else {
        throw Exception('Failed to login');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? e.message);
    }
  }
}
