import 'package:shared_preferences/shared_preferences.dart';

/// Persists server IP + port across app restarts using shared_preferences.
class SettingsService {
  SettingsService._();

  static const _keyIp = 'server_ip';
  static const _keyPort = 'server_port';
  static const defaultIp = '13.53.154.169';
  static const defaultPort = 8000;

  static String _ip = defaultIp;
  static int _port = defaultPort;

  static String get serverIp => _ip;
  static int get serverPort => _port;
  static String get baseUrl => 'http://$_ip:$_port/api/v1';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ip = prefs.getString(_keyIp) ?? defaultIp;
    _port = prefs.getInt(_keyPort) ?? defaultPort;
  }

  static Future<void> save(String ip, int port) async {
    _ip = ip;
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyIp, ip),
      prefs.setInt(_keyPort, port),
    ]);
  }
}
