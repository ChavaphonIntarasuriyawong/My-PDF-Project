import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/feature_flags.dart';
import 'core/constants/app_router.dart';
import 'core/local/recent_books_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

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
        // Web only: clamp the app to a phone-shaped frame on wide viewports
        // so the mobile-first layout doesn't stretch across desktop monitors.
        // Below 600px (real mobile browser / narrow), pass through full-width.
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        return _PhoneFrame(child: child);
      },
    );
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
