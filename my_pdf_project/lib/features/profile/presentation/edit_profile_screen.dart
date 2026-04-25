import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
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
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    try {
      await ref.read(firestoreDataSourceProvider).updateUserProfile(
            uid,
            name: name,
          );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed. Try again.')));
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.canPop()
                        ? context.pop()
                        : context.go('/profile'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.primary, size: 18),
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
                          horizontal: 16, vertical: 8),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
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
                              vertical: 12, horizontal: 16),
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
                            vertical: 16, horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.5),
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
