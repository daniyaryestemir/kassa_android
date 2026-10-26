import '../../../core/database/sync_state_store.dart';
import '../../../core/config/mysql_config.dart';
import '../../../core/mysql/mysql_sync_service.dart';
import '../../../core/sync/sync_progress.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../kassa/data/kassa_repository.dart';
import '../../nomenklatura/data/products_repository.dart';
import '../../postupleniya/data/receipts_repository.dart';

class SyncEntityStatus {
  const SyncEntityStatus({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lastSyncedAt,
    required this.pendingCount,
    required this.failedCount,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? lastSyncedAt;
  final int pendingCount;
  final int failedCount;
}

class SyncOverviewStatus {
  const SyncOverviewStatus({
    required this.entities,
  });

  final List<SyncEntityStatus> entities;
}

class SyncRunResult {
  const SyncRunResult({
    required this.productsSynced,
    required this.receiptsSynced,
    required this.checksSynced,
    required this.dashboardUpdated,
  });

  final int productsSynced;
  final int receiptsSynced;
  final int checksSynced;
  final bool dashboardUpdated;
}

class SyncOverviewRepository {
  static Future<SyncRunResult>? _activeSync;

  SyncOverviewRepository({
    ProductsRepository? productsRepository,
    ReceiptsRepository? receiptsRepository,
    KassaRepository? kassaRepository,
    DashboardRepository? dashboardRepository,
    SyncStateStore? syncStateStore,
  })  : _productsRepository = productsRepository ?? ProductsRepository(),
        _receiptsRepository = receiptsRepository ?? ReceiptsRepository(),
        _kassaRepository = kassaRepository ?? KassaRepository(),
        _dashboardRepository = dashboardRepository ?? DashboardRepository(),
        _syncStateStore = syncStateStore ?? SyncStateStore();

  final ProductsRepository _productsRepository;
  final ReceiptsRepository _receiptsRepository;
  final KassaRepository _kassaRepository;
  final DashboardRepository _dashboardRepository;
  final SyncStateStore _syncStateStore;

  Future<SyncOverviewStatus> load() async {
    final kassaStatus = await _kassaRepository.getSyncStatus();
    final productsSyncedAt = await _syncStateStore.getSyncedAt('products');
    final receiptsSyncedAt = await _syncStateStore.getSyncedAt('receipts');
    final checksSyncedAt = await _syncStateStore.getSyncedAt('kassa_checks');
    final dashboardSyncedAt = await _syncStateStore.getSyncedAt('dashboard');

    return SyncOverviewStatus(
      entities: [
        SyncEntityStatus(
          id: 'products',
          title: 'Товары',
          subtitle: 'Справочник номенклатуры',
          lastSyncedAt: productsSyncedAt,
          pendingCount: 0,
          failedCount: 0,
        ),
        SyncEntityStatus(
          id: 'receipts',
          title: 'Поступления',
          subtitle: 'Документы и строки поступлений',
          lastSyncedAt: receiptsSyncedAt,
          pendingCount: 0,
          failedCount: 0,
        ),
        SyncEntityStatus(
          id: 'checks',
          title: 'Чеки кассы',
          subtitle: 'Офлайн-очередь чеков',
          lastSyncedAt: checksSyncedAt,
          pendingCount: kassaStatus.pendingCount,
          failedCount: kassaStatus.failedCount,
        ),
        SyncEntityStatus(
          id: 'dashboard',
          title: 'Главная',
          subtitle: 'Кэш сводки и агрегатов',
          lastSyncedAt: dashboardSyncedAt,
          pendingCount: 0,
          failedCount: 0,
        ),
      ],
    );
  }

  Future<SyncRunResult> syncAll({
    void Function(SyncProgress progress)? onProgress,
    bool Function()? isCancellationRequested,
  }) {
    return _activeSync ??= _syncAll(
      onProgress: onProgress,
      isCancellationRequested: isCancellationRequested,
    ).whenComplete(() => _activeSync = null);
  }

  Future<SyncRunResult> _syncAll({
    void Function(SyncProgress progress)? onProgress,
    bool Function()? isCancellationRequested,
  }) async {
    void checkCancelled() {
      if (isCancellationRequested?.call() ?? false) {
        throw const SyncCancelledException();
      }
    }

    void report(int step, int totalSteps, String message) {
      onProgress?.call(
        SyncProgress(step: step, totalSteps: totalSteps, message: message),
      );
    }

    if (MySqlConfig.isConfigured) {
      final result = await MySqlSyncService().syncAll(
        onProgress: report,
        isCancellationRequested: isCancellationRequested,
      );
      return SyncRunResult(
        productsSynced: result.productsSynced,
        receiptsSynced: result.receiptsSynced,
        checksSynced: result.checksSynced,
        dashboardUpdated: true,
      );
    }
    const totalSteps = 4;
    report(0, totalSteps, 'Подготовка синхронизации');
    checkCancelled();
    final checksSynced = await _kassaRepository.syncPendingChecks();
    report(1, totalSteps, 'Чеки кассы синхронизированы');
    checkCancelled();
    final productsSynced = await _productsRepository.syncProducts();
    report(2, totalSteps, 'Товары синхронизированы');
    checkCancelled();
    final receiptsSynced = await _receiptsRepository.syncReceipts();
    report(3, totalSteps, 'Поступления синхронизированы');
    checkCancelled();
    await _dashboardRepository.syncDashboard();
    report(4, totalSteps, 'Главная обновлена');

    return SyncRunResult(
      productsSynced: productsSynced,
      receiptsSynced: receiptsSynced,
      checksSynced: checksSynced,
      dashboardUpdated: true,
    );
  }
}
