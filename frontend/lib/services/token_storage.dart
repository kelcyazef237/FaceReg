import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:face_reg_app/core/constants.dart';

class TokenStorage {
  TokenStorage._();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.accessTokenKey, value: accessToken),
      _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  static Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: AppConstants.accessTokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
      _storage.delete(key: AppConstants.usernameKey),
    ]);
  }

  static Future<void> saveUsername(String username) =>
      _storage.write(key: AppConstants.usernameKey, value: username);

  static Future<String?> getUsername() =>
      _storage.read(key: AppConstants.usernameKey);
}
