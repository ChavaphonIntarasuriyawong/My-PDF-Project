import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/desktop_auth_shell.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(email: email, password: password);
    if (!mounted) return;
    if (success) {
      if (mounted) context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen(authControllerProvider, (_, state) {
      if (state.status == AuthStatus.error && state.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    if (kIsWeb && isDesktop(context)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _DesktopBody(
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          emailFocus: _emailFocus,
          passwordFocus: _passwordFocus,
          obscurePassword: _obscurePassword,
          loading: isLoading,
          onSubmit: _submit,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onRegister: () => context.push(AppRoutes.register),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF191C1D).withValues(alpha: 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome Back', style: AppTypography.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to your editorial workspace.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 40),
                  LabeledTextField(
                    label: 'Email',
                    hint: 'example@gmail.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: () => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 24),
                  LabeledTextField(
                    label: 'Password',
                    hint: '••••••••',
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: _submit,
                    suffix: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Sign In',
                    loading: isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Semantics(
                      button: true,
                      label: "Don't have an account? Register now",
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.register),
                        child: ExcludeSemantics(
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: AppTypography.bodyMedium,
                              children: [
                                TextSpan(
                                  text: 'Register now',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopBody extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onToggleObscure;
  final VoidCallback onRegister;

  const _DesktopBody({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.loading,
    required this.onSubmit,
    required this.onToggleObscure,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopAuthShell(
      brandingOnLeft: true,
      branding: const DesktopAuthBranding(
        tagline: 'Where deep reading meets curated insight.',
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Welcome Back', style: AppTypography.headlineLarge),
          const SizedBox(height: 8),
          Text(
            'Sign in to your library.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          LabeledTextField(
            label: 'Email',
            hint: 'example@gmail.com',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            focusNode: emailFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 24),
          LabeledTextField(
            label: 'Password',
            hint: '••••••••',
            controller: passwordCtrl,
            obscureText: obscurePassword,
            focusNode: passwordFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            suffix: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Sign In',
            loading: loading,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 24),
          Center(
            child: Semantics(
              button: true,
              label: "Don't have an account? Register now",
              child: GestureDetector(
                onTap: onRegister,
                child: ExcludeSemantics(
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: AppTypography.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Register now',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
