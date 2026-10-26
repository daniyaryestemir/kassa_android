import 'dart:async';

import '../../features/sync/data/sync_overview_repository.dart';

/// Runs one shared sync at a time while the application is open.
///
/// The UI always reads from SQLite; this service only refreshes that local
/// cache in the background. Android background execution after the app is
/// closed will be added separately with WorkManager.
class SyncScheduler {
  SyncScheduler({SyncOverviewRepository? repository})
      : _repository = repository ?? SyncOverviewRepository();

  static const interval = Duration(minutes: 15);

  final SyncOverviewRepository _repository;
  Timer? _timer;
  bool _isSyncing = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => syncNow());
  }

  Future<void> syncNow() async {
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;
    try {
      await _repository.syncAll();
    } catch (_) {
      // Network errors leave the local database untouched. The user can see
      // the queue and retry from the Synchronization screen.
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
