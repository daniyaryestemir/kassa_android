import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/product_model.dart';
import '../data/products_repository.dart';
import 'barcode_scanner_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.product});

  final ProductModel product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ProductsRepository();
  late final TextEditingController _nameController;
  late final TextEditingController _stockController;
  late final TextEditingController _costPriceController;
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _retailPriceController;
  late final List<TextEditingController> _barcodeControllers;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product.name);
    _stockController = TextEditingController(text: _numberText(product.stock));
    _costPriceController =
        TextEditingController(text: _numberText(product.costPrice));
    _wholesalePriceController =
        TextEditingController(text: _numberText(product.wholesalePrice));
    _retailPriceController =
        TextEditingController(text: _numberText(product.retailPrice));
    _barcodeControllers = product.barcodes
        .map((barcode) => TextEditingController(text: barcode))
        .toList();
  }

  String _numberText(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _wholesalePriceController.dispose();
    _retailPriceController.dispose();
    for (final controller in _barcodeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _parseNumber(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  void _addBarcode([String value = '']) {
    setState(() => _barcodeControllers.add(TextEditingController(text: value)));
  }

  void _removeBarcode(TextEditingController controller) {
    setState(() {
      _barcodeControllers.remove(controller);
      controller.dispose();
    });
  }

  int _ean13CheckDigit(String code) {
    var sum = 0;
    for (var index = 0; index < code.length; index++) {
      final digit = int.parse(code[index]);
      sum += index.isOdd ? digit * 3 : digit;
    }
    return (10 - sum % 10) % 10;
  }

  Future<void> _generateBarcode() async {
    final used = (await _repository.getUsedBarcodes()).toSet()
      ..removeAll(widget.product.barcodes);
    for (var number = 200000000000; number <= 299999999999; number++) {
      final base = number.toString();
      final barcode = '$base${_ean13CheckDigit(base)}';
      if (!used.contains(barcode)) {
        _addBarcode(barcode);
        return;
      }
    }
  }

  Future<void> _scanBarcode() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted)
        _showMessage('Разрешите доступ к камере в настройках телефона.');
      return;
    }
    if (!mounted) return;
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;
    final exists =
        _barcodeControllers.any((item) => item.text.trim() == barcode);
    if (exists) {
      _showMessage('Этот штрихкод уже добавлен.');
      return;
    }
    _addBarcode(barcode);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final stock = _parseNumber(_stockController.text)!;
    final costPrice = _parseNumber(_costPriceController.text)!;
    final wholesalePrice = _parseNumber(_wholesalePriceController.text)!;
    final retailPrice = _parseNumber(_retailPriceController.text)!;
    final barcodes = _barcodeControllers
        .map((controller) => controller.text.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toList(growable: false);
    if (barcodes.toSet().length != barcodes.length) {
      _showMessage('Удалите повторяющиеся штрихкоды.');
      return;
    }
    final used = (await _repository.getUsedBarcodes()).toSet()
      ..removeAll(widget.product.barcodes);
    final occupied = barcodes.where(used.contains).toList(growable: false);
    if (occupied.isNotEmpty) {
      _showMessage('Штрихкод уже используется: ${occupied.join(', ')}');
      return;
    }

    final updated = ProductModel(
      uuid: widget.product.uuid,
      name: _nameController.text.trim(),
      stock: stock,
      costPrice: costPrice,
      retailPrice: retailPrice,
      wholesalePrice: wholesalePrice,
      category: widget.product.category,
      primaryBarcode: barcodes.isEmpty ? '' : barcodes.first,
      barcodes: barcodes,
      lastModified: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
      isDeleted: false,
    );
    setState(() => _isSaving = true);
    try {
      await _repository.saveLocalProduct(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String? _requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Заполните поле' : null;

  String? _numberValidator(String? value) {
    final number = _parseNumber(value ?? '');
    return number == null || number < 0 ? 'Укажите число не меньше нуля' : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Карточка товара'),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('СОХРАНИТЬ'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                onTap: () => _selectAll(_nameController),
                validator: _requiredText,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                onTap: () => _selectAll(_stockController),
                validator: _numberValidator,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Количество'),
              ),
              const SizedBox(height: 20),
              const Text('Цены',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _costPriceController,
                onTap: () => _selectAll(_costPriceController),
                validator: _numberValidator,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Поступление'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _wholesalePriceController,
                onTap: () => _selectAll(_wholesalePriceController),
                validator: _numberValidator,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Опт'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _retailPriceController,
                onTap: () => _selectAll(_retailPriceController),
                validator: _numberValidator,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Продажа'),
              ),
              const SizedBox(height: 24),
              const Text('Штрихкоды',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final controller in _barcodeControllers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          onTap: () => _selectAll(controller),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Штрихкод'),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeBarcode(controller),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Удалить штрихкод',
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _addBarcode(),
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _generateBarcode,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Сгенерировать'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Сканировать'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Сохранить изменения'),
              ),
            ],
          ),
        ),
      );
}
