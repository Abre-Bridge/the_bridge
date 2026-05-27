import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late Dio _dio;
  String? _serverUrl;
  String? _token;

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    ));
  }

  String get serverUrl => _serverUrl ?? '';
  bool get isInitialized => _serverUrl != null;

  Future<void> initialize({String? overrideUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = overrideUrl ?? prefs.getString('server_url');
    _token = prefs.getString('auth_token');

    if (_serverUrl != null) {
      _dio.options.baseUrl = _serverUrl!;
    }
    
    if (_token != null && _token!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  void setServerUrl(String url) async {
    _serverUrl = url;
    _dio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // --- Auth ---

  Future<Map<String, dynamic>> login({required String username, required String password}) async {
    final response = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    if (response.statusCode == 200) return response.data;
    throw Exception(response.data['error'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
  }) async {
    final response = await _dio.post('/api/auth/register', data: {
      'username': username,
      'display_name': displayName,
      'password': password,
      'email': email,
    });
    if (response.statusCode == 201) return response.data;
    throw Exception(response.data['error'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/api/auth/me');
    if (response.statusCode == 200) return response.data;
    throw Exception('Failed to get user profile');
  }

  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
  }

  // --- Chat Data ---

  Future<List<dynamic>> getChannels() async {
    final response = await _dio.get('/api/channels');
    return response.data as List;
  }

  Future<List<dynamic>> getConversations() async {
    final response = await _dio.get('/api/messages/conversations');
    return response.data as List;
  }

  Future<List<dynamic>> getOnlineUsers() async {
    final response = await _dio.get('/api/users/online');
    return response.data as List;
  }

  Future<List<dynamic>> getChannelMessages(String channelId) async {
    final response = await _dio.get('/api/channels/$channelId/messages');
    return response.data as List;
  }

  Future<List<dynamic>> getDirectMessages(String userId) async {
    final response = await _dio.get('/api/messages/$userId');
    return response.data as List;
  }

  // --- Files ---

  Future<Map<String, dynamic>> uploadFile(String filePath, String fileName, String contentType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    final response = await _dio.post('/api/upload', data: formData);
    if (response.statusCode == 200) return response.data;
    throw Exception('Upload failed');
  }

  Future<List<dynamic>> getActiveMeetings() async {
    final response = await _dio.get('/api/meetings/active');
    return response.data as List;
  }
}
