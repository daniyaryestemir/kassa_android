import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/api_config.dart';
import 'core/config/mysql_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.init();
  await MySqlConfig.init();
  runApp(const KassaApp());
}
