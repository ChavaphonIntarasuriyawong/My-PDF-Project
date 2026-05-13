import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Centered split-card layout for `/login` and `/register` on desktop.
///
/// `brandingOnLeft = true` renders the teal MYPDF panel on the left (login).
/// `brandingOnLeft = false` mirrors it to the right (register). The `form`
/// child is the right/left content panel; the `branding` content is rendered
/// inside the teal panel.
class DesktopAuthShell extends StatelessWidget {
  final bool brandingOnLeft;
  final Widget form;
  final Widget branding;

  const DesktopAuthShell({
    super.key,
    required this.form,
    required this.branding,
    this.brandingOnLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    final brandingPanel = Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(48, 56, 48, 48),
      alignment: Alignment.topLeft,
      child: branding,
    );
    final formPanel = Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
      child: form,
    );

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 620),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: brandingOnLeft
                    ? [
                        Expanded(child: brandingPanel),
                        Expanded(child: formPanel),
                      ]
                    : [
                        Expanded(child: formPanel),
                        Expanded(child: brandingPanel),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard branding content (wordmark, tagline, footer blurb) used by both
/// `/login` and `/register` so the two screens stay in visual lockstep.
class DesktopAuthBranding extends StatelessWidget {
  final String tagline;
  const DesktopAuthBranding({super.key, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MYPDF',
              style: AppTypography.headlineMedium.copyWith(
                color: Colors.white,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 72),
            Text(
              tagline,
              style: AppTypography.headlineLarge.copyWith(
                color: Colors.white,
                fontSize: 28,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  'DIGITAL LIBRARY V1.0',
                  style: AppTypography.labelSmall.copyWith(
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Access your global collection of research papers and journals in a focused, distraction-free environment.',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
