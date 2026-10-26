import '../../../core/network/api_client.dart';

class DashboardApi {
  DashboardApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> loadDashboard() {
    return _client.get('/api/dashboard');
  }
}
