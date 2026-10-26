import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'dashboard_models.dart';

class DashboardLocalDataSource {
  DashboardLocalDataSource({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<DashboardDataModel> buildDashboard() async {
    final db = await _database.database;
    final todayPrefix = DateTime.now().toIso8601String().split('T').first;

    final monthPrefix = todayPrefix.substring(0, 7);
    final checkRows = await db.query(
      'local_checks',
      columns: ['data', 'summa', 'oplata', 'sale_mode', 'items_json'],
      where: 'is_deleted = 0 AND data LIKE ?',
      whereArgs: ['$monthPrefix%'],
    );

    var todaySales = 0.0;
    var todayProfit = 0.0;
    var monthSales = 0.0;
    var monthProfit = 0.0;
    var todayCash = 0.0;
    var todayCard = 0.0;
    var todayDebt = 0.0;
    var todayBonus = 0.0;
    for (final row in checkRows) {
      final sale = ((row['summa'] ?? 0) as num).toDouble();
      final profit = _profitFromItems(
        row['items_json']?.toString() ?? '[]',
        row['sale_mode']?.toString() ?? 'retail',
      );
      final isToday = row['data']?.toString().startsWith(todayPrefix) ?? false;
      monthSales += sale;
      monthProfit += profit;
      if (!isToday) continue;
      todaySales += sale;
      todayProfit += profit;
      switch (row['oplata']?.toString()) {
        case 'cash':
          todayCash += sale;
        case 'card':
          todayCard += sale;
        case 'debt':
          todayDebt += sale;
        case 'bonus':
          todayBonus += sale;
      }
    }

    return DashboardDataModel(
      stats: DashboardStatsModel(
        todaySalesTotal: todaySales,
        todayProfitTotal: todayProfit,
        monthSalesTotal: monthSales,
        monthProfitTotal: monthProfit,
        todayCashTotal: todayCash,
        todayCardTotal: todayCard,
        todayDebtTotal: todayDebt,
        todayBonusTotal: todayBonus,
      ),
      recentReceipts: const [],
      topProducts: const [],
      updatedAt: '',
    );
  }

  double _profitFromItems(String rawItems, String saleMode) {
    try {
      final decoded = jsonDecode(rawItems);
      if (decoded is! List) return 0;
      return decoded.whereType<Map>().fold<double>(0, (sum, item) {
        final quantity = ((item['quantity'] ?? 0) as num).toDouble();
        final cost = ((item['cost_price'] ?? 0) as num).toDouble();
        final price = ((saleMode == 'wholesale'
                ? item['wholesale_price']
                : item['retail_price']) ??
            0) as num;
        return sum + (price.toDouble() - cost) * quantity;
      });
    } catch (_) {
      return 0;
    }
  }

  Future<void> saveRemoteDashboard(Map<String, dynamic> dashboard) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();
    await db.insert(
      'dashboard_cache',
      {
        'scope': 'main',
        'payload_json': jsonEncode({
          'stats': dashboard['stats'],
          'recent_receipts': dashboard['recent_receipts'],
          'top_products': dashboard['top_products'],
          'updated_at': now,
        }),
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

}
