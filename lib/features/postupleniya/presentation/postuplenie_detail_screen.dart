import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/receipt_models.dart';
import '../data/receipts_repository.dart';

class PostuplenieDetailScreen extends StatefulWidget {
  const PostuplenieDetailScreen({
    required this.receiptUuid,
    super.key,
  });

  final String receiptUuid;

  @override
  State<PostuplenieDetailScreen> createState() =>
      _PostuplenieDetailScreenState();
}

class _PostuplenieDetailScreenState extends State<PostuplenieDetailScreen> {
  final _repository = ReceiptsRepository();

  ReceiptDetailModel? _detail;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final localDetail =
        await _repository.getLocalReceiptDetail(widget.receiptUuid);

    if (!mounted) {
      return;
    }

    setState(() {
      _detail = localDetail;
      _isLoading = false;
    });
  }

  Future<void> _syncDetail({bool showBlockingError = false}) async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      if (!showBlockingError) {
        _errorMessage = null;
      }
    });

    try {
      final syncedDetail =
          await _repository.syncReceiptDetail(widget.receiptUuid);

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = syncedDetail;
        _errorMessage = null;
        _infoMessage = 'Детали поступления обновлены';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (showBlockingError) {
          _errorMessage = error.toString();
        } else {
          _infoMessage = 'Нет сети.';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали поступления'),
        actions: [
          if (_isRefreshing)
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
              onPressed: () => _syncDetail(showBlockingError: _detail == null),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_isLoading) {
            return const LoadingView();
          }

          if (_errorMessage != null && _detail == null) {
            return ErrorView(
              message: _errorMessage!,
              onRetry: _loadDetail,
            );
          }

          final detail = _detail;
          if (detail == null) {
            return const ErrorView(message: 'Поступление не найдено');
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.receipt.kontragent.isEmpty
                            ? '-'
                            : detail.receipt.kontragent,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Дата: ${detail.receipt.date.isEmpty ? '-' : detail.receipt.date}'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailMetric(
                              title: 'Закупка',
                              value: formatMoney(detail.receipt.purchaseSum),
                              color: const Color(0xFF166534),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DetailMetric(
                              title: 'Розница',
                              value: formatMoney(detail.receipt.retailSum),
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DetailMetric(
                              title: 'Опт',
                              value: formatMoney(detail.receipt.wholesaleSum),
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Состав поступления',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in detail.items) _ReceiptItemTile(item: item),
            ],
          );
        },
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemTile extends StatelessWidget {
  const _ReceiptItemTile({required this.item});

  final ReceiptItemModel item;

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
              item.name.isEmpty ? '-' : item.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LineMetric(
                    title: 'Количество',
                    value: '${item.quantity}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LineMetric(
                    title: 'Закупка',
                    value: formatMoney(item.costPrice),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LineMetric(
                    title: 'Розница',
                    value: formatMoney(item.retailPrice),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Сумма закупки: ${formatMoney(item.purchaseSum)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Сумма продажи: ${formatMoney(item.retailTotalSum)}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineMetric extends StatelessWidget {
  const _LineMetric({
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
