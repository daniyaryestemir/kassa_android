import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_view.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/loading_view.dart';
import '../../nomenklatura/data/product_model.dart';
import '../../nomenklatura/presentation/barcode_scanner_screen.dart';
import '../data/kassa_repository.dart';
import 'cart_controller.dart';

class KassaScreen extends StatefulWidget {
  const KassaScreen({super.key});

  @override
  State<KassaScreen> createState() => _KassaScreenState();
}

class _KassaScreenState extends State<KassaScreen> {
  final _repository = KassaRepository();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _cart = CartController();

  List<ProductModel> _products = const [];
  String _saleMode = 'retail';
  String _paymentMethod = 'cash';
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSubmitting = false;
  int _searchSession = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cart.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _isRefreshing = !showLoading;
      _errorMessage = null;
    });
    try {
      final result = await _repository.load();
      if (!mounted) return;
      setState(() {
        _products = result.products;
      });
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

  Future<void> _reload() => _loadData(showLoading: false);

  void _addProduct(ProductModel product) {
    _cart.addProduct({
      'uuid': product.uuid,
      'nazvanie': product.name,
      'kolichestvo': product.stock,
      'tsena_zakupki': product.costPrice,
      'tsena_prodazhi': product.retailPrice,
      'tsena_optom': product.wholesalePrice,
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
    // RawAutocomplete keeps its own selected option. Recreating it prevents
    // a stale selection from blocking subsequent additions of the same item.
    setState(() => _searchSession++);
  }

  void _addProductFromSearch(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return;

    ProductModel? product;
    for (final item in _products) {
      final isExactMatch = item.name.toLowerCase() == query ||
          item.primaryBarcode.toLowerCase() == query ||
          item.barcodes.any((barcode) => barcode.toLowerCase() == query);
      if (isExactMatch) {
        product = item;
        break;
      }
    }
    product ??= _products.cast<ProductModel?>().firstWhere(
          (item) =>
              item!.name.toLowerCase().contains(query) ||
              item.primaryBarcode.toLowerCase().contains(query) ||
              item.barcodes.any(
                (barcode) => barcode.toLowerCase().contains(query),
              ),
          orElse: () => null,
        );
    if (product != null) _addProduct(product);
  }

  Future<void> _scanAndAddProduct() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Разрешите доступ к камере в настройках телефона.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;

    ProductModel? product;
    for (final item in _products) {
      if (item.primaryBarcode == barcode || item.barcodes.contains(barcode)) {
        product = item;
        break;
      }
    }
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Товар со штрихкодом $barcode не найден.')),
      );
      return;
    }

    _addProduct(product);
  }

  Future<void> _showQuickProducts() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет товаров для быстрого добавления.')),
      );
      return;
    }

    final product = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.flash_on_outlined),
                    SizedBox(width: 8),
                    Text(
                      'Быстрые товары',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final item = _products[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatMoney(
                                _saleMode == 'wholesale'
                                    ? item.wholesalePrice
                                    : item.retailPrice,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (product != null) _addProduct(product);
  }

  Future<void> _choosePaymentMethod() async {
    if (_cart.isEmpty || _isSubmitting) return;
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Способ оплаты')),
          for (final option in const [
            ('cash', 'Наличные', Icons.payments_outlined),
            ('card', 'Карта', Icons.credit_card_outlined),
            ('debt', 'Долг', Icons.receipt_long_outlined),
            ('bonus', 'Бонус', Icons.stars_outlined),
          ])
            ListTile(
              leading: Icon(option.$3),
              title: Text(option.$2),
              onTap: () => Navigator.pop(context, option.$1),
            ),
        ]),
      ),
    );
    if (!mounted || method == null) return;
    setState(() => _paymentMethod = method);
    await _checkout();
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await _repository.checkout(
        payload: _cart.toCheckoutPayload(
          saleMode: _saleMode,
          paymentMethod: _paymentMethod,
        ),
        saleMode: _saleMode,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      _cart.clear();
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _saleMode = 'retail';
        _searchSession++;
      });
      await _loadData(showLoading: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _editCartItem(CartItem item) async {
    final quantityController = TextEditingController(text: '${item.quantity}');
    final priceController = TextEditingController(
      text: _formatEditablePrice(item.priceForMode(_saleMode)),
    );
    quantityController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: quantityController.text.length,
    );
    final result = await showDialog<({int quantity, double price})>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              autofocus: true,
              onTap: () => _selectAll(quantityController),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Количество'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              onTap: () => _selectAll(priceController),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Цена',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text.trim());
              final price = double.tryParse(
                priceController.text.trim().replaceAll(',', '.'),
              );
              if (quantity == null ||
                  quantity < 0 ||
                  price == null ||
                  price < 0) {
                return;
              }
              Navigator.pop(context, (quantity: quantity, price: price));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    quantityController.dispose();
    priceController.dispose();
    if (result == null) return;
    _cart.updateItem(
      uuid: item.uuid,
      quantity: result.quantity,
      price: result.price,
      saleMode: _saleMode,
    );
  }

  void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWholesale = _saleMode == 'wholesale';
    final accentColor =
        isWholesale ? const Color(0xFF1D4ED8) : const Color(0xFF15803D);
    final backgroundColor =
        isWholesale ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        title: const Text('Касса'),
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
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: isWholesale ? Colors.white : accentColor,
                backgroundColor:
                    isWholesale ? const Color(0xFF2563EB) : Colors.white,
              ),
              onPressed: () => setState(() =>
                  _saleMode = _saleMode == 'retail' ? 'wholesale' : 'retail'),
              icon: Icon(_saleMode == 'retail'
                  ? Icons.storefront_outlined
                  : Icons.inventory_2_outlined),
              label: Text(_saleMode == 'retail' ? 'Розница' : 'Оптом'),
            ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: RawAutocomplete<ProductModel>(
                  key: ValueKey(_searchSession),
                  textEditingController: _searchController,
                  focusNode: _searchFocusNode,
                  displayStringForOption: (product) => product.name,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return const Iterable<ProductModel>.empty();
                    }
                    return _products.where((product) =>
                        product.name.toLowerCase().contains(query) ||
                        product.primaryBarcode.toLowerCase().contains(query) ||
                        product.barcodes.any(
                          (barcode) => barcode.toLowerCase().contains(query),
                        ));
                  },
                  onSelected: _addProduct,
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) =>
                          TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onSubmitted: _addProductFromSearch,
                    decoration: const InputDecoration(
                        hintText: 'Поиск по названию или штрихкоду',
                        prefixIcon: Icon(Icons.search)),
                  ),
                  optionsViewBuilder: (context, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            for (final product in options)
                              ListTile(
                                title: Text(product.name),
                                subtitle: product.primaryBarcode.isEmpty
                                    ? null
                                    : Text('ШК: ${product.primaryBarcode}'),
                                trailing: Text(formatMoney(
                                    _saleMode == 'wholesale'
                                        ? product.wholesalePrice
                                        : product.retailPrice)),
                                onTap: () => onSelected(product),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _scanAndAddProduct,
                icon: const Icon(Icons.barcode_reader),
                tooltip: 'Сканировать товар',
              ),
            ],
          ),
        ),
        Expanded(child: _buildCart()),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
          child: AnimatedBuilder(
            animation: _cart,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _showQuickProducts,
                    icon: const Icon(Icons.flash_on_outlined),
                    label: const Text('Быстрые товары'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    onPressed: _cart.isEmpty || _isSubmitting
                        ? null
                        : _choosePaymentMethod,
                    child: Text(_isSubmitting ? 'Сохранение...' : 'Оплата'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCart() {
    if (_isLoading) {
      return const LoadingView();
    }
    if (_errorMessage != null && _products.isEmpty) {
      return ErrorView(message: _errorMessage!, onRetry: _loadData);
    }
    return AnimatedBuilder(
      animation: _cart,
      builder: (context, _) {
        final total = _cart.totalAmount(_saleMode);
        if (_cart.isEmpty) {
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.all(16), children: const [
              SizedBox(height: 72),
              EmptyView('Корзина пуста')
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: _cart.items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Row(children: [
                  Text('Корзина: ${_cart.totalItems}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Итого: ${formatMoney(total)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]);
              }
              final item = _cart.items[index - 1];
              final lineSum = item.priceForMode(_saleMode) * item.quantity;
              return Card(
                  child: ListTile(
                onTap: () => _editCartItem(item),
                title: Text(item.name),
                subtitle: item.quantity > item.stock
                    ? const Text('Количество больше остатка',
                        style: TextStyle(color: Color(0xFFB91C1C)))
                    : null,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatMoney(lineSum)),
                  IconButton(
                      onPressed: () => _cart.decrease(item.uuid),
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('${item.quantity}'),
                  IconButton(
                      onPressed: () => _cart.increase(item.uuid),
                      icon: const Icon(Icons.add_circle_outline)),
                ]),
              ));
            },
          ),
        );
      },
    );
  }
}

String _formatEditablePrice(double value) =>
    value == value.truncateToDouble() ? value.toInt().toString() : '$value';
