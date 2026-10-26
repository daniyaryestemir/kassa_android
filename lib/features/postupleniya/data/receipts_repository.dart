import '../../../core/database/sync_state_store.dart';
import '../../nomenklatura/data/product_model.dart';
import '../../nomenklatura/data/products_local_data_source.dart';
import 'postupleniya_api.dart';
import 'receipt_models.dart';
import 'receipts_local_data_source.dart';

class ReceiptsRepository {
  ReceiptsRepository({
    PostupleniyaApi? api,
    ReceiptsLocalDataSource? localDataSource,
    ProductsLocalDataSource? productsLocalDataSource,
    SyncStateStore? syncStateStore,
  })  : _api = api ?? PostupleniyaApi(),
        _localDataSource = localDataSource ?? ReceiptsLocalDataSource(),
        _productsLocalDataSource =
            productsLocalDataSource ?? ProductsLocalDataSource(),
        _syncStateStore = syncStateStore ?? SyncStateStore();

  final PostupleniyaApi _api;
  final ReceiptsLocalDataSource _localDataSource;
  final ProductsLocalDataSource _productsLocalDataSource;
  final SyncStateStore _syncStateStore;

  Future<List<ReceiptSummaryModel>> getLocalReceipts({String query = ''}) {
    return _localDataSource.getReceipts(query: query);
  }

  Future<ReceiptDetailModel?> getLocalReceiptDetail(String uuid) {
    return _localDataSource.getReceiptDetail(uuid);
  }

  Future<List<String>> getLocalSuppliers() {
    return _localDataSource.getSuppliers();
  }

  Future<int> syncReceipts() async {
    final response = await _api.loadReceipts();
    final receipts = (response['receipts'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReceiptSummaryModel.fromApi)
        .toList(growable: false);

    await _localDataSource.replaceReceipts(receipts);
    await _syncStateStore.setSyncedAt(
      'receipts',
      DateTime.now().toIso8601String(),
    );
    return receipts.length;
  }

  Future<ReceiptDetailModel> syncReceiptDetail(String uuid) async {
    final response = await _api.loadReceiptDetail(uuid);
    final receiptJson =
        response['receipt'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final summary = ReceiptSummaryModel.fromApi(receiptJson);
    final items = (receiptJson['items'] as List<dynamic>? ?? <dynamic>[])
        .asMap()
        .entries
        .where((entry) => entry.value is Map<String, dynamic>)
        .map(
          (entry) => ReceiptItemModel.fromApi(
            entry.value as Map<String, dynamic>,
            receiptUuid: summary.uuid,
            index: entry.key,
          ),
        )
        .toList(growable: false);

    final detail = ReceiptDetailModel(receipt: summary, items: items);
    await _localDataSource.saveReceiptDetail(detail);
    return detail;
  }

  Future<void> saveNewReceipt({
    required String uuid,
    required String supplier,
    required List<ReceiptItemModel> items,
    required List<ProductModel> products,
  }) async {
    final now = DateTime.now().toIso8601String();
    final purchaseSum =
        items.fold<double>(0, (sum, item) => sum + item.purchaseSum);
    final retailSum = items.fold<double>(
      0,
      (sum, item) => sum + item.retailTotalSum,
    );
    final wholesaleSum = items.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.wholesalePrice,
    );

    await _localDataSource.saveLocalReceipt(
      ReceiptDetailModel(
        receipt: ReceiptSummaryModel(
          uuid: uuid,
          kontragent: supplier,
          date: now.substring(0, 10),
          purchaseSum: purchaseSum,
          retailSum: retailSum,
          wholesaleSum: wholesaleSum,
          lastModified: now,
          syncStatus: 'pending',
          isDeleted: false,
        ),
        items: items,
      ),
    );

    await _productsLocalDataSource.applyReceiptItems([
      for (var index = 0; index < items.length; index++)
        {
          'uuid': products[index].uuid,
          'stock': products[index].stock + items[index].quantity,
          'costPrice': items[index].costPrice,
          'retailPrice': items[index].retailPrice,
          'wholesalePrice': items[index].wholesalePrice,
        },
    ]);
  }
}
