import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/formatters.dart';
import '../../nomenklatura/data/product_model.dart';
import '../../nomenklatura/data/products_repository.dart';
import '../../nomenklatura/presentation/new_product_screen.dart';
import '../data/receipt_models.dart';
import '../data/receipts_repository.dart';

class NewReceiptScreen extends StatefulWidget {
  const NewReceiptScreen({super.key});

  @override
  State<NewReceiptScreen> createState() => _NewReceiptScreenState();
}

class _NewReceiptScreenState extends State<NewReceiptScreen> {
  final _repository = ReceiptsRepository();
  final _productsRepository = ProductsRepository();
  final _uuid = const Uuid();
  final List<_DraftItem> _items = [];
  late Future<List<String>> _suppliersFuture;
  String? _supplier;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _suppliersFuture = _repository.getLocalSuppliers();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final products = await _productsRepository.getLocalProducts();
    if (!mounted) {
      return;
    }
    final product = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductPicker(products: products),
    );
    if (product == null ||
        _items.any((item) => item.product.uuid == product.uuid)) {
      return;
    }
    setState(() => _items.add(_DraftItem(product)));
  }

  Future<void> _addSupplier(List<String> suppliers) async {
    final controller = TextEditingController();
    final supplier = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить контрагента'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Название контрагента'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || supplier == null || supplier.isEmpty) return;
    final updatedSuppliers = [...suppliers];
    if (!updatedSuppliers
        .any((item) => item.toLowerCase() == supplier.toLowerCase())) {
      updatedSuppliers.add(supplier);
      updatedSuppliers
          .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
    setState(() {
      _supplier = updatedSuppliers.firstWhere(
        (item) => item.toLowerCase() == supplier.toLowerCase(),
      );
      _suppliersFuture = Future.value(updatedSuppliers);
    });
  }

  Future<void> _save() async {
    final supplier = _supplier;
    if (supplier == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Укажите поставщика и добавьте хотя бы один товар.')),
      );
      return;
    }
    final invalid = _items.any((item) => item.quantity <= 0);
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Количество каждого товара должно быть больше нуля.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final receiptUuid = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    try {
      await _repository.saveNewReceipt(
        uuid: receiptUuid,
        supplier: supplier,
        products: _items.map((item) => item.product).toList(),
        items: [
          for (var index = 0; index < _items.length; index++)
            _items[index].toModel(receiptUuid, index, now),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _items.fold<double>(0, (sum, item) => sum + item.purchaseTotal);
    return Scaffold(
      appBar: AppBar(title: const Text('Новая накладная')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _pickProduct,
        icon: const Icon(Icons.add),
        label: const Text('Добавить товар'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          FutureBuilder<List<String>>(
            future: _suppliersFuture,
            builder: (context, snapshot) {
              final suppliers = snapshot.data ?? const <String>[];
              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_supplier),
                      initialValue:
                          suppliers.contains(_supplier) ? _supplier : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Поставщик / контрагент',
                      ),
                      hint: const Text('Выберите контрагента'),
                      items: suppliers
                          .map((supplier) => DropdownMenuItem(
                                value: supplier,
                                child: Text(supplier,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(growable: false),
                      onChanged: _isSaving
                          ? null
                          : (supplier) => setState(() => _supplier = supplier),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Добавить контрагента',
                    onPressed: _isSaving ? null : () => _addSupplier(suppliers),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          for (var index = 0; index < _items.length; index++)
            _DraftItemCard(
              item: _items[index],
              onChanged: () => setState(() {}),
              onSubmitted: (fieldIndex) => _focusNextRow(index, fieldIndex),
              onDelete: () => setState(() {
                _items[index].dispose();
                _items.removeAt(index);
              }),
            ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              title: const Text('Итого закупка'),
              trailing: Text(formatMoney(total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isSaving ? 'Сохранение...' : 'Сохранить накладную'),
          ),
        ],
      ),
    );
  }

  void _focusNextRow(int itemIndex, int fieldIndex) {
    if (itemIndex + 1 >= _items.length) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _items[itemIndex + 1].focusNodes[fieldIndex].requestFocus();
  }
}

class _DraftItem {
  _DraftItem(this.product)
      : quantityController = TextEditingController(text: '1'),
        costController = TextEditingController(
            text: _formatEditableNumber(product.costPrice)),
        wholesaleController = TextEditingController(
            text: _formatEditableNumber(product.wholesalePrice)),
        retailController = TextEditingController(
            text: _formatEditableNumber(product.retailPrice)),
        focusNodes = List.generate(4, (_) => FocusNode());
  final ProductModel product;
  final TextEditingController quantityController;
  final TextEditingController costController;
  final TextEditingController wholesaleController;
  final TextEditingController retailController;
  final List<FocusNode> focusNodes;
  double get quantity =>
      double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
  double get cost =>
      double.tryParse(costController.text.replaceAll(',', '.')) ?? 0;
  double get wholesale =>
      double.tryParse(wholesaleController.text.replaceAll(',', '.')) ?? 0;
  double get retail =>
      double.tryParse(retailController.text.replaceAll(',', '.')) ?? 0;
  double get purchaseTotal => quantity * cost;
  ReceiptItemModel toModel(String receiptUuid, int index, String now) =>
      ReceiptItemModel(
        uuid: '$receiptUuid-item-$index',
        receiptUuid: receiptUuid,
        name: product.name,
        quantity: quantity,
        costPrice: cost,
        wholesalePrice: wholesale,
        retailPrice: retail,
        purchaseSum: purchaseTotal,
        retailTotalSum: quantity * retail,
        lastModified: now,
        syncStatus: 'pending',
        isDeleted: false,
      );
  void dispose() {
    quantityController.dispose();
    costController.dispose();
    wholesaleController.dispose();
    retailController.dispose();
    for (final focusNode in focusNodes) {
      focusNode.dispose();
    }
  }
}

String _formatEditableNumber(num value) =>
    value == value.truncateToDouble() ? value.toInt().toString() : '$value';

class _DraftItemCard extends StatelessWidget {
  const _DraftItemCard(
      {required this.item,
      required this.onChanged,
      required this.onSubmitted,
      required this.onDelete});
  final _DraftItem item;
  final VoidCallback onChanged;
  final ValueChanged<int> onSubmitted;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: onDelete, icon: const Icon(Icons.delete_outline))
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _NumberField(
                  label: 'Количество',
                  controller: item.quantityController,
                  focusNode: item.focusNodes[0],
                  onSubmitted: () => onSubmitted(0),
                  onChanged: onChanged),
              _NumberField(
                  label: 'Закупка',
                  controller: item.costController,
                  focusNode: item.focusNodes[1],
                  onSubmitted: () => onSubmitted(1),
                  onChanged: onChanged),
              _NumberField(
                  label: 'Опт',
                  controller: item.wholesaleController,
                  focusNode: item.focusNodes[2],
                  onSubmitted: () => onSubmitted(2),
                  onChanged: onChanged),
              _NumberField(
                  label: 'Розница',
                  controller: item.retailController,
                  focusNode: item.focusNodes[3],
                  onSubmitted: () => onSubmitted(3),
                  onChanged: onChanged),
            ]),
            const SizedBox(height: 10),
            Text('Сумма закупки: ${formatMoney(item.purchaseTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _NumberField extends StatelessWidget {
  const _NumberField(
      {required this.label,
      required this.controller,
      required this.focusNode,
      required this.onChanged,
      required this.onSubmitted});
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 150,
      child: TextField(
          controller: controller,
          focusNode: focusNode,
          onTap: () {
            controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            );
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(labelText: label)));
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.products});
  final List<ProductModel> products;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';

  Future<void> _addNewProduct() async {
    final product = await Navigator.of(context).push<ProductModel>(
      MaterialPageRoute(builder: (_) => const NewProductScreen()),
    );
    if (!mounted || product == null) return;
    Navigator.of(context).pop(product);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.products
        .where((product) =>
            product.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return SafeArea(
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
                height: 560,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                          autofocus: true,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Поиск товара'))),
                  Expanded(
                      child: ListView.builder(
                          itemCount: result.length,
                          itemBuilder: (_, index) {
                            final product = result[index];
                            return ListTile(
                                title: Text(product.name),
                                subtitle: Text(
                                    'Остаток: ${_formatEditableNumber(product.stock)}'),
                                trailing: Text(formatMoney(product.costPrice)),
                                onTap: () => Navigator.pop(context, product));
                          })),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: FilledButton.icon(
                      onPressed: _addNewProduct,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('Добавить новый товар'),
                    ),
                  ),
                ]))));
  }
}
