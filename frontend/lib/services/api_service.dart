import 'dart:io';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:face_reg_app/models/user_model.dart';
import 'package:face_reg_app/services/settings_service.dart';
import 'package:face_reg_app/services/token_storage.dart';

class ApiService {
  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: SettingsService.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      PrettyDioLogger(requestBody: false, responseBody: false),
      _AuthInterceptor(_dio),
    ]);
  }

  static final ApiService instance = ApiService._();
  late final Dio _dio;

  /// Call this after changing server settings so Dio uses the new base URL.
  void updateBaseUrl() => _dio.options.baseUrl = SettingsService.baseUrl;

  // ── Register with face ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerFace({
    required String name,
    required String phoneNumber,
    required File imageFile,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      'phone_number': phoneNumber,
      'face_image': await MultipartFile.fromFile(
        imageFile.path,
        filename: 'enroll.jpg',
      ),
    });
    final response = await _dio.post('/auth/register-face', data: form);
    return response.data as Map<String, dynamic>;
  }

  // ── Face login ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> loginFace({
    required String name,
    required List<File> frames,
  }) async {
    final form = FormData.fromMap({'name': name});
    for (int i = 0; i < frames.length; i++) {
      form.files.add(MapEntry(
        'face_frames',
        await MultipartFile.fromFile(frames[i].path, filename: 'frame_$i.jpg'),
      ));
    }
    final response = await _dio.post('/auth/login/face', data: form);
    return response.data as Map<String, dynamic>;
  }

  // ── Token refresh ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> refreshTokens(String refreshToken) async {
    final response = await _dio.post(
      '/auth/token/refresh',
      data: {'refresh_token': refreshToken},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Profile ──────────────────────────────────────────────────────────────

  Future<UserModel> getMe() async {
    final response = await _dio.get('/auth/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Admin: clear database ────────────────────────────────────────────────

  Future<void> clearDatabase() async {
    await _dio.delete('/auth/admin/clear');
  }
}

// ── JWT Auth Interceptor ──────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);
  final Dio _dio;
  bool _refreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_refreshing) {
      _refreshing = true;
      try {
        final refresh = await TokenStorage.getRefreshToken();
        if (refresh == null) return handler.next(err);

        final res = await _dio.post(
          '/auth/token/refresh',
          data: {'refresh_token': refresh},
        );
        final newAccess = res.data['access_token'] as String;
        final newRefresh = res.data['refresh_token'] as String;
        await TokenStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await _dio.fetch(err.requestOptions);
        return handler.resolve(retried);
      } catch (_) {
        await TokenStorage.clearAll();
      } finally {
        _refreshing = false;
      }
    }
    handler.next(err);
  }
}
