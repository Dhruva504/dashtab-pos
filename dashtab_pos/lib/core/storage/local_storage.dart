import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tenantIdKey = 'tenant_id';
  static const _tenantNameKey = 'tenant_name';
  static const _userIdKey = 'user_id';
  static const _fullNameKey = 'full_name';
  static const _tenantSlugKey = 'tenant_slug';

  static Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String fullName,
    required String tenantId,
    required String tenantName,
    required String tenantSlug,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _fullNameKey, value: fullName),
      _storage.write(key: _tenantIdKey, value: tenantId),
      _storage.write(key: _tenantNameKey, value: tenantName),
      _storage.write(key: _tenantSlugKey, value: tenantSlug),
    ]);
  }

  static Future<String?> getAccessToken() => _storage.read(key: _tokenKey);
  static Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  static Future<String?> getTenantId() => _storage.read(key: _tenantIdKey);
  static Future<String?> getTenantName() => _storage.read(key: _tenantNameKey);
  static Future<String?> getUserId() => _storage.read(key: _userIdKey);
  static Future<String?> getFullName() => _storage.read(key: _fullNameKey);
  static Future<String?> getTenantSlug() => _storage.read(key: _tenantSlugKey);

  static Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
