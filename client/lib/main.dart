import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: TheBridgeApp()));
}

class TheBridgeApp extends ConsumerWidget {
  const TheBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'The Bridge',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      home: authState.isLoading 
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : authState.isAuthenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
