import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegister = false;
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _serverUrl;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_serverUrl != null && _serverUrl!.isNotEmpty) {
      ref.read(apiServiceProvider).setServerUrl(_serverUrl!);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    final authNotifier = ref.read(authProvider.notifier);
    bool success;

    if (_isRegister) {
      success = await authNotifier.register(
        _usernameController.text,
        _displayNameController.text,
        _passwordController.text,
        email: _emailController.text.isNotEmpty ? _emailController.text : null,
      );
    } else {
      success = await authNotifier.login(
        _usernameController.text,
        _passwordController.text,
      );
    }

    if (!success && mounted) {
      final errorMsg = ref.read(authProvider).error ?? 'Authentication failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppTheme.busy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Animated background orbs
            const FloatingOrbs(),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height:
                      size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Logo & Title
                      _buildHeader()
                          .animate()
                          .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                          .slideY(begin: -0.3, end: 0, duration: 800.ms),

                      const SizedBox(height: 48),

                      // Login Form
                      _buildForm(isLoading)
                          .animate()
                          .fadeIn(duration: 800.ms, delay: 200.ms)
                          .slideY(
                            begin: 0.3,
                            end: 0,
                            duration: 800.ms,
                            delay: 200.ms,
                          ),

                      const SizedBox(height: 24),

                      // Server URL
                      _buildServerConfig().animate().fadeIn(
                        duration: 600.ms,
                        delay: 400.ms,
                      ),

                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Bridge icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryStart.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            'The Bridge',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enterprise Collaboration Platform',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(bool isLoading) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode toggle
            Row(
              children: [
                _buildModeTab('Sign In', !_isRegister),
                const SizedBox(width: 16),
                _buildModeTab('Register', _isRegister),
              ],
            ),
            const SizedBox(height: 24),

            // Display name (register only)
            if (_isRegister) ...[
              _buildTextField(
                controller: _displayNameController,
                label: 'Display Name',
                icon: Icons.person_outline_rounded,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email (optional)',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
            ],

            // Username
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.alternate_email_rounded,
              validator: (v) => v!.length < 3 ? 'Min 3 characters' : null,
            ),
            const SizedBox(height: 16),

            // Password
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              validator: (v) => v!.length < 8 ? 'Min 8 characters' : null,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 28),

            // Submit button
            GradientButton(
              text: _isRegister ? 'Create Account' : 'Sign In',
              isLoading: isLoading,
              onPressed: isLoading ? null : _handleSubmit,
              icon: _isRegister
                  ? Icons.person_add_rounded
                  : Icons.login_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _isRegister = label == 'Register'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryStart.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AppTheme.primaryStart : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppTheme.primaryStart : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.glassSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppTheme.primaryStart,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.busy),
        ),
      ),
    );
  }

  Widget _buildServerConfig() {
    return GestureDetector(
      onTap: _showServerDialog,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, color: AppTheme.textMuted, size: 16),
          const SizedBox(width: 6),
          Text(
            _serverUrl ?? 'Auto-discover server',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.textMuted.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerDialog() {
    final controller = TextEditingController(text: _serverUrl ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Server Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the The Bridge server address or leave empty for auto-discovery.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'http://192.168.204.92:3000',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(
                () => _serverUrl = controller.text.isEmpty
                    ? null
                    : controller.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
