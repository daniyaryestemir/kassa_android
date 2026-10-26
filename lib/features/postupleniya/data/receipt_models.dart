class ReceiptSummaryModel {
  const ReceiptSummaryModel({
    required this.uuid,
    required this.kontragent,
    required this.date,
    required this.purchaseSum,
    required this.retailSum,
    required this.wholesaleSum,
    required this.lastModified,
    required this.syncStatus,
    required this.isDeleted,
  });

  final String uuid;
  final String kontragent;
  final String date;
  final double purchaseSum;
  final double retailSum;
  final double wholesaleSum;
  final String lastModified;
  final String syncStatus;
  final bool isDeleted;

  factory ReceiptSummaryModel.fromApi(Map<String, dynamic> json) {
    return ReceiptSummaryModel(
      uuid: json['uuid']?.toString() ?? '',
      kontragent: json['kontragent']?.toString() ?? '',
      date: json['data']?.toString() ?? '',
      purchaseSum: ((json['summa_postupleni'] ?? 0) as num).toDouble(),
      retailSum: ((json['summa_prodazhi'] ?? 0) as num).toDouble(),
      wholesaleSum: ((json['summa_optom'] ?? 0) as num).toDouble(),
      lastModified: json['last_modified']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
    );
  }

  factory ReceiptSummaryModel.fromDb(Map<String, Object?> row) {
    return ReceiptSummaryModel(
      uuid: row['uuid']?.toString() ?? '',
      kontragent: row['kontragent']?.toString() ?? '',
      date: row['data']?.toString() ?? '',
      purchaseSum: ((row['summa_postupleni'] ?? 0) as num).toDouble(),
      retailSum: ((row['summa_prodazhi'] ?? 0) as num).toDouble(),
      wholesaleSum: ((row['summa_optom'] ?? 0) as num).toDouble(),
      lastModified: row['last_modified']?.toString() ?? '',
      syncStatus: row['sync_status']?.toString() ?? 'synced',
      isDeleted: ((row['is_deleted'] ?? 0) as num).toInt() == 1,
    );
  }

  Map<String, Object?> toDb() {
    return {
      'uuid': uuid,
      'last_modified': lastModified,
      'sync_status': syncStatus,
      'is_deleted': isDeleted ? 1 : 0,
      'kontragent': kontragent,
      'data': date,
      'summa_postupleni': purchaseSum,
      'summa_prodazhi': retailSum,
      'summa_optom': wholesaleSum,
    };
  }
}

class ReceiptItemModel {
  const ReceiptItemModel({
    required this.uuid,
    required this.receiptUuid,
    required this.name,
    required this.quantity,
    required this.costPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.purchaseSum,
    required this.retailTotalSum,
    required this.lastModified,
    required this.syncStatus,
    required this.isDeleted,
  });

  final String uuid;
  final String receiptUuid;
  final String name;
  final double quantity;
  final double costPrice;
  final double retailPrice;
  final double wholesalePrice;
  final double purchaseSum;
  final double retailTotalSum;
  final String lastModified;
  final String syncStatus;
  final bool isDeleted;

  factory ReceiptItemModel.fromApi(
    Map<String, dynamic> json, {
    required String receiptUuid,
    required int index,
  }) {
    return ReceiptItemModel(
      uuid: json['uuid']?.toString() ?? '$receiptUuid-item-$index',
      receiptUuid: receiptUuid,
      name: json['nazvanie']?.toString() ?? '',
      quantity: ((json['kolichestvo'] ?? 0) as num).toDouble(),
      costPrice: ((json['tsena_zakupki'] ?? 0) as num).toDouble(),
      retailPrice: ((json['tsena_prodazhi'] ?? 0) as num).toDouble(),
      wholesalePrice: ((json['tsena_optom'] ?? 0) as num).toDouble(),
      purchaseSum: ((json['summa_zakupki'] ?? 0) as num).toDouble(),
      retailTotalSum: ((json['summa_prodazhi_itogo'] ?? 0) as num).toDouble(),
      lastModified: json['last_modified']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
    );
  }

  factory ReceiptItemModel.fromDb(Map<String, Object?> row) {
    return ReceiptItemModel(
      uuid: row['uuid']?.toString() ?? '',
      receiptUuid: row['receipt_uuid']?.toString() ?? '',
      name: row['nazvanie']?.toString() ?? '',
      quantity: ((row['kolichestvo'] ?? 0) as num).toDouble(),
      costPrice: ((row['tsena_zakupki'] ?? 0) as num).toDouble(),
      retailPrice: ((row['tsena_prodazhi'] ?? 0) as num).toDouble(),
      wholesalePrice: ((row['tsena_optom'] ?? 0) as num).toDouble(),
      purchaseSum: ((row['summa_zakupki'] ?? 0) as num).toDouble(),
      retailTotalSum: ((row['summa_prodazhi_itogo'] ?? 0) as num).toDouble(),
      lastModified: row['last_modified']?.toString() ?? '',
      syncStatus: row['sync_status']?.toString() ?? 'synced',
      isDeleted: ((row['is_deleted'] ?? 0) as num).toInt() == 1,
    );
  }

  Map<String, Object?> toDb() {
    return {
      'uuid': uuid,
      'receipt_uuid': receiptUuid,
      'last_modified': lastModified,
      'sync_status': syncStatus,
      'is_deleted': isDeleted ? 1 : 0,
      'nazvanie': name,
      'kolichestvo': quantity,
      'tsena_zakupki': costPrice,
      'tsena_prodazhi': retailPrice,
      'tsena_optom': wholesalePrice,
      'summa_zakupki': purchaseSum,
      'summa_prodazhi_itogo': retailTotalSum,
    };
  }
}

class ReceiptDetailModel {
  const ReceiptDetailModel({
    required this.receipt,
    required this.items,
  });

  final ReceiptSummaryModel receipt;
  final List<ReceiptItemModel> items;
}
