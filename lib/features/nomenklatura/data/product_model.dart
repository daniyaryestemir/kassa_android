import 'dart:convert';

class ProductModel {
  const ProductModel({
    required this.uuid,
    required this.name,
    required this.stock,
    required this.costPrice,
    required this.retailPrice,
    required this.wholesalePrice,
    required this.category,
    required this.primaryBarcode,
    required this.barcodes,
    required this.lastModified,
    required this.syncStatus,
    required this.isDeleted,
  });

  final String uuid;
  final String name;
  final double stock;
  final double costPrice;
  final double retailPrice;
  final double wholesalePrice;
  final String category;
  final String primaryBarcode;
  final List<String> barcodes;
  final String lastModified;
  final String syncStatus;
  final bool isDeleted;

  bool get isLowStock => stock <= 5;

  factory ProductModel.fromApi(Map<String, dynamic> json) {
    final rawBarcodes = (json['barcodes'] as List<dynamic>? ?? <dynamic>[])
        .map((barcode) => barcode.toString().trim())
        .where((barcode) => barcode.isNotEmpty)
        .toList();

    final primaryBarcode = (json['primary_barcode']?.toString().trim() ?? '');
    final mergedBarcodes = <String>[
      if (primaryBarcode.isNotEmpty) primaryBarcode,
      ...rawBarcodes.where((barcode) => barcode != primaryBarcode),
    ];

    return ProductModel(
      uuid: json['uuid']?.toString() ?? '',
      name: json['nazvanie']?.toString() ?? '',
      stock: ((json['kolichestvo'] ?? 0) as num).toDouble(),
      costPrice: ((json['tsena_zakupki'] ?? 0) as num).toDouble(),
      retailPrice: ((json['tsena_prodazhi'] ?? 0) as num).toDouble(),
      wholesalePrice: ((json['tsena_optom'] ?? 0) as num).toDouble(),
      category: json['category']?.toString() ?? '',
      primaryBarcode: primaryBarcode,
      barcodes: mergedBarcodes,
      lastModified: json['last_modified']?.toString() ?? '',
      syncStatus: json['sync_status']?.toString() ?? 'synced',
      isDeleted: json['is_deleted'] == true || json['is_deleted'] == 1,
    );
  }

  factory ProductModel.fromDb(Map<String, Object?> row) {
    final barcodesJson = row['barcodes_json']?.toString() ?? '[]';
    final decoded = jsonDecode(barcodesJson);
    final barcodes = decoded is List
        ? decoded
            .map((barcode) => barcode.toString().trim())
            .where((barcode) => barcode.isNotEmpty)
            .toList()
        : <String>[];

    return ProductModel(
      uuid: row['uuid']?.toString() ?? '',
      name: row['nazvanie']?.toString() ?? '',
      stock: ((row['kolichestvo'] ?? 0) as num).toDouble(),
      costPrice: ((row['tsena_zakupki'] ?? 0) as num).toDouble(),
      retailPrice: ((row['tsena_prodazhi'] ?? 0) as num).toDouble(),
      wholesalePrice: ((row['tsena_optom'] ?? 0) as num).toDouble(),
      category: row['category']?.toString() ?? '',
      primaryBarcode: row['primary_barcode']?.toString() ?? '',
      barcodes: barcodes,
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
      'nazvanie': name,
      'kolichestvo': stock,
      'tsena_zakupki': costPrice,
      'tsena_prodazhi': retailPrice,
      'tsena_optom': wholesalePrice,
      'category': category,
      'primary_barcode': primaryBarcode,
      'barcodes_json': jsonEncode(barcodes),
    };
  }
}
