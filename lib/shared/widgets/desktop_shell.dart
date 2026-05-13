import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'desktop_nav_sidebar.dart';

/// Post-auth desktop shell: persistent sidebar + main content area.
///
/// Injected by `MyPdfApp.builder` for any non-auth route when the viewport is
/// >= `kDesktopBreakpoint`. Per-screen `_DesktopBody` widgets render inside
/// the right pane; they should NOT add their own sidebar.
///
/// The `router` is forwarded explicitly to the sidebar because the shell
/// renders OUTSIDE the InheritedGoRouter widget that GoRouter installs inside
/// the Navigator subtree — so `GoRouter.of(context)` / `context.go` would fail
/// here. The sidebar uses the captured router directly.
class DesktopShell extends StatelessWidget {
  final GoRouter router;
  final Widget child;
  const DesktopShell({super.key, required this.router, required this.child});

  @override
  Widget build(BuildContext context) {
    // Material ancestor required because `InkWell` lives in the sidebar but
    // MaterialApp.router.builder runs above the Navigator (no Scaffold yet).
    return Material(
      color: AppColors.background,
      child: Row(
        children: [
          DesktopNavSidebar(router: router),
          Expanded(
            child: ColoredBox(color: AppColors.background, child: child),
          ),
        ],
      ),
    );
  }
}
