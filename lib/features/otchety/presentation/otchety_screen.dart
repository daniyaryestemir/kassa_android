import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/otchety_api.dart';

class OtchetyScreen extends StatefulWidget {
  const OtchetyScreen({super.key});

  @override
  State<OtchetyScreen> createState() => _OtchetyScreenState();
}

class _OtchetyScreenState extends State<OtchetyScreen> {
  final _api = OtchetyApi();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.loadReport();
  }

  @override
  void dispose() {
    _dateFromController.dispose();
    _dateToController.dispose();
    super.dispose();
  }

  void _loadReport() {
    setState(() {
      _future = _api.loadReport(
        dateFrom: _dateFromController.text,
        dateTo: _dateToController.text,
      );
    });
  }

  void _reload() {
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчет'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dateFromController,
                        decoration: const InputDecoration(
                          labelText: 'Дата с',
                          hintText: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dateToController,
                        decoration: const InputDecoration(
                          labelText: 'Дата по',
                          hintText: 'YYYY-MM-DD',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _loadReport,
                      child: const Text('Ок'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
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

                final filters =
                    snapshot.data!['filters'] as Map<String, dynamic>? ??
                        <String, dynamic>{};
                final summary =
                    snapshot.data!['summary'] as Map<String, dynamic>? ??
                        <String, dynamic>{};
                final items =
                    snapshot.data!['items'] as List<dynamic>? ?? <dynamic>[];

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      _ReportHeader(
                        dateFrom: filters['date_from']?.toString() ?? '',
                        dateTo: filters['date_to']?.toString() ?? '',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryCard(
                            title: 'Продажи',
                            value: formatMoney(
                                (summary['total_sale_sum'] ?? 0) as num),
                            color: const Color(0xFF166534),
                          ),
                          _SummaryCard(
                            title: 'Прибыль',
                            value: formatMoney(
                                (summary['total_profit_sum'] ?? 0) as num),
                            color: const Color(0xFF15803D),
                          ),
                          _SummaryCard(
                            title: 'Наличные',
                            value: formatMoney(
                                (summary['cash_total'] ?? 0) as num),
                            color: const Color(0xFF15803D),
                          ),
                          _SummaryCard(
                            title: 'Карта',
                            value: formatMoney(
                                (summary['card_total'] ?? 0) as num),
                            color: const Color(0xFF047857),
                          ),
                          _SummaryCard(
                            title: 'Долг',
                            value: formatMoney(
                                (summary['debt_total'] ?? 0) as num),
                            color: const Color(0xFFBE123C),
                          ),
                          _SummaryCard(
                            title: 'Чеки',
                            value: '${summary['checks_count'] ?? 0}',
                            color: const Color(0xFF374151),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Товарные строки',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (items.isEmpty)
                        const EmptyView('За выбранный период данных нет'),
                      for (final raw in items.take(80))
                        _ReportItemCard(item: raw as Map<String, dynamic>),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.dateFrom,
    required this.dateTo,
  });

  final String dateFrom;
  final String dateTo;

  @override
  Widget build(BuildContext context) {
    final text = (dateFrom.isEmpty && dateTo.isEmpty)
        ? 'Период: все данные'
        : 'Период: ${dateFrom.isEmpty ? '...' : dateFrom} - ${dateTo.isEmpty ? '...' : dateTo}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportItemCard extends StatelessWidget {
  const _ReportItemCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name']?.toString() ?? '-',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    title: 'Кол-во',
                    value: '${item['quantity'] ?? 0}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    title: 'Ср. закупка',
                    value: formatMoney((item['avg_cost'] ?? 0) as num),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    title: 'Ср. продажа',
                    value: formatMoney((item['avg_sale'] ?? 0) as num),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Выручка: ${formatMoney((item['sale_sum'] ?? 0) as num)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            Text(
              'Прибыль: ${formatMoney((item['total_profit'] ?? 0) as num)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
