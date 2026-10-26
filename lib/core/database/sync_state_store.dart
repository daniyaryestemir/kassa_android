import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class SyncStateStore {
  SyncStateStore({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<String?> getSyncedAt(String scope) async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_state',
      columns: ['synced_at'],
      where: 'scope = ?',
      whereArgs: [scope],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['synced_at']?.toString();
  }

  Future<void> setSyncedAt(String scope, String syncedAt) async {
    final db = await _database.database;
    await db.insert(
      'sync_state',
      {'scope': scope, 'synced_at': syncedAt},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
