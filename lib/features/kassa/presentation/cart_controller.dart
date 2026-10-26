import 'package:flutter/foundation.dart';

class CartItem {
  CartItem({
    required this.uuid,
    required this.name,
    required this.stock,
    required this.costPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    this.quantity = 1,
  });

  final String uuid;
  final String name;
  final double stock;
  final double costPrice;
  final double retailPrice;
  final double wholesalePrice;
  final int quantity;

  double priceForMode(String saleMode) {
    return saleMode == 'wholesale' ? wholesalePrice : retailPrice;
  }

  CartItem copyWith({
    int? quantity,
    double? retailPrice,
    double? wholesalePrice,
  }) {
    return CartItem(
      uuid: uuid,
      name: name,
      stock: stock,
      costPrice: costPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartController extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList(growable: false);

  bool get isEmpty => _items.isEmpty;

  int get totalItems =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double totalAmount(String saleMode) {
    return _items.values.fold(
      0,
      (sum, item) => sum + (item.priceForMode(saleMode) * item.quantity),
    );
  }

  void addProduct(Map<String, dynamic> product) {
    final uuid = product['uuid'].toString();
    final current = _items[uuid];
    if (current != null) {
      _items[uuid] = current.copyWith(quantity: current.quantity + 1);
      notifyListeners();
      return;
    }
    _items[uuid] = CartItem(
      uuid: uuid,
      name: product['nazvanie']?.toString() ?? '',
      stock: (product['kolichestvo'] ?? 0).toDouble(),
      costPrice: (product['tsena_zakupki'] ?? 0).toDouble(),
      retailPrice: (product['tsena_prodazhi'] ?? 0).toDouble(),
      wholesalePrice: (product['tsena_optom'] ?? 0).toDouble(),
      quantity: 1,
    );
    notifyListeners();
  }

  void increase(String uuid) {
    final current = _items[uuid];
    if (current == null) {
      return;
    }
    _items[uuid] = current.copyWith(quantity: current.quantity + 1);
    notifyListeners();
  }

  void decrease(String uuid) {
    final current = _items[uuid];
    if (current == null) {
      return;
    }
    if (current.quantity <= 1) {
      _items.remove(uuid);
    } else {
      _items[uuid] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  void updateItem({
    required String uuid,
    required int quantity,
    required double price,
    required String saleMode,
  }) {
    final current = _items[uuid];
    if (current == null) return;
    if (quantity <= 0) {
      _items.remove(uuid);
    } else {
      _items[uuid] = saleMode == 'wholesale'
          ? current.copyWith(quantity: quantity, wholesalePrice: price)
          : current.copyWith(quantity: quantity, retailPrice: price);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  Map<String, dynamic> toCheckoutPayload({
    required String saleMode,
    required String paymentMethod,
  }) {
    final total = totalAmount(saleMode);
    return {
      'sale_mode': saleMode,
      'payment_method': paymentMethod,
      'cash_amount': paymentMethod == 'cash' ? total : 0,
      'card_amount': paymentMethod == 'card' ? total : 0,
      'debt_amount': paymentMethod == 'debt' ? total : 0,
      'bonus_amount': paymentMethod == 'bonus' ? total : 0,
      'paid_amount': total,
      'change_amount': 0,
      'client_debt': '',
      'items': items
          .map(
            (item) => {
              'product_uuid': item.uuid,
              'product_name': item.name,
              'quantity': item.quantity,
              'stock': item.stock,
              'cost_price': item.costPrice,
              'retail_price': item.retailPrice,
              'wholesale_price': item.wholesalePrice,
            },
          )
          .toList(),
    };
  }
}
