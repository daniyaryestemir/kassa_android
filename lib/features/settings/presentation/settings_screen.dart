import 'package:flutter/material.dart';

import '../../../core/config/mysql_config.dart';
import '../../../core/mysql/mysql_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _database;
  late final TextEditingController _charset;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = MySqlConfig.settings;
    _host = TextEditingController(text: settings.host);
    _port = TextEditingController(text: '${settings.port}');
    _user = TextEditingController(text: settings.user);
    _password = TextEditingController(text: settings.password);
    _database = TextEditingController(text: settings.database);
    _charset = TextEditingController(text: settings.charset);
  }

  @override
  void dispose() {
    for (final controller in [
      _host,
      _port,
      _user,
      _password,
      _database,
      _charset
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool test = false}) async {
    final port = int.tryParse(_port.text.trim());
    if (_host.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _database.text.trim().isEmpty ||
        port == null ||
        port < 1 ||
        port > 65535) {
      _message('Заполните все параметры MySQL и корректный порт.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await MySqlConfig.save(MySqlSettings(
        host: _host.text,
        port: port,
        user: _user.text,
        password: _password.text,
        database: _database.text,
        charset: _charset.text,
      ));
      if (test) {
        await MySqlClient().testConnection();
      }
      if (mounted) {
        _message(test
            ? 'Подключение к MySQL успешно.'
            : 'Настройки MySQL сохранены.');
      }
    } catch (error) {
      if (mounted) {
        _message('Не удалось подключиться: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки MySQL')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Прямое подключение к общей базе кассы.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          TextField(
              controller: _host,
              decoration: const InputDecoration(
                  labelText: 'Host', hintText: '192.168.1.10')),
          const SizedBox(height: 12),
          TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Port', hintText: '3306')),
          const SizedBox(height: 12),
          TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'User')),
          const SizedBox(height: 12),
          TextField(
              controller: _password,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          TextField(
              controller: _database,
              decoration: const InputDecoration(labelText: 'Database')),
          const SizedBox(height: 12),
          TextField(
              controller: _charset,
              decoration: const InputDecoration(
                  labelText: 'Charset', hintText: 'utf8mb4')),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Сохранение...' : 'Сохранить')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _save(test: true),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Сохранить и проверить подключение')),
        ],
      ),
    );
  }
}
