import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/database/sync_state_store.dart';
import '../../nomenklatura/data/product_model.dart';
import 'kassa_api.dart';
import 'kassa_local_data_source.dart';
import 'local_check_models.dart';

class KassaLoadResult {
  const KassaLoadResult({
    required this.products,
    required this.recentChecks,
    required this.pendingChecksCount,
    required this.failedChecksCount,
    required this.usedOfflineData,
  });

  final List<ProductModel> products;
  final List<LocalCheckModel> recentChecks;
  final int pendingChecksCount;
  final int failedChecksCount;
  final bool usedOfflineData;
}

class CheckoutResult {
  const CheckoutResult({
    required this.checkUuid,
    required this.queuedOffline,
  });

  final String checkUuid;
  final bool queuedOffline;
}

class KassaSyncStatus {
  const KassaSyncStatus({
    required this.checks,
    required this.pendingCount,
    required this.failedCount,
    required this.lastSyncedAt,
  });

  final List<LocalCheckModel> checks;
  final int pendingCount;
  final int failedCount;
  final String? lastSyncedAt;
}

class KassaRepository {
  static Future<int>? _activeChecksSync;

  KassaRepository({
    KassaApi? api,
    KassaLocalDataSource? localDataSource,
    SyncStateStore? syncStateStore,
  })  : _api = api ?? KassaApi(),
        _localDataSource = localDataSource ?? KassaLocalDataSource(),
        _syncStateStore = syncStateStore ?? SyncStateStore();

  final KassaApi _api;
  final KassaLocalDataSource _localDataSource;
  final SyncStateStore _syncStateStore;
  final _uuid = const Uuid();

  Future<KassaLoadResult> load({String query = ''}) async {
    final products = await _localDataSource.getProducts(query: query);
    final recentChecks = await _localDataSource.getRecentChecks();
    final pendingChecks = await _localDataSource.getPendingChecks();
    final failedChecksCount =
        pendingChecks.where((check) => check.hasSyncError).length;

    return KassaLoadResult(
      products: products,
      recentChecks: recentChecks,
      pendingChecksCount: pendingChecks.length,
      failedChecksCount: failedChecksCount,
      usedOfflineData: false,
    );
  }

  Future<CheckoutResult> checkout({
    required Map<String, dynamic> payload,
    required String saleMode,
    required String paymentMethod,
  }) async {
    final now = DateTime.now().toIso8601String();
    final requestedUuid = _uuid.v4();
    final payloadWithUuid = Map<String, dynamic>.from(payload)
      ..putIfAbsent('check_uuid', () => requestedUuid);
    final items = (payloadWithUuid['items'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final totalSum = ((payloadWithUuid['paid_amount'] ?? 0) as num).toDouble();

    await _localDataSource.decreaseStocks(items);
    await _localDataSource.saveCheck(
      LocalCheckModel(
        uuid: requestedUuid,
        date: now,
        payloadJson: jsonEncode(payloadWithUuid),
        itemsJson: jsonEncode(items),
        totalSum: totalSum,
        paymentMethod: paymentMethod,
        saleMode: saleMode,
        syncStatus: 'pending',
        lastModified: now,
        lastAttemptAt: '',
        lastError: '',
        retryCount: 0,
        isDeleted: false,
      ),
    );

    return CheckoutResult(
      checkUuid: requestedUuid,
      queuedOffline: true,
    );
  }

  Future<int> syncPendingChecks() {
    return _activeChecksSync ??=
        _syncPendingChecks().whenComplete(() => _activeChecksSync = null);
  }

  Future<int> _syncPendingChecks() async {
    final pendingChecks = await _localDataSource.getPendingChecks();
    var synced = 0;

    for (final pendingCheck in pendingChecks) {
      final decoded = jsonDecode(pendingCheck.payloadJson);
      if (decoded is! Map<String, dynamic>) {
        await _localDataSource.markCheckSyncError(
          pendingCheck.uuid,
          attemptedAt: DateTime.now().toIso8601String(),
          errorMessage: 'Некорректный локальный payload чека',
        );
        continue;
      }

      final attemptedAt = DateTime.now().toIso8601String();
      await _localDataSource.markCheckSyncAttempt(
        pendingCheck.uuid,
        attemptedAt,
      );

      try {
        await _api.checkout(decoded);
        await _localDataSource.markCheckSynced(
          pendingCheck.uuid,
          attemptedAt,
        );
        synced += 1;
      } catch (error) {
        await _localDataSource.markCheckSyncError(
          pendingCheck.uuid,
          attemptedAt: attemptedAt,
          errorMessage: error.toString(),
        );
      }
    }

    if (synced > 0) {
      await _syncStateStore.setSyncedAt(
        'kassa_checks',
        DateTime.now().toIso8601String(),
      );
    }

    return synced;
  }

  Future<KassaSyncStatus> getSyncStatus() async {
    final checks = await _localDataSource.getPendingChecks();
    final failedCount = checks.where((check) => check.hasSyncError).length;
    final lastSyncedAt = await _syncStateStore.getSyncedAt('kassa_checks');

    return KassaSyncStatus(
      checks: checks,
      pendingCount: checks.length,
      failedCount: failedCount,
      lastSyncedAt: lastSyncedAt,
    );
  }
}
