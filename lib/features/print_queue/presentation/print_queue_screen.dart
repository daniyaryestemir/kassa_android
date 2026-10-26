import 'package:flutter/material.dart';

import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/print_queue_api.dart';

class PrintQueueScreen extends StatefulWidget {
  const PrintQueueScreen({super.key});

  @override
  State<PrintQueueScreen> createState() => _PrintQueueScreenState();
}

class _PrintQueueScreenState extends State<PrintQueueScreen> {
  final _api = PrintQueueApi();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.loadQueue();
  }

  void _reload() {
    setState(() {
      _future = _api.loadQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Очередь печати'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final groups =
              snapshot.data!['queue_groups'] as List<dynamic>? ?? <dynamic>[];
          if (groups.isEmpty) {
            return const EmptyView('Очередь печати пока пуста');
          }

          final processingCount = groups.where((raw) {
            final item = raw as Map<String, dynamic>;
            return (item['status']?.toString() ?? '') == 'processing';
          }).length;

          final queuedCount = groups.where((raw) {
            final item = raw as Map<String, dynamic>;
            return (item['status']?.toString() ?? '') == 'queue';
          }).length;

          final errorCount = groups.where((raw) {
            final item = raw as Map<String, dynamic>;
            return (item['status']?.toString() ?? '') == 'error';
          }).length;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _QueueSummary(
                  totalCount: groups.length,
                  queuedCount: queuedCount,
                  processingCount: processingCount,
                  errorCount: errorCount,
                ),
                const SizedBox(height: 12),
                for (final raw in groups)
                  _QueueJobCard(item: raw as Map<String, dynamic>),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.totalCount,
    required this.queuedCount,
    required this.processingCount,
    required this.errorCount,
  });

  final int totalCount;
  final int queuedCount;
  final int processingCount;
  final int errorCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              title: 'Всего',
              value: '$totalCount',
              color: const Color(0xFF15803D),
            ),
            _SummaryTile(
              title: 'В очереди',
              value: '$queuedCount',
              color: const Color(0xFF15803D),
            ),
            _SummaryTile(
              title: 'В работе',
              value: '$processingCount',
              color: const Color(0xFF166534),
            ),
            _SummaryTile(
              title: 'Ошибки',
              value: '$errorCount',
              color: const Color(0xFFBE123C),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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

class _QueueJobCard extends StatelessWidget {
  const _QueueJobCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? '';
    final statusColor = switch (status) {
      'processing' => const Color(0xFF166534),
      'error' => const Color(0xFFBE123C),
      'queue' => const Color(0xFF15803D),
      _ => const Color(0xFF374151),
    };

    final statusLabel = switch (status) {
      'processing' => 'В работе',
      'error' => 'Ошибка',
      'queue' => 'В очереди',
      _ => status.isEmpty ? 'Неизвестно' : status,
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
                    'Задание печати',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoBox(
                    title: 'Элементов',
                    value: '${item['items_count'] ?? 0}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoBox(
                    title: 'Копий',
                    value: '${item['total_copies'] ?? 0}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Создано: ${item['created_at'] ?? '-'}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
