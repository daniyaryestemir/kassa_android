class DashboardStatsModel {
  const DashboardStatsModel({
    required this.todaySalesTotal,
    required this.todayProfitTotal,
    required this.monthSalesTotal,
    required this.monthProfitTotal,
    required this.todayCashTotal,
    required this.todayCardTotal,
    required this.todayDebtTotal,
    required this.todayBonusTotal,
  });

  final double todaySalesTotal;
  final double todayProfitTotal;
  final double monthSalesTotal;
  final double monthProfitTotal;
  final double todayCashTotal;
  final double todayCardTotal;
  final double todayDebtTotal;
  final double todayBonusTotal;

  factory DashboardStatsModel.fromMap(Map<String, dynamic> map) {
    return DashboardStatsModel(
      todaySalesTotal: ((map['today_sales_total'] ?? 0) as num).toDouble(),
      todayProfitTotal: ((map['today_profit_total'] ?? 0) as num).toDouble(),
      monthSalesTotal: ((map['month_sales_total'] ?? 0) as num).toDouble(),
      monthProfitTotal: ((map['month_profit_total'] ?? 0) as num).toDouble(),
      todayCashTotal: ((map['today_cash_total'] ?? 0) as num).toDouble(),
      todayCardTotal: ((map['today_card_total'] ?? 0) as num).toDouble(),
      todayDebtTotal: ((map['today_debt_total'] ?? 0) as num).toDouble(),
      todayBonusTotal: ((map['today_bonus_total'] ?? 0) as num).toDouble(),
    );
  }
}

class DashboardReceiptModel {
  const DashboardReceiptModel({
    required this.uuid,
    required this.kontragent,
    required this.date,
    required this.purchaseSum,
    required this.retailSum,
  });

  final String uuid;
  final String kontragent;
  final String date;
  final double purchaseSum;
  final double retailSum;

  factory DashboardReceiptModel.fromMap(Map<String, dynamic> map) {
    return DashboardReceiptModel(
      uuid: map['uuid']?.toString() ?? '',
      kontragent: map['kontragent']?.toString() ?? '',
      date: map['data']?.toString() ?? '',
      purchaseSum: ((map['summa_postupleni'] ?? 0) as num).toDouble(),
      retailSum: ((map['summa_prodazhi'] ?? 0) as num).toDouble(),
    );
  }
}

class DashboardProductModel {
  const DashboardProductModel({
    required this.uuid,
    required this.name,
    required this.stock,
    required this.retailPrice,
    required this.costPrice,
  });

  final String uuid;
  final String name;
  final double stock;
  final double retailPrice;
  final double costPrice;

  factory DashboardProductModel.fromMap(Map<String, dynamic> map) {
    return DashboardProductModel(
      uuid: map['uuid']?.toString() ?? '',
      name: map['nazvanie']?.toString() ?? '',
      stock: ((map['kolichestvo'] ?? 0) as num).toDouble(),
      retailPrice: ((map['tsena_prodazhi'] ?? 0) as num).toDouble(),
      costPrice: ((map['tsena_zakupki'] ?? 0) as num).toDouble(),
    );
  }
}

class DashboardDataModel {
  const DashboardDataModel({
    required this.stats,
    required this.recentReceipts,
    required this.topProducts,
    required this.updatedAt,
  });

  final DashboardStatsModel stats;
  final List<DashboardReceiptModel> recentReceipts;
  final List<DashboardProductModel> topProducts;
  final String updatedAt;
}
