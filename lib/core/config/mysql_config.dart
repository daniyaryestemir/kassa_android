import 'package:shared_preferences/shared_preferences.dart';

class MySqlSettings {
  const MySqlSettings({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
    required this.charset,
  });

  final String host;
  final int port;
  final String user;
  final String password;
  final String database;
  final String charset;

  bool get isComplete =>
      host.isNotEmpty &&
      user.isNotEmpty &&
      password.isNotEmpty &&
      database.isNotEmpty;
}

class MySqlConfig {
  const MySqlConfig._();

  static const _host = 'mysql_host';
  static const _port = 'mysql_port';
  static const _user = 'mysql_user';
  static const _password = 'mysql_password';
  static const _database = 'mysql_database';
  static const _charset = 'mysql_charset';

  static MySqlSettings _settings = const MySqlSettings(
    host: '',
    port: 3306,
    user: '',
    password: '',
    database: '',
    charset: 'utf8mb4',
  );

  static MySqlSettings get settings => _settings;
  static bool get isConfigured => _settings.isComplete;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = MySqlSettings(
      host: prefs.getString(_host)?.trim() ?? '',
      port: prefs.getInt(_port) ?? 3306,
      user: prefs.getString(_user)?.trim() ?? '',
      password: prefs.getString(_password) ?? '',
      database: prefs.getString(_database)?.trim() ?? '',
      charset: prefs.getString(_charset)?.trim().isNotEmpty == true
          ? prefs.getString(_charset)!.trim()
          : 'utf8mb4',
    );
  }

  static Future<void> save(MySqlSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_host, value.host.trim());
    await prefs.setInt(_port, value.port);
    await prefs.setString(_user, value.user.trim());
    await prefs.setString(_password, value.password);
    await prefs.setString(_database, value.database.trim());
    await prefs.setString(_charset,
        value.charset.trim().isEmpty ? 'utf8mb4' : value.charset.trim());
    _settings = MySqlSettings(
      host: value.host.trim(),
      port: value.port,
      user: value.user.trim(),
      password: value.password,
      database: value.database.trim(),
      charset: value.charset.trim().isEmpty ? 'utf8mb4' : value.charset.trim(),
    );
  }
}
