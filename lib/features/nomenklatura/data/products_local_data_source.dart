import '../../../core/database/app_database.dart';
import 'package:sqflite/sqflite.dart';
import 'product_model.dart';

class ProductsLocalDataSource {
  ProductsLocalDataSource({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<ProductModel>> getProducts({String query = ''}) async {
    final db = await _database.database;
    final normalizedQuery = query.trim();

    final rows = await db.query(
      'products',
      where: normalizedQuery.isEmpty
          ? 'is_deleted = 0'
          : '''
              is_deleted = 0 AND (
                lower(nazvanie) LIKE ? OR
                lower(coalesce(category, '')) LIKE ? OR
                lower(coalesce(primary_barcode, '')) LIKE ? OR
                lower(coalesce(barcodes_json, '')) LIKE ?
              )
            ''',
      whereArgs: normalizedQuery.isEmpty
          ? null
          : List.filled(4, '%${normalizedQuery.toLowerCase()}%'),
      orderBy: 'nazvanie COLLATE NOCASE ASC',
    );

    return rows.map(ProductModel.fromDb).toList(growable: false);
  }

  Future<void> replaceProducts(List<ProductModel> products) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.delete('products', where: "sync_status = 'synced'");
      for (final product in products) {
        await txn.insert('products', product.toDb());
      }
    });
  }

  Future<List<String>> getUsedBarcodes() async {
    final db = await _database.database;
    final rows = await db.query(
      'products',
      columns: ['primary_barcode', 'barcodes_json'],
      where: 'is_deleted = 0',
    );

    final barcodes = <String>{};
    for (final row in rows) {
      final product = ProductModel.fromDb({
        'uuid': '',
        'nazvanie': '',
        'primary_barcode': row['primary_barcode'],
        'barcodes_json': row['barcodes_json'],
      });
      if (product.primaryBarcode.isNotEmpty) {
        barcodes.add(product.primaryBarcode);
      }
      barcodes.addAll(product.barcodes);
    }
    return barcodes.toList(growable: false);
  }

  Future<void> saveLocalProduct(ProductModel product) async {
    final db = await _database.database;
    await db.insert(
      'products',
      product.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> applyReceiptItems(List<Map<String, Object?>> items) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final item in items) {
        await txn.update(
          'products',
          {
            'kolichestvo': item['stock'],
            'tsena_zakupki': item['costPrice'],
            'tsena_prodazhi': item['retailPrice'],
            'tsena_optom': item['wholesalePrice'],
            'last_modified': now,
            'sync_status': 'pending',
          },
          where: 'uuid = ?',
          whereArgs: [item['uuid']],
        );
      }
    });
  }
}
