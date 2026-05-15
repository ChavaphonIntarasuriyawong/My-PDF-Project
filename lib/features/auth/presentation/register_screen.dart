import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/desktop_auth_shell.dart';
import '../../../shared/widgets/escape_pop_scope.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .register(name: name, email: email, password: password);
    if (success && mounted) context.go(AppRoutes.home);
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
      return EscapePopScope(
        onEscape: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.login),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: _DesktopBody(
            nameCtrl: _nameCtrl,
            emailCtrl: _emailCtrl,
            passwordCtrl: _passwordCtrl,
            confirmCtrl: _confirmCtrl,
            nameFocus: _nameFocus,
            emailFocus: _emailFocus,
            passwordFocus: _passwordFocus,
            confirmFocus: _confirmFocus,
            obscurePassword: _obscurePassword,
            obscureConfirm: _obscureConfirm,
            loading: isLoading,
            onSubmit: _submit,
            onTogglePassword: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            onToggleConfirm: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            onSignIn: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.login),
          ),
        ),
      );
    }

    return EscapePopScope(
      onEscape: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.login),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top app bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.login),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Create Account', style: AppTypography.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      // Hero section
                      Column(
                        children: [
                          Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 1,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Join the Collection',
                            style: AppTypography.headlineLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Every great insight begins with a single page.\nCurate your knowledge with us.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFF506872),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Form card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LabeledTextField(
                              label: 'Username',
                              hint: 'Johnathan',
                              controller: _nameCtrl,
                              focusNode: _nameFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: () => _emailFocus.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                            LabeledTextField(
                              label: 'Email',
                              hint: 'johnathan@gmail.com',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              focusNode: _emailFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: () => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                            LabeledTextField(
                              label: 'Password',
                              hint: '••••••••',
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              focusNode: _passwordFocus,
                              textInputAction: TextInputAction.next,
                              onSubmitted: () => _confirmFocus.requestFocus(),
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
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            LabeledTextField(
                              label: 'Confirm Password',
                              hint: '••••••••',
                              controller: _confirmCtrl,
                              obscureText: _obscureConfirm,
                              focusNode: _confirmFocus,
                              textInputAction: TextInputAction.done,
                              onSubmitted: _submit,
                              suffix: IconButton(
                                tooltip: _obscureConfirm
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            GradientButton(
                              label: 'Sign Up',
                              loading: isLoading,
                              onPressed: _submit,
                              borderRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Semantics(
                        button: true,
                        label: 'Already have an account? Sign In',
                        child: GestureDetector(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.login),
                          child: ExcludeSemantics(
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: const Color(0xFF506872),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopBody extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final FocusNode nameFocus;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final FocusNode confirmFocus;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSignIn;

  const _DesktopBody({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.nameFocus,
    required this.emailFocus,
    required this.passwordFocus,
    required this.confirmFocus,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.loading,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return DesktopAuthShell(
      brandingOnLeft: false,
      branding: const DesktopAuthBranding(
        tagline:
            'Every great insight begins with a single page. Curate your knowledge with us',
      ),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Join the Collection', style: AppTypography.headlineLarge),
          const SizedBox(height: 16),
          LabeledTextField(
            label: 'Username',
            hint: 'Johnathan',
            controller: nameCtrl,
            focusNode: nameFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => emailFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          LabeledTextField(
            label: 'Email',
            hint: 'johnathan@gmail.com',
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            focusNode: emailFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          LabeledTextField(
            label: 'Password',
            hint: '••••••••',
            controller: passwordCtrl,
            obscureText: obscurePassword,
            focusNode: passwordFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: () => confirmFocus.requestFocus(),
            suffix: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onTogglePassword,
            ),
          ),
          const SizedBox(height: 12),
          LabeledTextField(
            label: 'Confirm Password',
            hint: '••••••••',
            controller: confirmCtrl,
            obscureText: obscureConfirm,
            focusNode: confirmFocus,
            textInputAction: TextInputAction.done,
            onSubmitted: onSubmit,
            suffix: IconButton(
              tooltip: obscureConfirm ? 'Show password' : 'Hide password',
              icon: Icon(
                obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: onToggleConfirm,
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Sign Up',
            loading: loading,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 24),
          Center(
            child: Semantics(
              button: true,
              label: 'Already have an account? Sign in',
              child: GestureDetector(
                onTap: onSignIn,
                child: ExcludeSemantics(
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: AppTypography.bodyMedium,
                      children: [
                        TextSpan(
                          text: 'Sign in',
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
