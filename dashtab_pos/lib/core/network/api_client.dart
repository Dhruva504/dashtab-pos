import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/local_storage.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Inject JWT Bearer token
        final token = await SecureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Inject X-Tenant-Id header for backend multi-tenancy middleware
        final tenantId = await SecureStorage.getTenantId();
        if (tenantId != null && tenantId.isNotEmpty) {
          options.headers['X-Tenant-Id'] = tenantId;
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // On 401 (token expired/invalid), clear auth data
        if (e.response?.statusCode == 401) {
          await SecureStorage.clearAll();
          // The router redirect will handle navigation to /login
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
