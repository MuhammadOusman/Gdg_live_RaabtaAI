import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../app/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;
  Map<String, dynamic>? _currentAgent;

  String? get token => _token;
  Map<String, dynamic>? get currentAgent => _currentAgent;

  bool get isAuthenticated => _token != null;

  Future<void> login(String phone, String name) async {
    final url = Uri.parse('${AppConfig.backendUrl}/api/auth/login');
    debugPrint('Logging in to backend at $url for phone: $phone');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone, 'name': name}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      _token = body['token'] as String?;
      _currentAgent = body['agent'] as Map<String, dynamic>?;
      debugPrint('Successfully authenticated with backend via legacy login.');
      return;
    }

    final body = jsonDecode(response.body);
    throw Exception(body['error'] ?? 'Failed to log in');
  }

  Future<void> ensureAuthenticated() async {
    if (_token != null) return;

    // Use the configured legacy agent if a route needs auth before the sign-in screen runs.
    if (AppConfig.agentPhone.isNotEmpty) {
      try {
        await login(AppConfig.agentPhone, AppConfig.agentName);
        return;
      } catch (e) {
        debugPrint('Legacy login failed: $e');
      }
    }

    throw Exception('Not authenticated. Please log in.');
  }

  Future<Map<String, dynamic>> sendMessage(
    String text, {
    String source = 'app',
  }) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/message');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'raw_text': text,
        'sender_agent_id': _currentAgent?['id'],
        'source': source,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Listings ---
  Future<List<dynamic>> getListings() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) return decoded;
      if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
        return decoded['data'] as List<dynamic>;
      }
      throw Exception('Unexpected listings response shape');
    }
    throw Exception('Failed to load listings: ${response.statusCode}');
  }

  Future<List<dynamic>> getMyListings() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings/my');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List<dynamic>) return decoded;
      if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
        return decoded['data'] as List<dynamic>;
      }
      throw Exception('Unexpected my listings response shape');
    }
    throw Exception('Failed to load my listings: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> createListing(Map<String, dynamic> data) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create listing: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> updateListing(
    String id,
    Map<String, dynamic> data,
  ) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings/$id');
    final response = await http.patch(
      url,
      headers: _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update listing: ${response.statusCode}');
  }

  Future<void> deleteListing(String id) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings/$id');
    final response = await http.delete(url, headers: _headers());
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete listing: ${response.statusCode}');
    }
  }

  // --- Requests ---
  Future<List<dynamic>> getMyRequests() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/requests/my');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load requests: ${response.statusCode}');
  }

  Future<void> deleteRequest(String id) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/requests/$id');
    final response = await http.delete(url, headers: _headers());
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete request: ${response.statusCode}');
    }
  }

  // --- Notifications (Match Leads) ---
  Future<List<dynamic>> getNotifications() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/notifications');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load notifications: ${response.statusCode}');
  }

  Future<void> markNotificationRead(String id) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/notifications/$id/read');
    final response = await http.patch(url, headers: _headers());
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to mark notification read: ${response.statusCode}',
      );
    }
  }

  // --- Analytics ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/analytics/dashboard');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load dashboard stats: ${response.statusCode}');
  }

  Future<List<dynamic>> getLeaderboard() async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/analytics/leaderboard');
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load leaderboard: ${response.statusCode}');
  }
}
