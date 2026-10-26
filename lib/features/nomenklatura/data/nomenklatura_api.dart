import '../../../core/network/api_client.dart';

class NomenklaturaApi {
  NomenklaturaApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadProducts({String query = ''}) {
    return _client.get('/api/nomenklatura', queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
  }
}
