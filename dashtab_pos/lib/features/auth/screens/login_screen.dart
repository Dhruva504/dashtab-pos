import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_icons.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _workspaceController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _workspaceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Enter your email and password.');
      return;
    }
    final String? errorMsg;
    if (_registerMode) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _showError('Enter your full name.');
        return;
      }
      errorMsg = await ref.read(authProvider.notifier).register(
            name: name,
            email: email,
            password: password,
            restaurantName: _workspaceController.text.trim(),
          );
    } else {
      errorMsg = await ref
          .read(authProvider.notifier)
          .login(email: email, password: password);
    }
    if (errorMsg == null && mounted) {
      context.go('/');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() => _localError = msg);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width >= 900;

    final form = _buildForm(
      context,
      isLoading,
      authState.errorMessage ?? _localError,
      isDark,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: _buildLeftPanel(context, isDark)),
                Expanded(
                  flex: 9,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: form,
                ),
              ),
            ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF14151C),
            isDark ? AppColors.darkSide : const Color(0xFF1D1E27),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Branded panel backdrop (no remote placeholder art).
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF23242F),
                  isDark ? AppColors.darkSide : const Color(0xFF191A22),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF14151C).withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.brand, Color(0xFFFF8A4C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: 0.55),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          AppIcons.flame,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DashTab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'POS SUITE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 17)),
                        const SizedBox(width: 10),
                        Text(
                          'Live floor, kitchen & cash — updated in real time',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.09),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧾', style: TextStyle(fontSize: 17)),
                        const SizedBox(width: 10),
                        Text(
                          'Orders, kitchen, staff & reports — one terminal',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Run your restaurant,\nbeautifully.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -0.6,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Orders, tables, kitchen, staff and analytics — one state-of-the-art terminal for your whole floor.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    bool isLoading,
    String? error,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppColors.darkLine : AppColors.line),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _registerMode ? 'Create your workspace 🚀' : 'Welcome back 👋',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            _registerMode
                ? 'Set up DashTab for your restaurant. Your first workspace is created automatically.'
                : 'Log in to your DashTab account to continue.',
            style: TextStyle(
              color: isDark ? AppColors.darkText2 : AppColors.text2,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          if (_registerMode) ...[
            _Label('RESTAURANT NAME'),
            const SizedBox(height: 6),
            TextField(
              controller: _workspaceController,
              decoration: const InputDecoration(
                hintText: 'e.g. La Trattoria',
                prefixIcon: Icon(AppIcons.buildings, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            _Label('FULL NAME'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Ana García',
                prefixIcon: Icon(AppIcons.user, size: 18),
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox.shrink(),
          _Label(_registerMode ? 'EMAIL' : 'EMAIL'),
          const SizedBox(height: 6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'you@restaurant.com',
              prefixIcon: Icon(AppIcons.user, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          _Label('PASSWORD'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLoading ? null : _submit(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(AppIcons.lock, size: 18),
              suffixIcon: IconButton(
                tooltip: 'Show password',
                icon: Icon(
                  _obscurePassword
                      ? AppIcons.eye
                      : Icons.visibility_off_rounded,
                  size: 18,
                  color: AppColors.text3,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.redT,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.red, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _submit,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(AppIcons.arrowR, size: 18),
              label: Text(
                isLoading
                    ? 'Working…'
                    : _registerMode
                    ? 'Create workspace'
                    : 'Log in',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: isLoading
                ? null
                : () => setState(() {
                      _registerMode = !_registerMode;
                      _localError = null;
                      ref.read(authProvider.notifier).clearError();
                    }),
            child: Text(
              _registerMode
                  ? 'Already have an account? Log in'
                  : 'New here? Create your workspace',
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.06,
        color: AppColors.text3,
      ),
    );
  }
}
