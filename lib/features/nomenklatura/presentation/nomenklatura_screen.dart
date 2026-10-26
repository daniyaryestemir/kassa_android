import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../data/product_model.dart';
import '../data/products_repository.dart';
import 'product_detail_screen.dart';

class NomenklaturaScreen extends StatefulWidget {
  const NomenklaturaScreen({super.key});

  @override
  State<NomenklaturaScreen> createState() => _NomenklaturaScreenState();
}

class _NomenklaturaScreenState extends State<NomenklaturaScreen> {
  final _repository = ProductsRepository();
  final _controller = TextEditingController();

  List<ProductModel> _products = const [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final query = _controller.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final localProducts = await _repository.getLocalProducts(query: query);

    if (!mounted) {
      return;
    }

    setState(() {
      _products = localProducts;
      _isLoading = false;
    });
  }

  Future<void> _syncProducts({bool showBlockingError = false}) async {
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
      final syncedCount = await _repository.syncProducts();
      final refreshedProducts = await _repository.getLocalProducts(
        query: _controller.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products = refreshedProducts;
        _errorMessage = null;
        _infoMessage = syncedCount == 0
            ? 'Синхронизация завершена, товаров не найдено'
            : 'Синхронизировано товаров: $syncedCount';
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
    _loadProducts();
  }

  Future<void> _reload() async {
    await _syncProducts(showBlockingError: _products.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Номенклатура'),
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
                      hintText: 'Поиск по названию, категории или штрихкоду',
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

                if (_errorMessage != null && _products.isEmpty) {
                  return ErrorView(
                    message: _errorMessage!,
                    onRetry: _reload,
                  );
                }

                if (_products.isEmpty) {
                  return const EmptyView('Товары не найдены');
                }

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      for (final product in _products)
                        _ProductTile(
                          item: product,
                          onTap: () async {
                            final updated =
                                await Navigator.of(context).push<ProductModel>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: product),
                              ),
                            );
                            if (updated != null && mounted) {
                              await _loadProducts();
                            }
                          },
                        ),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item, required this.onTap});

  final ProductModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = item.stock;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name.isEmpty ? '-' : item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatMoney(item.retailPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Закуп: ${formatMoney(item.costPrice)} · '
                      'Опт: ${formatMoney(item.wholesalePrice)} · '
                      'Остаток: ${stock.toStringAsFixed(stock.truncateToDouble() == stock ? 0 : 2)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
