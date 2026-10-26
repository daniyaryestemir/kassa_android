import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/sync/sync_progress.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../../kassa/presentation/kassa_sync_screen.dart';
import '../data/sync_overview_repository.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _repository = SyncOverviewRepository();
  final _logController = ScrollController();
  final List<_SyncLogEntry> _logEntries = [];

  SyncOverviewStatus? _status;
  SyncProgress? _progress;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _cancelRequested = false;
  String? _errorMessage;
  String _statusMessage = 'Готово к синхронизации';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _repository.load();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addLog(String message, _SyncLogType type) {
    if (!mounted) return;
    setState(() {
      _logEntries.add(_SyncLogEntry(message: message, type: type));
      if (_logEntries.length > 200) _logEntries.removeAt(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logController.hasClients) {
        _logController.animateTo(
          _logController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _syncAll() async {
    setState(() {
      _isSyncing = true;
      _cancelRequested = false;
      _errorMessage = null;
      _progress = null;
      _statusMessage = 'Инициализация...';
      _logEntries.clear();
    });
    _addLog('Синхронизация началась', _SyncLogType.success);

    try {
      final result = await _repository.syncAll(
        isCancellationRequested: () => _cancelRequested,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _statusMessage = progress.message;
          });
          _addLog(progress.message, _SyncLogType.info);
        },
      );
      await _load();
      if (!mounted) return;
      final summary = 'Готово: товары ${result.productsSynced}, '
          'поступления ${result.receiptsSynced}, чеки ${result.checksSynced}';
      setState(() => _statusMessage = summary);
      _addLog(summary, _SyncLogType.success);
    } on SyncCancelledException {
      if (!mounted) return;
      setState(() => _statusMessage = 'Синхронизация отменена');
      _addLog('Синхронизация отменена', _SyncLogType.warning);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _statusMessage = 'Синхронизация завершилась с ошибкой';
      });
      _addLog('Ошибка: $error', _SyncLogType.error);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _cancelSync() {
    if (_cancelRequested) return;
    setState(() {
      _cancelRequested = true;
      _statusMessage = 'Запрошена остановка...';
    });
    _addLog('Запрошена остановка после текущего этапа', _SyncLogType.warning);
  }

  Future<void> _copyLog() async {
    if (_logEntries.isEmpty) return;
    final log = _logEntries
        .map((entry) => '${entry.time} ${entry.prefix} ${entry.message}')
        .join('\n');
    await Clipboard.setData(ClipboardData(text: log));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Журнал скопирован в буфер обмена')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final progress = _progress;
    final progressValue = progress == null || progress.totalSteps == 0
        ? 0.0
        : progress.step / progress.totalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Синхронизация с сервером'),
        actions: [
          IconButton(
            onPressed: _isLoading || _isSyncing ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить статус',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _errorMessage != null && status == null
              ? ErrorView(message: _errorMessage!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SyncProgressCard(
                      isSyncing: _isSyncing,
                      isCancellationRequested: _cancelRequested,
                      message: _statusMessage,
                      progress: progressValue,
                      step: progress?.step,
                      totalSteps: progress?.totalSteps,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSyncing ? null : _syncAll,
                            icon: const Icon(Icons.sync),
                            label: Text(_isSyncing
                                ? 'Синхронизация...'
                                : 'Синхронизировать'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _isSyncing ? _cancelSync : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Отмена'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Журнал синхронизации',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _logEntries.isEmpty ? null : _copyLog,
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: const Text('Копировать'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _SyncLogPanel(
                      entries: _logEntries,
                      controller: _logController,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _MessageCard(
                        message: _errorMessage!,
                        color: const Color(0xFFBE123C),
                        icon: Icons.error_outline,
                      ),
                    ],
                    if (status != null) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Состояние данных',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final entity in status.entities)
                        _SyncEntityCard(
                          item: entity,
                          onTap: entity.id == 'checks'
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const KassaSyncScreen(),
                                    ),
                                  )
                              : null,
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _SyncProgressCard extends StatelessWidget {
  const _SyncProgressCard({
    required this.isSyncing,
    required this.isCancellationRequested,
    required this.message,
    required this.progress,
    required this.step,
    required this.totalSteps,
  });

  final bool isSyncing;
  final bool isCancellationRequested;
  final String message;
  final double progress;
  final int? step;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) {
    final color = isCancellationRequested
        ? const Color(0xFFD97706)
        : isSyncing
            ? Theme.of(context).colorScheme.primary
            : const Color(0xFF15803D);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isSyncing ? Icons.sync : Icons.cloud_done_outlined,
                    color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: isSyncing ? progress : 0),
            if (step != null && totalSteps != null) ...[
              const SizedBox(height: 8),
              Text('$step из $totalSteps',
                  style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncLogPanel extends StatelessWidget {
  const _SyncLogPanel({required this.entries, required this.controller});

  final List<_SyncLogEntry> entries;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(12),
      ),
      child: entries.isEmpty
          ? const Align(
              alignment: Alignment.topLeft,
              child: Text('Журнал появится после запуска синхронизации.',
                  style: TextStyle(color: Color(0xFFCBD5E1))),
            )
          : ListView.separated(
              controller: controller,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 7),
              itemBuilder: (_, index) {
                final entry = entries[index];
                return Text(
                  '${entry.time}  ${entry.prefix} ${entry.message}',
                  style: TextStyle(
                    color: entry.color,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                );
              },
            ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _SyncEntityCard extends StatelessWidget {
  const _SyncEntityCard({required this.item, this.onTap});

  final SyncEntityStatus item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasProblem = item.failedCount > 0;
    final hasQueue = item.pendingCount > 0;
    final accent = hasProblem
        ? const Color(0xFFBE123C)
        : hasQueue
            ? const Color(0xFFD97706)
            : const Color(0xFF15803D);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: .12),
          child: Icon(Icons.sync, color: accent),
        ),
        title: Text(item.title),
        subtitle: Text(
          '${item.subtitle}\n'
          'Последняя синхронизация: ${item.lastSyncedAt ?? 'ещё не выполнялась'}\n'
          'Очередь: ${item.pendingCount} | Ошибки: ${item.failedCount}',
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

enum _SyncLogType { info, success, warning, error }

class _SyncLogEntry {
  _SyncLogEntry({required this.message, required this.type})
      : time = _formatTime(DateTime.now());

  final String message;
  final _SyncLogType type;
  final String time;

  static String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String get prefix => switch (type) {
        _SyncLogType.info => '•',
        _SyncLogType.success => '✓',
        _SyncLogType.warning => '!',
        _SyncLogType.error => '✕',
      };

  Color get color => switch (type) {
        _SyncLogType.info => const Color(0xFFE2E8F0),
        _SyncLogType.success => const Color(0xFF86EFAC),
        _SyncLogType.warning => const Color(0xFFFDE68A),
        _SyncLogType.error => const Color(0xFFFDA4AF),
      };
}
