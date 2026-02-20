import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:face_reg_app/models/user_model.dart';
import 'package:face_reg_app/services/api_service.dart';
import 'package:face_reg_app/services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, needsReauth }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _error;
  bool _loading = false;
  String? _savedName;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get savedName => _savedName;

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  Future<void> checkAuth() async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      try {
        _user = await ApiService.instance.getMe();
        _status = AuthStatus.authenticated;
        notifyListeners();
        return;
      } catch (_) {
        // Token invalid / expired & refresh failed
      }
    }

    // Check for saved name → offer re-auth via face
    final saved = await TokenStorage.getUsername();
    if (saved != null && saved.isNotEmpty) {
      _savedName = saved;
      _status = AuthStatus.needsReauth;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Register with face ────────────────────────────────────────────────────

  Future<bool> registerWithFace({
    required String name,
    required String phoneNumber,
    required File image,
  }) async {
    _setLoading(true);
    try {
      final data = await ApiService.instance.registerFace(
        name: name,
        phoneNumber: phoneNumber,
        imageFile: image,
      );
      await TokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      await TokenStorage.saveUsername(name);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      _clearError();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _setError(_extractMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Face login ────────────────────────────────────────────────────────────

  Future<bool> loginFace({
    required String name,
    required List<File> frames,
  }) async {
    _setLoading(true);
    try {
      final data = await ApiService.instance.loginFace(
        name: name,
        frames: frames,
      );
      await TokenStorage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      await TokenStorage.saveUsername(name);
      _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      _clearError();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _setError(_extractMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await TokenStorage.clearAll();
    _user = null;
    _savedName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Clear re-auth (switch account) ────────────────────────────────────────

  Future<void> clearSavedUser() async {
    await TokenStorage.clearAll();
    _savedName = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  void _clearError() => _error = null;

  String _extractMessage(Exception e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      String? detail;
      if (data is Map<String, dynamic>) detail = data['detail'] as String?;

      if (code == 401) {
        if (detail == 'Face does not match') return 'Face not recognised';
        if (detail == 'Invalid credentials') return 'User not found — register first';
        if (detail != null && detail.startsWith('Liveness failed')) {
          return 'Liveness check failed — hold still and try again';
        }
        return detail ?? 'Authentication failed';
      }
      if (code == 409) return detail ?? 'Name already taken';
      if (code == 422) {
        return detail?.replaceFirst('Liveness failed: ', '') ?? 'Invalid data';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Server not responding — check your connection';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Cannot reach server — check IP in Settings';
      }
      return detail ?? 'Request failed';
    }
    return 'Something went wrong';
  }
}
