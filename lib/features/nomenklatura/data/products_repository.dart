import '../../../core/database/sync_state_store.dart';
import 'nomenklatura_api.dart';
import 'product_model.dart';
import 'products_local_data_source.dart';

class ProductsRepository {
  ProductsRepository({
    NomenklaturaApi? api,
    ProductsLocalDataSource? localDataSource,
    SyncStateStore? syncStateStore,
  })  : _api = api ?? NomenklaturaApi(),
        _localDataSource = localDataSource ?? ProductsLocalDataSource(),
        _syncStateStore = syncStateStore ?? SyncStateStore();

  final NomenklaturaApi _api;
  final ProductsLocalDataSource _localDataSource;
  final SyncStateStore _syncStateStore;

  Future<List<ProductModel>> getLocalProducts({String query = ''}) {
    return _localDataSource.getProducts(query: query);
  }

  Future<List<String>> getUsedBarcodes() {
    return _localDataSource.getUsedBarcodes();
  }

  Future<void> saveLocalProduct(ProductModel product) {
    return _localDataSource.saveLocalProduct(product);
  }

  Future<int> syncProducts() async {
    final response = await _api.loadProducts();
    final products = (response['products'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromApi)
        .toList(growable: false);

    await _localDataSource.replaceProducts(products);
    await _syncStateStore.setSyncedAt(
      'products',
      DateTime.now().toIso8601String(),
    );
    return products.length;
  }
}
