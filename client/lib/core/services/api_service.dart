import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// API Service for HTTP communication with TheBridge server
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _token;
  String _baseUrl = 'http://localhost:3000';

  Future<void> initialize({String? serverUrl}) async {
    if (serverUrl != null) _baseUrl = serverUrl;

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _baseUrl = prefs.getString('server_url') ?? _baseUrl;

    _dio = Dio(
      BaseOptions(
        baseUrl: '$_baseUrl/api',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired — could trigger re-auth flow
          }
          handler.next(error);
        },
      ),
    );
  }

  void setToken(String token) {
    _token = token;
  }

  void setServerUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = '$url/api';
  }

  String get serverUrl => _baseUrl;

  // ========== AUTH ==========

  Future<Map<String, dynamic>> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'username': username,
        'displayName': displayName,
        'password': password,
        'email': email,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
        'deviceInfo': deviceInfo,
      },
    );
    return response.data;
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    _token = null;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final response = await _dio.get(
      '/auth/users/search',
      queryParameters: {'q': query},
    );
    return response.data;
  }

  Future<List<dynamic>> getOnlineUsers() async {
    final response = await _dio.get('/auth/users/online');
    return response.data;
  }

  // ========== CHANNELS ==========

  Future<List<dynamic>> getChannels() async {
    final response = await _dio.get('/channels');
    return response.data;
  }

  Future<Map<String, dynamic>> createChannel({
    required String name,
    String? description,
    bool isPrivate = false,
    List<String>? members,
  }) async {
    final response = await _dio.post(
      '/channels',
      data: {
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
        'members': members,
      },
    );
    return response.data;
  }

  Future<List<dynamic>> getChannelMessages(
    String channelId, {
    int limit = 50,
    String? before,
  }) async {
    final response = await _dio.get(
      '/channels/$channelId/messages',
      queryParameters: {'limit': limit, 'before': ?before},
    );
    return response.data;
  }

  Future<List<dynamic>> getChannelMembers(String channelId) async {
    final response = await _dio.get('/channels/$channelId/members');
    return response.data;
  }

  // ========== MESSAGES ==========

  Future<List<dynamic>> getDirectMessages(
    String userId, {
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/messages/dm/$userId',
      queryParameters: {'limit': limit},
    );
    return response.data;
  }

  Future<List<dynamic>> getConversations() async {
    final response = await _dio.get('/messages/conversations');
    return response.data;
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    final response = await _dio.get('/messages/unread');
    return response.data;
  }

  // ========== DISCOVERY ==========

  Future<Map<String, dynamic>> getServerInfo() async {
    final response = await _dio.get('/discovery/server-info');
    return response.data;
  }

  Future<void> registerDevice(Map<String, dynamic> deviceInfo) async {
    await _dio.post('/discovery/register', data: deviceInfo);
  }

  // ========== MEETINGS ==========

  Future<List<dynamic>> getActiveMeetings() async {
    final response = await _dio.get('/meetings');
    return response.data;
  }

  // ========== STATUS ==========

  Future<Map<String, dynamic>> getServerStatus() async {
    final response = await _dio.get('/status');
    return response.data;
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
