import 'dart:convert';

import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../database/sync_state_store.dart';
import 'mysql_client.dart';
import 'mysql_tables.dart';
import '../sync/sync_progress.dart';

class MySqlSyncResult {
  const MySqlSyncResult({
    required this.tablesSynced,
    required this.productsSynced,
    required this.receiptsSynced,
    required this.checksSynced,
  });

  final int tablesSynced;
  final int productsSynced;
  final int receiptsSynced;
  final int checksSynced;
}

/// Mirrors the same MySQL tables and conflict rule used by the Windows app:
/// local pending rows win; otherwise the newest server row is stored locally.
class MySqlSyncService {
  MySqlSyncService({MySqlClient? client, AppDatabase? database})
      : _client = client ?? MySqlClient(),
        _database = database ?? AppDatabase.instance;

  final MySqlClient _client;
  final AppDatabase _database;
  final _uuid = const Uuid();

  Future<MySqlSyncResult> syncAll({
    void Function(int step, int totalSteps, String message)? onProgress,
    bool Function()? isCancellationRequested,
  }) async {
    void checkCancelled() {
      if (isCancellationRequested?.call() ?? false) {
        throw const SyncCancelledException();
      }
    }

    final totalSteps = mysqlTableFields.length + 4;
    void report(int step, String message) => onProgress?.call(
          step,
          totalSteps,
          message,
        );

    final db = await _database.database;
    return _client.withConnection((connection) async {
      report(0, 'Проверка таблиц на сервере');
      checkCancelled();
      final serverTables = await _serverTables(connection);
      final missing = mysqlTableFields.keys
          .where((table) => !serverTables.contains(table))
          .toList();
      if (missing.isNotEmpty) {
        throw StateError('В MySQL отсутствуют таблицы: ${missing.join(', ')}');
      }

      report(1, 'Подготовка локальных изменений');
      await _stageAppChanges(db);
      var changed = 0;
      for (final entry in mysqlTableFields.entries.indexed) {
        checkCancelled();
        final index = entry.$1;
        final table = entry.$2;
        report(index + 2, 'Синхронизация: ${table.key}');
        changed +=
            await _syncMirrorTable(db, connection, table.key, table.value);
      }
      await db.transaction((transaction) async {
        await transaction.update('products', {'sync_status': 'synced'},
            where: "sync_status <> 'synced'");
        await transaction.update('receipts', {'sync_status': 'synced'},
            where: "sync_status <> 'synced'");
        await transaction.update('receipt_items', {'sync_status': 'synced'},
            where: "sync_status <> 'synced'");
      });
      checkCancelled();
      report(totalSteps - 2, 'Обновление товаров');
      final products = await _applyProducts(db);
      checkCancelled();
      report(totalSteps - 1, 'Обновление поступлений');
      final receipts = await _applyReceipts(db);
      checkCancelled();
      report(totalSteps, 'Отправка чеков кассы');
      final checks = await _pushChecks(db, connection);
      final now = DateTime.now().toIso8601String();
      final store = SyncStateStore(database: _database);
      await Future.wait([
        store.setSyncedAt('products', now),
        store.setSyncedAt('receipts', now),
        store.setSyncedAt('kassa_checks', now),
        store.setSyncedAt('dashboard', now),
      ]);
      return MySqlSyncResult(
        tablesSynced: changed,
        productsSynced: products,
        receiptsSynced: receipts,
        checksSynced: checks,
      );
    });
  }

  Future<Set<String>> _serverTables(MySqlConnection connection) async {
    final result = await connection.query('SHOW TABLES');
    return result.map((row) => row[0].toString()).toSet();
  }

  Future<void> _stageAppChanges(Database db) async {
    final now = DateTime.now().toIso8601String();
    final products =
        await db.query('products', where: "sync_status <> 'synced'");
    for (final product in products) {
      await db.insert(
          mysqlMirrorTable('tovary'),
          {
            'uuid': product['uuid'],
            'last_modified': product['last_modified'] ?? now,
            'is_deleted': product['is_deleted'] ?? 0,
            'nazvanie': product['nazvanie'],
            'kolichestvo': product['kolichestvo'],
            'tsena_zakupki': product['tsena_zakupki'],
            'tsena_prodazhi': product['tsena_prodazhi'],
            'tsena_optom': product['tsena_optom'],
            'category': product['category'] ?? '',
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final rawBarcodes = product['barcodes_json']?.toString() ?? '[]';
      final decoded = jsonDecode(rawBarcodes);
      final barcodes = decoded is List
          ? decoded.map((value) => '$value'.trim())
          : const Iterable<String>.empty();
      for (final barcode in barcodes.where((value) => value.isNotEmpty)) {
        await db.insert(mysqlMirrorTable('dop_shtrih_kody'), {
          'uuid': _uuid.v4(),
          'tovar_uuid': product['uuid'],
          'shtrih_kod': barcode,
          'last_modified': product['last_modified'] ?? now,
          'is_deleted': 0,
          'sync_status': 'pending',
        });
      }
    }
    final receipts =
        await db.query('receipts', where: "sync_status <> 'synced'");
    for (final receipt in receipts) {
      await db.insert(
          mysqlMirrorTable('postupleniya'),
          {
            'uuid': receipt['uuid'],
            'kontragent': receipt['kontragent'],
            'data': receipt['data'],
            'summa_postupleni': receipt['summa_postupleni'],
            'summa_prodazhi': receipt['summa_prodazhi'],
            'summa_optom': receipt['summa_optom'],
            'last_modified': receipt['last_modified'] ?? now,
            'is_deleted': receipt['is_deleted'] ?? 0,
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final items =
        await db.query('receipt_items', where: "sync_status <> 'synced'");
    for (final item in items) {
      await db.insert(
          mysqlMirrorTable('spisok_postupleniy'),
          {
            'uuid': item['uuid'],
            'postuplenie_uuid': item['receipt_uuid'],
            'nazvanie': item['nazvanie'],
            'kolichestvo': item['kolichestvo'],
            'tsena_zakupki': item['tsena_zakupki'],
            'tsena_prodazhi': item['tsena_prodazhi'],
            'tsena_optom': item['tsena_optom'],
            'last_modified': item['last_modified'] ?? now,
            'is_deleted': item['is_deleted'] ?? 0,
            'sync_status': 'pending',
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<int> _syncMirrorTable(Database db, MySqlConnection connection,
      String table, List<String> fields) async {
    final mirror = mysqlMirrorTable(table);
    final pending = await db.query(mirror, where: "sync_status <> 'synced'");
    for (final row in pending) {
      await _upsert(connection, table, fields, row);
    }

    final result = await connection.query(
      'SELECT ${fields.map(_quote).join(', ')} FROM ${_quote(table)}',
    );
    var changed = 0;
    await db.transaction((transaction) async {
      for (final sourceRow in result) {
        final row = <String, Object?>{};
        for (var index = 0; index < fields.length; index++) {
          row[fields[index]] = _sqliteValue(sourceRow[index]);
        }
        final uuid = row['uuid']?.toString() ?? '';
        if (uuid.isEmpty) continue;
        final current = await transaction.query(
          mirror,
          columns: ['sync_status'],
          where: 'uuid = ?',
          whereArgs: [uuid],
          limit: 1,
        );
        if (current.isNotEmpty && current.first['sync_status'] != 'synced') {
          continue;
        }
        row['sync_status'] = 'synced';
        await transaction.insert(
          mirror,
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        changed++;
      }
    });
    return changed;
  }

  Future<void> _upsert(MySqlConnection connection, String table,
      List<String> fields, Map<String, Object?> row) async {
    final columns = fields.map(_quote).join(', ');
    final placeholders = List.filled(fields.length, '?').join(', ');
    final assignments = [
      for (final field in fields.where((field) => field != 'uuid'))
        '${_quote(field)} = VALUES(${_quote(field)})',
      "`sync_status` = 'synced'",
    ].join(', ');
    final values = [for (final field in fields) row[field]];
    await connection.query(
      'INSERT INTO ${_quote(table)} ($columns, `sync_status`) '
      "VALUES ($placeholders, 'synced') ON DUPLICATE KEY UPDATE $assignments",
      values,
    );
  }

  Future<int> _applyProducts(Database db) async {
    final products = await db.query(mysqlMirrorTable('tovary'));
    final barcodeRows = await db.query(
      mysqlMirrorTable('dop_shtrih_kody'),
      where: 'is_deleted = 0',
    );
    final barcodes = <String, List<String>>{};
    for (final row in barcodeRows) {
      final productUuid = row['tovar_uuid']?.toString() ?? '';
      final barcode = row['shtrih_kod']?.toString().trim() ?? '';
      if (productUuid.isNotEmpty && barcode.isNotEmpty) {
        (barcodes[productUuid] ??= []).add(barcode);
      }
    }
    await db.transaction((transaction) async {
      await transaction.delete('products', where: "sync_status = 'synced'");
      for (final row in products) {
        final uuid = row['uuid']?.toString() ?? '';
        if (uuid.isEmpty) continue;
        final productBarcodes = barcodes[uuid] ?? const <String>[];
        await transaction.insert(
            'products',
            {
              'uuid': uuid,
              'last_modified': row['last_modified']?.toString() ?? '',
              'sync_status': 'synced',
              'is_deleted': _asInt(row['is_deleted']),
              'nazvanie': row['nazvanie']?.toString() ?? '',
              'kolichestvo': _asDouble(row['kolichestvo']),
              'tsena_zakupki': _asDouble(row['tsena_zakupki']),
              'tsena_prodazhi': _asDouble(row['tsena_prodazhi']),
              'tsena_optom': _asDouble(row['tsena_optom']),
              'category': row['category']?.toString() ?? '',
              'primary_barcode':
                  productBarcodes.isEmpty ? '' : productBarcodes.first,
              'barcodes_json': jsonEncode(productBarcodes),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return products.length;
  }

  Future<int> _applyReceipts(Database db) async {
    final receipts = await db.query(mysqlMirrorTable('postupleniya'));
    final items = await db.query(mysqlMirrorTable('spisok_postupleniy'));
    await db.transaction((transaction) async {
      await transaction.delete('receipt_items',
          where: "sync_status = 'synced'");
      await transaction.delete('receipts', where: "sync_status = 'synced'");
      for (final receipt in receipts) {
        final uuid = receipt['uuid']?.toString() ?? '';
        if (uuid.isEmpty) continue;
        await transaction.insert('receipts', {
          'uuid': uuid,
          'last_modified': receipt['last_modified']?.toString() ?? '',
          'sync_status': 'synced',
          'is_deleted': _asInt(receipt['is_deleted']),
          'kontragent': receipt['kontragent']?.toString() ?? '',
          'data': receipt['data']?.toString() ?? '',
          'summa_postupleni': _asDouble(receipt['summa_postupleni']),
          'summa_prodazhi': _asDouble(receipt['summa_prodazhi']),
          'summa_optom': _asDouble(receipt['summa_optom']),
        });
      }
      for (final item in items) {
        final uuid = item['uuid']?.toString() ?? '';
        if (uuid.isEmpty) continue;
        final quantity = _asDouble(item['kolichestvo']);
        final cost = _asDouble(item['tsena_zakupki']);
        final retail = _asDouble(item['tsena_prodazhi']);
        await transaction.insert('receipt_items', {
          'uuid': uuid,
          'receipt_uuid': item['postuplenie_uuid']?.toString() ?? '',
          'last_modified': item['last_modified']?.toString() ?? '',
          'sync_status': 'synced',
          'is_deleted': _asInt(item['is_deleted']),
          'nazvanie': item['nazvanie']?.toString() ?? '',
          'kolichestvo': quantity,
          'tsena_zakupki': cost,
          'tsena_prodazhi': retail,
          'tsena_optom': _asDouble(item['tsena_optom']),
          'summa_zakupki': quantity * cost,
          'summa_prodazhi_itogo': quantity * retail,
        });
      }
    });
    return receipts.length;
  }

  Future<int> _pushChecks(Database db, MySqlConnection connection) async {
    final checks =
        await db.query('local_checks', where: "sync_status <> 'synced'");
    var synced = 0;
    for (final check in checks) {
      final payload = jsonDecode(check['payload_json']?.toString() ?? '{}');
      if (payload is! Map<String, dynamic>) continue;
      final items = payload['items'] ?? const [];
      final values = <String, Object?>{
        'uuid': check['uuid'],
        'data': check['data'],
        'tovary': jsonEncode(items),
        'summa': check['summa'],
        'oplata': check['oplata'],
        'skidka': 0,
        'total_cost': 0,
        'total_gross_profit': 0,
        'nalichnye': payload['cash_amount'] ?? 0,
        'karta': payload['card_amount'] ?? 0,
        'dolg': payload['debt_amount'] ?? 0,
        'klient_dolg': payload['client_debt'] ?? '',
        'spent_bonuses': payload['bonus_amount'] ?? 0,
        'vnesennaya_summa': payload['paid_amount'] ?? 0,
        'sdacha': payload['change_amount'] ?? 0,
        'klient_id': null,
        'last_modified': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      };
      await _upsert(connection, 'cheki', mysqlTableFields['cheki']!, values);
      await db.update(
          'local_checks',
          {
            'sync_status': 'synced',
            'last_attempt_at': DateTime.now().toIso8601String(),
            'last_error': '',
          },
          where: 'uuid = ?',
          whereArgs: [check['uuid']]);
      synced++;
    }
    return synced;
  }

  static String _quote(String value) => '`${value.replaceAll('`', '``')}`';
  static Object? _sqliteValue(Object? value) {
    if (value is DateTime) return value.toIso8601String();
    // mysql1 may return TEXT/LONGTEXT fields as Blob. SQLite cannot bind the
    // driver's Blob object, while the mirrored fields are stored as text.
    if (value is Blob) return value.toString();
    return value;
  }

  static int _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
