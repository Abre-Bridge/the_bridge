import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final socketServiceProvider = Provider<SocketService>((ref) => SocketService());

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({this.isLoading = false, this.isAuthenticated = false, this.user, this.error});

  AuthState copyWith({bool? isLoading, bool? isAuthenticated, Map<String, dynamic>? user, String? error}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  AuthNotifier(this._ref) : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final api = _ref.read(apiServiceProvider);
      await api.initialize();
      
      if (api.isInitialized) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          final user = await api.getMe();
          _ref.read(socketServiceProvider).initialize(serverUrl: api.serverUrl, token: token);
          state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
          return;
        }
      }
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false, error: e.toString());
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = _ref.read(apiServiceProvider);
      final res = await api.login(username: username, password: password);
      
      final token = res['token'];
      final user = res['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      api.setToken(token);
      _ref.read(socketServiceProvider).initialize(serverUrl: api.serverUrl, token: token);
      
      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String displayName, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final api = _ref.read(apiServiceProvider);
      final res = await api.register(username: username, displayName: displayName, password: password);
      
      final token = res['token'];
      final user = res['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      
      api.setToken(token);
      _ref.read(socketServiceProvider).initialize(serverUrl: api.serverUrl, token: token);
      
      state = state.copyWith(isLoading: false, isAuthenticated: true, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void logout() async {
    try { await _ref.read(apiServiceProvider).logout(); } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _ref.read(socketServiceProvider).disconnect();
    state = AuthState(isAuthenticated: false);
  }
}
