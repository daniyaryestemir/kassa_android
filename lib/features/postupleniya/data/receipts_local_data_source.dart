import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'receipt_models.dart';

class ReceiptsLocalDataSource {
  ReceiptsLocalDataSource({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<List<ReceiptSummaryModel>> getReceipts({String query = ''}) async {
    final db = await _database.database;
    final normalizedQuery = query.trim().toLowerCase();

    final rows = await db.query(
      'receipts',
      where: normalizedQuery.isEmpty
          ? 'is_deleted = 0'
          : '''
              is_deleted = 0 AND (
                lower(kontragent) LIKE ? OR
                lower(uuid) LIKE ?
              )
            ''',
      whereArgs: normalizedQuery.isEmpty
          ? null
          : ['%$normalizedQuery%', '%$normalizedQuery%'],
      orderBy: 'data DESC',
    );

    return rows.map(ReceiptSummaryModel.fromDb).toList(growable: false);
  }

  Future<List<String>> getSuppliers() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT kontragent
      FROM receipts
      WHERE is_deleted = 0 AND trim(kontragent) <> ''
      ORDER BY kontragent COLLATE NOCASE ASC
    ''');

    return rows
        .map((row) => row['kontragent']?.toString().trim() ?? '')
        .where((supplier) => supplier.isNotEmpty)
        .toList(growable: false);
  }

  Future<ReceiptDetailModel?> getReceiptDetail(String uuid) async {
    final db = await _database.database;
    final receiptRows = await db.query(
      'receipts',
      where: 'uuid = ? AND is_deleted = 0',
      whereArgs: [uuid],
      limit: 1,
    );

    if (receiptRows.isEmpty) {
      return null;
    }

    final itemRows = await db.query(
      'receipt_items',
      where: 'receipt_uuid = ? AND is_deleted = 0',
      whereArgs: [uuid],
      orderBy: 'nazvanie COLLATE NOCASE ASC',
    );

    return ReceiptDetailModel(
      receipt: ReceiptSummaryModel.fromDb(receiptRows.first),
      items: itemRows.map(ReceiptItemModel.fromDb).toList(growable: false),
    );
  }

  Future<void> replaceReceipts(List<ReceiptSummaryModel> receipts) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.delete('receipts', where: "sync_status = 'synced'");
      for (final receipt in receipts) {
        await txn.insert('receipts', receipt.toDb());
      }
    });
  }

  Future<void> saveLocalReceipt(ReceiptDetailModel detail) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('receipts', detail.receipt.toDb());
      for (final item in detail.items) {
        await txn.insert('receipt_items', item.toDb());
      }
    });
  }

  Future<void> saveReceiptDetail(ReceiptDetailModel detail) async {
    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.insert(
        'receipts',
        detail.receipt.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'receipt_items',
        where: 'receipt_uuid = ?',
        whereArgs: [detail.receipt.uuid],
      );
      for (final item in detail.items) {
        await txn.insert(
          'receipt_items',
          item.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
