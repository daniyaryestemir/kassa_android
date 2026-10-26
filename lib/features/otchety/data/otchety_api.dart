import '../../../core/network/api_client.dart';

class OtchetyApi {
  OtchetyApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadReport({
    String dateFrom = '',
    String dateTo = '',
  }) {
    return _client.get('/api/otchety', queryParameters: {
      if (dateFrom.trim().isNotEmpty) 'date_from': dateFrom.trim(),
      if (dateTo.trim().isNotEmpty) 'date_to': dateTo.trim(),
    });
  }
}
