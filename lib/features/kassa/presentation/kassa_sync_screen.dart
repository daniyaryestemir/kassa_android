import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/kassa_repository.dart';
import '../data/local_check_models.dart';

class KassaSyncScreen extends StatefulWidget {
  const KassaSyncScreen({super.key});

  @override
  State<KassaSyncScreen> createState() => _KassaSyncScreenState();
}

class _KassaSyncScreenState extends State<KassaSyncScreen> {
  final _repository = KassaRepository();

  KassaSyncStatus? _status;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _repository.getSyncStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _infoMessage =
            status.lastSyncedAt == null || status.lastSyncedAt!.isEmpty
                ? null
                : 'Последняя синхронизация: ${status.lastSyncedAt}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runSync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final synced = await _repository.syncPendingChecks();
      await _loadStatus();

      if (!mounted) {
        return;
      }

      setState(() {
        _infoMessage = synced == 0
            ? 'Новых синхронизированных чеков нет'
            : 'Синхронизировано чеков: $synced';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Синхронизация кассы'),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _loadStatus,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const LoadingView();
          }

          if (_errorMessage != null && status == null) {
            return ErrorView(
              message: _errorMessage!,
              onRetry: _loadStatus,
            );
          }

          if (status == null) {
            return const ErrorView(message: 'Нет данных синхронизации');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_infoMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _infoMessage!,
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SyncMetric(
                        title: 'В очереди',
                        value: '${status.pendingCount}',
                        color: const Color(0xFF15803D),
                      ),
                      _SyncMetric(
                        title: 'Ошибки',
                        value: '${status.failedCount}',
                        color: const Color(0xFFBE123C),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSyncing ? null : _runSync,
                icon: const Icon(Icons.sync),
                label: Text(_isSyncing
                    ? 'Синхронизация...'
                    : 'Синхронизировать сейчас'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Очередь чеков',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (status.checks.isEmpty)
                const EmptyView('Очередь синхронизации пуста'),
              for (final check in status.checks) _SyncCheckCard(item: check),
            ],
          );
        },
      ),
    );
  }
}

class _SyncMetric extends StatelessWidget {
  const _SyncMetric({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncCheckCard extends StatelessWidget {
  const _SyncCheckCard({required this.item});

  final LocalCheckModel item;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (item.syncStatus) {
      'error' => 'Ошибка',
      'pending' => 'Ожидает',
      _ => item.syncStatus,
    };

    final statusColor = switch (item.syncStatus) {
      'error' => const Color(0xFFBE123C),
      'pending' => const Color(0xFF15803D),
      _ => const Color(0xFF374151),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Чек',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Дата: ${item.date}'),
            Text('Сумма: ${formatMoney(item.totalSum)}'),
            Text('Оплата: ${item.paymentMethod}'),
            Text('Товаров: ${item.itemsCount}'),
            Text('Повторов: ${item.retryCount}'),
            if (item.lastAttemptAt.isNotEmpty)
              Text('Последняя попытка: ${item.lastAttemptAt}'),
            if (item.lastError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  item.lastError,
                  style: const TextStyle(
                    color: Color(0xFFBE123C),
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
