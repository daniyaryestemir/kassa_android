import 'dart:convert';

class LocalCheckModel {
  const LocalCheckModel({
    required this.uuid,
    required this.date,
    required this.payloadJson,
    required this.itemsJson,
    required this.totalSum,
    required this.paymentMethod,
    required this.saleMode,
    required this.syncStatus,
    required this.lastModified,
    required this.lastAttemptAt,
    required this.lastError,
    required this.retryCount,
    required this.isDeleted,
  });

  final String uuid;
  final String date;
  final String payloadJson;
  final String itemsJson;
  final double totalSum;
  final String paymentMethod;
  final String saleMode;
  final String syncStatus;
  final String lastModified;
  final String lastAttemptAt;
  final String lastError;
  final int retryCount;
  final bool isDeleted;

  bool get isPendingSync => syncStatus == 'pending';

  bool get hasSyncError => syncStatus == 'error';

  List<Map<String, dynamic>> get items {
    final decoded = jsonDecode(itemsJson);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  int get itemsCount => items.fold<int>(
        0,
        (sum, item) => sum + ((item['quantity'] ?? 0) as num).toInt(),
      );

  factory LocalCheckModel.fromDb(Map<String, Object?> row) {
    return LocalCheckModel(
      uuid: row['uuid']?.toString() ?? '',
      date: row['data']?.toString() ?? '',
      payloadJson: row['payload_json']?.toString() ?? '{}',
      itemsJson: row['items_json']?.toString() ?? '[]',
      totalSum: ((row['summa'] ?? 0) as num).toDouble(),
      paymentMethod: row['oplata']?.toString() ?? '',
      saleMode: row['sale_mode']?.toString() ?? '',
      syncStatus: row['sync_status']?.toString() ?? 'pending',
      lastModified: row['last_modified']?.toString() ?? '',
      lastAttemptAt: row['last_attempt_at']?.toString() ?? '',
      lastError: row['last_error']?.toString() ?? '',
      retryCount: ((row['retry_count'] ?? 0) as num).toInt(),
      isDeleted: ((row['is_deleted'] ?? 0) as num).toInt() == 1,
    );
  }

  Map<String, Object?> toDb() {
    return {
      'uuid': uuid,
      'data': date,
      'payload_json': payloadJson,
      'items_json': itemsJson,
      'summa': totalSum,
      'oplata': paymentMethod,
      'sale_mode': saleMode,
      'sync_status': syncStatus,
      'last_modified': lastModified,
      'last_attempt_at': lastAttemptAt,
      'last_error': lastError,
      'retry_count': retryCount,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}
