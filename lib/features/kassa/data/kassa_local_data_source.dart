import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../nomenklatura/data/product_model.dart';
import '../../nomenklatura/data/products_local_data_source.dart';
import 'local_check_models.dart';

class KassaLocalDataSource {
  KassaLocalDataSource({
    AppDatabase? database,
    ProductsLocalDataSource? productsLocalDataSource,
  })  : _database = database ?? AppDatabase.instance,
        _productsLocalDataSource =
            productsLocalDataSource ?? ProductsLocalDataSource();

  final AppDatabase _database;
  final ProductsLocalDataSource _productsLocalDataSource;

  Future<List<ProductModel>> getProducts({String query = ''}) {
    return _productsLocalDataSource.getProducts(query: query);
  }

  Future<List<LocalCheckModel>> getRecentChecks({int limit = 3}) async {
    final db = await _database.database;
    final rows = await db.query(
      'local_checks',
      where: 'is_deleted = 0',
      orderBy: 'data DESC',
      limit: limit,
    );
    return rows.map(LocalCheckModel.fromDb).toList(growable: false);
  }

  Future<List<LocalCheckModel>> getPendingChecks() async {
    final db = await _database.database;
    final rows = await db.query(
      'local_checks',
      where: 'is_deleted = 0 AND sync_status IN (?, ?)',
      whereArgs: ['pending', 'error'],
      orderBy: 'data ASC, retry_count ASC',
    );
    return rows.map(LocalCheckModel.fromDb).toList(growable: false);
  }

  Future<void> saveCheck(LocalCheckModel check) async {
    final db = await _database.database;
    await db.insert(
      'local_checks',
      check.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markCheckSynced(String uuid, String syncedAt) async {
    final db = await _database.database;
    await db.update(
      'local_checks',
      {
        'sync_status': 'synced',
        'last_modified': syncedAt,
        'last_attempt_at': syncedAt,
        'last_error': '',
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> markCheckSyncAttempt(String uuid, String attemptedAt) async {
    final db = await _database.database;
    await db.update(
      'local_checks',
      {
        'last_attempt_at': attemptedAt,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  Future<void> markCheckSyncError(
    String uuid, {
    required String attemptedAt,
    required String errorMessage,
  }) async {
    final db = await _database.database;
    await db.rawUpdate(
      '''
      UPDATE local_checks
      SET sync_status = 'error',
          last_attempt_at = ?,
          last_error = ?,
          retry_count = retry_count + 1
      WHERE uuid = ?
      ''',
      [attemptedAt, errorMessage, uuid],
    );
  }

  Future<void> decreaseStocks(List<Map<String, dynamic>> items) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      for (final item in items) {
        final uuid = item['product_uuid']?.toString() ?? '';
        final quantity = ((item['quantity'] ?? 0) as num).toDouble();
        if (uuid.isEmpty || quantity == 0) {
          continue;
        }

        await txn.rawUpdate(
          '''
          UPDATE products
          SET kolichestvo = kolichestvo - ?
          WHERE uuid = ?
          ''',
          [quantity, uuid],
        );
      }
    });
  }
}
