import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/feature_flags.dart';
import 'core/constants/app_router.dart';
import 'core/constants/app_routes.dart';
import 'core/local/recent_books_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'firebase_options.dart';
import 'shared/layout/responsive.dart';
import 'shared/widgets/desktop_shell.dart';
import 'package:go_router/go_router.dart' show GoRouter;

// this works
void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Remote Config: kill switches + feature flags. Never throws — logs and
      // falls through to defaults on offline / fetch errors.
      final featureFlags = FeatureFlags();
      await featureFlags.initialize();

      await Hive.initFlutter();
      await Hive.openBox(RecentBooksService.boxName);

      // Crashlytics is not supported on web.
      if (!kIsWeb) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
          !kDebugMode,
        );
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }

      await Supabase.initialize(
        url: 'https://wtjwmwisitohlzyinoaf.supabase.co',
        anonKey: 'sb_publishable_WY9c8ogY4iVKHU7sFT5slw_oUoQFAl8',
      );
      runApp(
        ProviderScope(
          overrides: [
            // Inject the already-initialized singleton so every `ref.read` reuses
            // the same Remote Config instance — see featureFlagsProvider.
            featureFlagsProvider.overrideWithValue(featureFlags),
          ],
          child: const MyPdfApp(),
        ),
      );
    },
    (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        debugPrint('Uncaught error: $error\n$stack');
      }
    },
  );
}

class MyPdfApp extends ConsumerWidget {
  const MyPdfApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MyPDF',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) {
        // Web only: pick a layout shell based on viewport width.
        //   < 600           pass-through (mobile)
        //   600 – 1023      existing 412×896 phone frame (tablet preview)
        //   >= 1024 (web)   new desktop shell — sidebar + main content,
        //                   except `/login` and `/register` which render
        //                   their own centered split-card via DesktopAuthShell.
        // Native mobile / desktop builds always pass through.
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        final width = MediaQuery.of(context).size.width;
        if (width < 600) return child;
        if (width < kDesktopBreakpoint) return _PhoneFrame(child: child);
        return _DesktopRouteAwareShell(router: router, child: child);
      },
    );
  }
}


/// Listens to the captured GoRouter's route stream and swaps the desktop
/// shell when the active path is an auth route. Using the captured `router`
/// (not `GoRouter.of(context)`) avoids the InheritedGoRouter lookup that
/// fails inside `MaterialApp.router.builder` — the builder's context sits
/// above the Router widget that installs the inherited.
class _DesktopRouteAwareShell extends ConsumerStatefulWidget {
  final GoRouter router;
  final Widget child;
  const _DesktopRouteAwareShell({required this.router, required this.child});

  @override
  ConsumerState<_DesktopRouteAwareShell> createState() =>
      _DesktopRouteAwareShellState();
}

class _DesktopRouteAwareShellState
    extends ConsumerState<_DesktopRouteAwareShell> {
  @override
  void initState() {
    super.initState();
    // The routerDelegate is a ChangeNotifier that fires AFTER redirect logic
    // resolves, so `currentConfiguration.uri.path` is the authoritative source.
    // `routeInformationProvider` lags pre-redirect values and broke the gate.
    widget.router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    // The delegate fires this notification during the first build phase
    // (`setInitialRoutePath` → `notifyListeners`), so calling setState
    // synchronously crashes with "setState during build". Defer to the next
    // frame — by then the redirect has already settled.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Auth gate first: if not definitively signed in (loading / error / null
    // user), suppress the sidebar entirely. This closes the race between
    // FirebaseAuth firing signOut and GoRouter's redirect landing on /login —
    // the sidebar disappears on the same frame the auth stream flips.
    final authState = ref.watch(authStateProvider);
    final user = authState.valueOrNull;
    if (user == null) {
      return widget.child;
    }

    final path =
        widget.router.routerDelegate.currentConfiguration.uri.path;
    if (path == AppRoutes.login || path == AppRoutes.register) {
      // Auth screens render their own DesktopAuthShell.
      return widget.child;
    }
    return DesktopShell(router: widget.router, child: widget.child);
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  static const double _phoneWidth = 412;
  static const double _phoneHeight = 896;
  static const double _breakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (size.width < _breakpoint) return child;

    final maxHeight = size.height.clamp(0.0, _phoneHeight);
    final frame = Container(
      width: _phoneWidth,
      height: maxHeight,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(child: frame),
    );
  }
}
