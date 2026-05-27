import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/discovery_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _manualServerUrl = TextEditingController();
  bool _isRegister = false;
  bool _showManualIp = false;

  @override
  void initState() {
    super.initState();
    ref.read(discoveryServiceProvider).scanForServers();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final servers = ref.watch(discoveredServersProvider).value ?? [];
    final currentUrl = ref.watch(apiServiceProvider).serverUrl;

    // Listen for errors and show SnackBar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.redAccent),
        );
      }
    });
    
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_outlined, size: 64, color: AppTheme.primary),
                    const SizedBox(height: 16),
                    Text(_isRegister ? 'Create Account' : 'Welcome to The Bridge', 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (authState.error != null) ...[
                      const SizedBox(height: 12),
                      Text(authState.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    
                    if (!_showManualIp) ...[
                      if (servers.isNotEmpty) 
                        DropdownButtonFormField<String>(
                          value: currentUrl.isEmpty ? null : currentUrl,
                          decoration: const InputDecoration(labelText: 'Select Server'),
                          isExpanded: true,
                          items: servers.map((s) => DropdownMenuItem(value: s.url, child: Text(s.name))).toList(),
                          onChanged: (url) => ref.read(apiServiceProvider).setServerUrl(url!),
                        )
                      else
                        const Text('Searching for servers on LAN...', style: TextStyle(color: Colors.grey)),
                      
                      TextButton(
                        onPressed: () => setState(() => _showManualIp = true),
                        child: const Text('Enter Server IP Manually'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _manualServerUrl,
                        decoration: const InputDecoration(
                          labelText: 'Server URL (e.g. http://192.168.1.5:3050)',
                          hintText: 'http://',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          if (_manualServerUrl.text.isNotEmpty) {
                            ref.read(apiServiceProvider).setServerUrl(_manualServerUrl.text);
                            setState(() => _showManualIp = false);
                          }
                        },
                        child: const Text('Use Manual IP'),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    TextField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
                    TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          if (_username.text.isEmpty || _password.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                            return;
                          }
                          if (ref.read(apiServiceProvider).serverUrl.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a server first')));
                            return;
                          }
                          
                          final notifier = ref.read(authProvider.notifier);
                          if (_isRegister) {
                            notifier.register(_username.text, _username.text, _password.text);
                          } else {
                            notifier.login(_username.text, _password.text);
                          }
                        },
                        child: Text(_isRegister ? 'REGISTER' : 'LOGIN', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() => _isRegister = !_isRegister),
                      child: Text(_isRegister ? 'Already have an account? Login' : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
