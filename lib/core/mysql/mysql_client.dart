import 'package:mysql1/mysql1.dart';

import '../config/mysql_config.dart';

class MySqlClient {
  Future<T> withConnection<T>(
      Future<T> Function(MySqlConnection) action) async {
    final settings = MySqlConfig.settings;
    if (!settings.isComplete) {
      throw StateError('Заполните параметры подключения к MySQL в настройках.');
    }

    final connection = await MySqlConnection.connect(
      ConnectionSettings(
        host: settings.host,
        port: settings.port,
        user: settings.user,
        password: settings.password,
        db: settings.database,
        timeout: const Duration(seconds: 15),
      ),
    );
    try {
      await connection.query('SET NAMES utf8mb4');
      return await action(connection);
    } finally {
      await connection.close();
    }
  }

  Future<void> testConnection() {
    return withConnection((connection) async {
      await connection.query('SELECT 1');
    });
  }
}
