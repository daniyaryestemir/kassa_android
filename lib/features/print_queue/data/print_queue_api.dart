import '../../../core/network/api_client.dart';

class PrintQueueApi {
  PrintQueueApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadQueue({int limit = 100}) {
    return _client.get('/api/barcode-print-queue', queryParameters: {
      'limit': '$limit',
    });
  }
}
