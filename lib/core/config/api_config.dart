import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _storageKey = 'api_base_url';
  static const String _defaultBaseUrl = 'http://10.0.2.2:5000';
  static const String _buildTimeBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String? _runtimeBaseUrl;

  static String get baseUrl => _runtimeBaseUrl ?? _buildTimeBaseUrl;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey)?.trim() ?? '';
    _runtimeBaseUrl = saved.isEmpty ? null : saved;
  }

  static Future<void> saveBaseUrl(String value) async {
    final normalized = value.trim();
    final prefs = await SharedPreferences.getInstance();

    if (normalized.isEmpty) {
      await prefs.remove(_storageKey);
      _runtimeBaseUrl = null;
      return;
    }

    await prefs.setString(_storageKey, normalized);
    _runtimeBaseUrl = normalized;
  }

  static bool isValidBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
