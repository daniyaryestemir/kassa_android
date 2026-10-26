import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../data/product_model.dart';
import '../data/products_repository.dart';
import 'barcode_scanner_screen.dart';

class NewProductScreen extends StatefulWidget {
  const NewProductScreen({super.key});

  @override
  State<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends State<NewProductScreen> {
  final _repository = ProductsRepository();
  final _uuid = const Uuid();
  final _nameController = TextEditingController();
  final List<TextEditingController> _barcodeControllers = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _barcodeControllers) {
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _scanBarcode() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (!mounted) {
        return;
      }
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нужен доступ к камере'),
          content: const Text(
            'Разрешите доступ к камере, чтобы сканировать штрихкоды товаров.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Открыть настройки'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
      return;
    }

    if (!mounted) {
      return;
    }
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) {
      return;
    }

    final isAlreadyAdded = _barcodeControllers
        .any((controller) => controller.text.trim() == barcode);
    if (isAlreadyAdded) {
      _showMessage('Этот штрихкод уже добавлен.');
      return;
    }
    _addBarcode(barcode);
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
    final used = (await _repository.getUsedBarcodes()).toSet();
    for (var number = 200000000000; number <= 299999999999; number++) {
      final base = number.toString();
      final barcode = '$base${_ean13CheckDigit(base)}';
      if (!used.contains(barcode)) {
        _addBarcode(barcode);
        return;
      }
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Укажите наименование товара.');
      return;
    }

    final barcodes = _barcodeControllers
        .map((controller) => controller.text.trim())
        .where((barcode) => barcode.isNotEmpty)
        .toList(growable: false);
    final duplicate = barcodes.toSet().length != barcodes.length;
    if (duplicate) {
      _showMessage('Удалите повторяющиеся штрихкоды.');
      return;
    }
    final used = (await _repository.getUsedBarcodes()).toSet();
    final occupied = barcodes.where(used.contains).toList(growable: false);
    if (occupied.isNotEmpty) {
      _showMessage('Штрихкод уже используется: ${occupied.join(', ')}');
      return;
    }

    final now = DateTime.now().toIso8601String();
    final product = ProductModel(
      uuid: _uuid.v4(),
      name: name,
      stock: 0,
      costPrice: 0,
      retailPrice: 0,
      wholesalePrice: 0,
      category: '',
      primaryBarcode: barcodes.isEmpty ? '' : barcodes.first,
      barcodes: barcodes,
      lastModified: now,
      syncStatus: 'pending',
      isDeleted: false,
    );

    setState(() => _isSaving = true);
    try {
      await _repository.saveLocalProduct(product);
      if (mounted) Navigator.of(context).pop(product);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Добавление нового товара')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Наименование товара'),
            ),
            const SizedBox(height: 24),
            const Text('Штрих-коды',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final controller in _barcodeControllers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Штрих-код'),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeBarcode(controller),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Удалить штрих-код',
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _scanBarcode,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Сканировать штрихкод'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _generateBarcode,
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: const Text('Сгенерировать штрих-код'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Сохранение...' : 'Сохранить товар'),
            ),
          ],
        ),
      );
}
