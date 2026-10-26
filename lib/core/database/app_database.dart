import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../mysql/mysql_tables.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'kassa_android.db');

    _database = await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createReceiptsTables(db);
        }
        if (oldVersion < 3) {
          await _createSyncTables(db);
        }
        if (oldVersion < 4) {
          await _createDashboardCacheTable(db);
        }
        if (oldVersion < 5) {
          await _upgradeLocalChecksQueue(db);
        }
        if (oldVersion < 6) {
          await _createMysqlMirrorTables(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE products (
        uuid TEXT PRIMARY KEY,
        last_modified TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        nazvanie TEXT NOT NULL,
        kolichestvo REAL NOT NULL DEFAULT 0,
        tsena_zakupki REAL NOT NULL DEFAULT 0,
        tsena_prodazhi REAL NOT NULL DEFAULT 0,
        tsena_optom REAL NOT NULL DEFAULT 0,
        category TEXT,
        primary_barcode TEXT,
        barcodes_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_products_name ON products(nazvanie)',
    );
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category)',
    );

    await _createReceiptsTables(db);
    await _createSyncTables(db);
    await _createMysqlMirrorTables(db);
  }

  Future<void> _createReceiptsTables(Database db) async {
    await db.execute('''
      CREATE TABLE receipts (
        uuid TEXT PRIMARY KEY,
        last_modified TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        kontragent TEXT NOT NULL,
        data TEXT NOT NULL,
        summa_postupleni REAL NOT NULL DEFAULT 0,
        summa_prodazhi REAL NOT NULL DEFAULT 0,
        summa_optom REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE receipt_items (
        uuid TEXT PRIMARY KEY,
        receipt_uuid TEXT NOT NULL,
        last_modified TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        nazvanie TEXT NOT NULL,
        kolichestvo REAL NOT NULL DEFAULT 0,
        tsena_zakupki REAL NOT NULL DEFAULT 0,
        tsena_prodazhi REAL NOT NULL DEFAULT 0,
        tsena_optom REAL NOT NULL DEFAULT 0,
        summa_zakupki REAL NOT NULL DEFAULT 0,
        summa_prodazhi_itogo REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (receipt_uuid) REFERENCES receipts(uuid) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_receipts_date ON receipts(data)');
    await db.execute(
      'CREATE INDEX idx_receipts_kontragent ON receipts(kontragent)',
    );
    await db.execute(
      'CREATE INDEX idx_receipt_items_receipt_uuid ON receipt_items(receipt_uuid)',
    );
  }

  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE sync_state (
        scope TEXT PRIMARY KEY,
        synced_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE local_checks (
        uuid TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        items_json TEXT NOT NULL,
        summa REAL NOT NULL DEFAULT 0,
        oplata TEXT NOT NULL,
        sale_mode TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_modified TEXT,
        last_attempt_at TEXT,
        last_error TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_local_checks_date ON local_checks(data DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_local_checks_sync_status ON local_checks(sync_status)',
    );

    await _createDashboardCacheTable(db);
  }

  Future<void> _createDashboardCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dashboard_cache (
        scope TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeLocalChecksQueue(Database db) async {
    await db
        .execute('ALTER TABLE local_checks ADD COLUMN last_attempt_at TEXT');
    await db.execute('ALTER TABLE local_checks ADD COLUMN last_error TEXT');
    await db.execute(
      'ALTER TABLE local_checks ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _createMysqlMirrorTables(Database db) async {
    for (final entry in mysqlTableFields.entries) {
      final columns = entry.value.map((field) {
        if (field == 'uuid') return 'uuid TEXT PRIMARY KEY';
        if (field == 'is_deleted') {
          return 'is_deleted INTEGER NOT NULL DEFAULT 0';
        }
        return '$field TEXT';
      }).join(', ');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${mysqlMirrorTable(entry.key)} (
          $columns,
          sync_status TEXT NOT NULL DEFAULT 'synced'
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${mysqlMirrorTable(entry.key)}_sync ON ${mysqlMirrorTable(entry.key)}(sync_status)',
      );
    }
  }
}
