import '../../../core/database/sync_state_store.dart';
import 'dashboard_api.dart';
import 'dashboard_local_data_source.dart';
import 'dashboard_models.dart';

class DashboardLoadResult {
  const DashboardLoadResult({
    required this.data,
    required this.usedOfflineData,
  });

  final DashboardDataModel data;
  final bool usedOfflineData;
}

class DashboardRepository {
  DashboardRepository({
    DashboardApi? api,
    DashboardLocalDataSource? localDataSource,
    SyncStateStore? syncStateStore,
  })  : _api = api ?? DashboardApi(),
        _localDataSource = localDataSource ?? DashboardLocalDataSource(),
        _syncStateStore = syncStateStore ?? SyncStateStore();

  final DashboardApi _api;
  final DashboardLocalDataSource _localDataSource;
  final SyncStateStore _syncStateStore;

  Future<DashboardLoadResult> loadLocal() async {
    final data = await _localDataSource.buildDashboard();
    return DashboardLoadResult(
      data: data,
      usedOfflineData: false,
    );
  }

  Future<void> syncDashboard() async {
    final response = await _api.loadDashboard();
    final dashboard =
        response['dashboard'] as Map<String, dynamic>? ?? <String, dynamic>{};
    await _localDataSource.saveRemoteDashboard(dashboard);
    await _syncStateStore.setSyncedAt(
      'dashboard',
      DateTime.now().toIso8601String(),
    );
  }
}
