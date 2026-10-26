import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repository = DashboardRepository();
  DashboardDataModel? _data;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool showLoading = true}) async {
    setState(() {
      _isLoading = showLoading;
      _isRefreshing = !showLoading;
      _errorMessage = null;
    });
    try {
      final result = await _repository.loadLocal();
      if (mounted) {
        setState(() => _data = result.data);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              onPressed: () => _loadDashboard(showLoading: false),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _errorMessage != null && data == null
              ? ErrorView(message: _errorMessage!, onRetry: _loadDashboard)
              : data == null
                  ? const ErrorView(message: 'Нет данных для отображения')
                  : RefreshIndicator(
                      onRefresh: () => _loadDashboard(showLoading: false),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _StatCard(
                                  title: 'Продажи сегодня',
                                  value:
                                      formatMoney(data.stats.todaySalesTotal),
                                  color: const Color(0xFF166534)),
                              _StatCard(
                                  title: 'Прибыль за день',
                                  value:
                                      formatMoney(data.stats.todayProfitTotal),
                                  color: const Color(0xFF047857)),
                              _StatCard(
                                  title: 'Продажи за месяц',
                                  value:
                                      formatMoney(data.stats.monthSalesTotal),
                                  color: const Color(0xFF15803D)),
                              _StatCard(
                                  title: 'Прибыль за месяц',
                                  value:
                                      formatMoney(data.stats.monthProfitTotal),
                                  color: const Color(0xFF047857)),
                              _StatCard(
                                  title: 'Наличные',
                                  value: formatMoney(data.stats.todayCashTotal),
                                  color: const Color(0xFF15803D)),
                              _StatCard(
                                  title: 'Карта',
                                  value: formatMoney(data.stats.todayCardTotal),
                                  color: const Color(0xFFBE123C)),
                              _StatCard(
                                  title: 'В долг',
                                  value: formatMoney(data.stats.todayDebtTotal),
                                  color: const Color(0xFF991B1B)),
                              _StatCard(
                                  title: 'Бонус',
                                  value:
                                      formatMoney(data.stats.todayBonusTotal),
                                  color: const Color(0xFF374151)),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
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
                        borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 12),
                Text(title,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
}
