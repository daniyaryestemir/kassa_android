import 'package:flutter/material.dart';

import '../core/sync/sync_scheduler.dart';
import 'router.dart';
import 'theme.dart';

class KassaApp extends StatefulWidget {
  const KassaApp({super.key});

  @override
  State<KassaApp> createState() => _KassaAppState();
}

class _KassaAppState extends State<KassaApp> {
  final _syncScheduler = SyncScheduler();

  @override
  void initState() {
    super.initState();
    _syncScheduler.start();
  }

  @override
  void dispose() {
    _syncScheduler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kassa Android',
      theme: buildAppTheme(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
      debugShowCheckedModeBanner: false,
    );
  }
}
