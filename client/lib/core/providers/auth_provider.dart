import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final socketServiceProvider = Provider<SocketService>((ref) => SocketService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(apiServiceProvider),
    ref.read(socketServiceProvider),
  );
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final SocketService _socketService;

  AuthNotifier(this._apiService, this._socketService) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        await _apiService.initialize();
        final userData = await _apiService.getMe();
        _socketService.initialize(serverUrl: _apiService.serverUrl, token: token);
        state = state.copyWith(isLoading: false, isAuthenticated: true, user: userData);
      } else {
        await _apiService.initialize();
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false, error: e.toString());
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.login(username: username, password: password);
      
      final token = response['token'];
      final user = response['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      _apiService.setToken(token);
      _socketService.initialize(serverUrl: _apiService.serverUrl, token: token);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false, error: "Login failed: $e");
      return false;
    }
  }

  Future<bool> register(String username, String displayName, String password, {String? email}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.register(
        username: username,
        displayName: displayName,
        password: password,
        email: email,
      );

      final token = response['token'];
      final user = response['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      _apiService.setToken(token);
      _socketService.initialize(serverUrl: _apiService.serverUrl, token: token);

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false, error: "Registration failed: $e");
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {}
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    _apiService.setToken('');
    _socketService.disconnect();
    
    state = state.copyWith(isAuthenticated: false, user: null, clearError: true);
  }
}
