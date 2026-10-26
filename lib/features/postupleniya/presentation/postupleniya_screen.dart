import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/receipt_models.dart';
import '../data/receipts_repository.dart';
import 'new_receipt_screen.dart';
import 'postuplenie_detail_screen.dart';

class PostupleniyaScreen extends StatefulWidget {
  const PostupleniyaScreen({super.key});

  @override
  State<PostupleniyaScreen> createState() => _PostupleniyaScreenState();
}

class _PostupleniyaScreenState extends State<PostupleniyaScreen> {
  final _repository = ReceiptsRepository();
  final _controller = TextEditingController();

  List<ReceiptSummaryModel> _receipts = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    final query = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final localReceipts = await _repository.getLocalReceipts(query: query);

    if (!mounted) {
      return;
    }

    setState(() {
      _receipts = localReceipts;
      _isLoading = false;
    });
  }

  Future<void> _syncReceipts({bool showBlockingError = false}) async {
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
      final syncedCount = await _repository.syncReceipts();
      final refreshed = await _repository.getLocalReceipts(
        query: _controller.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _receipts = refreshed;
        _errorMessage = null;
        _infoMessage = syncedCount == 0
            ? 'Синхронизация завершена, поступлений не найдено'
            : 'Синхронизировано поступлений: $syncedCount';
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

  void _search() {
    _loadReceipts();
  }

  Future<void> _reload() async {
    await _syncReceipts(showBlockingError: _receipts.isEmpty);
  }

  Future<void> _createReceipt() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewReceiptScreen()),
    );
    if (saved == true && mounted) {
      await _loadReceipts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Поступления'),
        ),
        actions: [
          IconButton(
            onPressed: _createReceipt,
            icon: const Icon(Icons.add),
            tooltip: 'Добавить накладную',
          ),
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
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'Поиск по контрагенту',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _search,
                  child: const Text('Найти'),
                ),
              ],
            ),
          ),
          if (_infoMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
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
            ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const LoadingView();
                }

                if (_errorMessage != null && _receipts.isEmpty) {
                  return ErrorView(
                    message: _errorMessage!,
                    onRetry: _reload,
                  );
                }

                if (_receipts.isEmpty) {
                  return const EmptyView('Поступления не найдены');
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      for (final receipt in _receipts)
                        _ReceiptTile(item: receipt),
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

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.item});

  final ReceiptSummaryModel item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          item.kontragent.isEmpty ? '-' : item.kontragent,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Дата: ${item.date.isEmpty ? '-' : item.date}',
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(item.purchaseSum),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Продажа: ${formatMoney(item.retailSum)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostuplenieDetailScreen(
                receiptUuid: item.uuid,
              ),
            ),
          );
        },
      ),
    );
  }
}
