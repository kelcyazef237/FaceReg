class AppConstants {
  AppConstants._();

  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String usernameKey = 'username';

  // Liveness capture (login/re-auth)
  static const int livenessFrameCount = 3;
  static const Duration captureInterval = Duration(milliseconds: 400);

  // Face ID auto-scan delay after camera ready
  static const Duration faceIdStartDelay = Duration(milliseconds: 800);
}
