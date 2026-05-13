import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/responsive.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/escape_pop_scope.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../library/presentation/library_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }
    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    try {
      await ref
          .read(firestoreDataSourceProvider)
          .updateUserProfile(uid, name: name);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.valueOrNull;

    if (!_initialized && user != null) {
      _nameCtrl.text = user.name;
      _initialized = true;
    }

    if (kIsWeb && isDesktop(context)) {
      final allBooks = ref.watch(allBooksProvider).valueOrNull ?? [];
      final shelves = ref.watch(shelvesProvider).valueOrNull ?? [];
      final notesCount = ref.watch(userNotesCountProvider).valueOrNull ?? 0;
      return EscapePopScope(
        onEscape: () =>
            context.canPop() ? context.pop() : context.go('/profile'),
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: _DesktopBody(
            user: user,
            nameCtrl: _nameCtrl,
            saving: _saving,
            readCount: allBooks.length,
            notesCount: notesCount,
            shelvesCount: shelves.length,
            onCancel: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
            onConfirm: _save,
            onLogout: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ),
      );
    }

    return EscapePopScope(
      onEscape: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: AppBottomNavBar(
          onTap: (tab) {
            if (tab == NavTab.library) context.go('/home');
            if (tab == NavTab.create) context.push('/book/new');
            if (tab == NavTab.profile) context.go('/profile');
          },
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        letterSpacing: -0.45,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: AppColors.surfaceMuted),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Username ────────────────────────────────────
                      _ProfileFieldLabel('USERNAME'),
                      const SizedBox(height: 8),
                      _ProfileInputBox(
                        child: TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Email (read-only) ────────────────────────────
                      _ProfileFieldLabel('EMAIL ADDRESS'),
                      const SizedBox(height: 8),
                      _ProfileInputBox(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user?.email ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    color: AppColors.textMuted.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFieldLabel extends StatelessWidget {
  final String text;
  const _ProfileFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 10,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ProfileInputBox extends StatelessWidget {
  final Widget child;
  const _ProfileInputBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFBFC8CC).withValues(alpha: 0.2),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: child,
    );
  }
}

// ── Desktop body — Figma "User Profile - Desktop (edit)" frame ───────────
class _DesktopBody extends StatelessWidget {
  final UserModel? user;
  final TextEditingController nameCtrl;
  final bool saving;
  final int readCount;
  final int notesCount;
  final int shelvesCount;
  final VoidCallback onCancel;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onLogout;

  const _DesktopBody({
    required this.user,
    required this.nameCtrl,
    required this.saving,
    required this.readCount,
    required this.notesCount,
    required this.shelvesCount,
    required this.onCancel,
    required this.onConfirm,
    required this.onLogout,
  });

  String _initials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'[\s@.]+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return source[0].toUpperCase();
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2
          ? p.substring(0, 2).toUpperCase()
          : p[0].toUpperCase();
    }
    return (parts.first[0] + parts.elementAt(1)[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final email = user?.email ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(name, email),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w800,
                      fontSize: 56,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? 'Guest' : name,
                        style: AppTypography.displayLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Stats + editable settings split
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATS INTEGRATED',
                      style: AppTypography.sectionMeta,
                    ),
                    const SizedBox(height: 12),
                    _DesktopStat(label: 'READ', value: '$readCount'),
                    const SizedBox(height: 12),
                    _DesktopStat(label: 'NOTES', value: '$notesCount'),
                    const SizedBox(height: 12),
                    _DesktopStat(label: 'SHELVES', value: '$shelvesCount'),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT SETTINGS',
                      style: AppTypography.sectionMeta,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('USERNAME', style: AppTypography.sectionMeta),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                            child: TextField(
                              controller: nameCtrl,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'EMAIL ADDRESS',
                            style: AppTypography.sectionMeta,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              email,
                              style: AppTypography.bodyLarge.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Cancel edit',
                                child: GestureDetector(
                                  onTap: onCancel,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: AppTypography.labelButton
                                          .copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 14,
                                            height: 1.0,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Semantics(
                                button: true,
                                label: 'Confirm changes',
                                child: GestureDetector(
                                  onTap: saving ? null : onConfirm,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Confirm',
                                            style: AppTypography.labelButton
                                                .copyWith(
                                                  fontSize: 14,
                                                  height: 1.0,
                                                ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.logout,
                              color: AppColors.error,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: 'Logout',
                              child: GestureDetector(
                                onTap: onLogout,
                                child: Text(
                                  'Logout',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopStat extends StatelessWidget {
  final String label;
  final String value;
  const _DesktopStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: AppTypography.displayLarge),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.sectionMeta),
        ],
      ),
    );
  }
}
