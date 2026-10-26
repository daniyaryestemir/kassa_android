import '../../../core/network/api_client.dart';

class KassaApi {
  KassaApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadProducts({String query = ''}) {
    return _client.get('/api/kassa/products', queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> body) {
    return _client
        .post('/api/kassa/checkout', body: body)
        .timeout(const Duration(seconds: 8));
  }
}
