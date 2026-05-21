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
  bool _allowUnauth = false;

  Future<void> login(String phone, String name) async {
    final url = Uri.parse('${AppConfig.backendUrl}/api/auth/login');
    debugPrint('Logging in to backend at $url for phone: $phone');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone, 'name': name}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) {
          _token = parsed['token'] as String?;
          _currentAgent = (parsed['agent'] as Map?)?.cast<String, dynamic>();
          debugPrint('Successfully authenticated with backend via legacy login.');
          return;
        }
        debugPrint('Login returned non-object JSON: ${response.body}');
        throw Exception('Invalid login response shape');
      } catch (e) {
        debugPrint('Failed to parse JSON from login response: $e');
        debugPrint('Login response body: ${response.body}');
        throw Exception('Failed to parse login response: ${response.statusCode}');
      }
    }

    // Non-200: try to extract an error message, but fall back to raw body.
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map && parsed['error'] != null) {
        throw Exception(parsed['error'].toString());
      }
      throw Exception('Failed to log in: ${response.statusCode} - ${response.body}');
    } catch (_) {
      throw Exception('Failed to log in: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> ensureAuthenticated() async {
    if (_allowUnauth) return;
    if (_token != null) return;

    // Use the configured legacy agent if a route needs auth before the sign-in screen runs.
    if (AppConfig.agentPhone.isNotEmpty) {
      try {
        await login(AppConfig.agentPhone, AppConfig.agentName);
        return;
      } catch (e) {
        debugPrint('Legacy login failed: $e');
        _allowUnauth = true;
        return;
      }
    }
    _allowUnauth = true;
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
        'sender_agent_id': _resolveSenderAgentId(),
        'source': source,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send message: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> confirmMessage({
    required Map<String, dynamic> parsedData,
    required String sessionId,
  }) async {
    await ensureAuthenticated();
    final url = Uri.parse('${AppConfig.backendUrl}/api/confirm');
    final response = await http.post(
      url,
      headers: _headers(),
      body: jsonEncode({
        'parsed_data': parsedData,
        'sender_agent_id': _resolveSenderAgentId(),
        'session_id': sessionId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to confirm message: ${response.statusCode}');
  }

  String _resolveSenderAgentId() {
    String normalize(dynamic value) {
      final raw = (value ?? '').toString().trim();
      if (raw.isEmpty) return '';
      final digits = raw.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? raw : '+$digits';
    }

    final fromPhone = normalize(_currentAgent?['phone_number']);
    if (fromPhone.isNotEmpty) return fromPhone;

    final configured = normalize(AppConfig.agentPhone);
    if (configured.isNotEmpty) return configured;

    final fallbackId = (_currentAgent?['id'] ?? '').toString().trim();
    return fallbackId;
  }

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null && !_allowUnauth) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // --- Listings ---
  Future<List<dynamic>> getMapListings() async {
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load map listings: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
      return decoded['data'] as List<dynamic>;
    }
    throw Exception('Unexpected map listings response shape');
  }

  Future<List<dynamic>> getListings() async {
    final url = Uri.parse('${AppConfig.backendUrl}/api/listings');

    // Prefer global/public fetch without auth so backend does not scope by agent token.
    var response = await http.get(
      url,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      await ensureAuthenticated();
      response = await http.get(url, headers: _headers());
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load listings: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic> && decoded['data'] is List<dynamic>) {
      return decoded['data'] as List<dynamic>;
    }
    throw Exception('Unexpected listings response shape');
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

  Future<List<dynamic>> getRecommendations({int limit = 20}) async {
    await ensureAuthenticated();
    final agent = Uri.encodeQueryComponent(_resolveSenderAgentId());
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/analytics/recommendations?limit=$limit&agent_id=$agent',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load recommendations: ${response.statusCode}');
  }

  Future<List<dynamic>> runRecommendations() async {
    await ensureAuthenticated();
    final agent = Uri.encodeQueryComponent(_resolveSenderAgentId());
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/recommender/run?agent_id=$agent',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final recs = decoded['recommendations'];
      if (recs is List<dynamic>) {
        return recs;
      }
      return [];
    }
    throw Exception('Failed to run recommendations: ${response.statusCode}');
  }

  Future<List<dynamic>> getDemandVsSupply({String? blockId}) async {
    await ensureAuthenticated();
    final query = blockId != null && blockId.isNotEmpty
        ? '?block_id=$blockId'
        : '';
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/analytics/demand-vs-supply$query',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load demand vs supply: ${response.statusCode}');
  }

  Future<List<dynamic>> getPriceStats({String? blockId, String? unit}) async {
    await ensureAuthenticated();
    final params = <String>[];
    if (blockId != null && blockId.isNotEmpty) params.add('block_id=$blockId');
    if (unit != null && unit.isNotEmpty) params.add('unit=$unit');
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/analytics/price-stats$query',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load price stats: ${response.statusCode}');
  }

  Future<List<dynamic>> getVelocity({String? blockId, int days = 30}) async {
    await ensureAuthenticated();
    final params = <String>['days=$days'];
    if (blockId != null && blockId.isNotEmpty) params.add('block_id=$blockId');
    final query = '?${params.join('&')}';
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/analytics/velocity$query',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load velocity: ${response.statusCode}');
  }

  Future<List<dynamic>> getCornerPremium({String? blockId}) async {
    await ensureAuthenticated();
    final query = blockId != null && blockId.isNotEmpty
        ? '?block_id=$blockId'
        : '';
    final url = Uri.parse(
      '${AppConfig.backendUrl}/api/analytics/corner-premium$query',
    );
    final response = await http.get(url, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load corner premium: ${response.statusCode}');
  }
}
