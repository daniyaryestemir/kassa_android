import '../../../core/network/api_client.dart';

class PostupleniyaApi {
  PostupleniyaApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadReceipts({String query = ''}) {
    return _client.get('/api/postupleniya', queryParameters: {
      if (query.trim().isNotEmpty) 'q': query.trim(),
    });
  }

  Future<Map<String, dynamic>> loadReceiptDetail(String uuid) {
    return _client.get('/api/postupleniya', queryParameters: {'uuid': uuid});
  }
}
