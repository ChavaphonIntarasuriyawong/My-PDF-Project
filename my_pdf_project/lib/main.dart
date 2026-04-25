import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  // Capture all uncaught errors and route them to Crashlytics in release builds.
  await runZonedGuarded(() async {
    if (kDebugMode) {
      MarionetteBinding.ensureInitialized();
    } else {
      WidgetsFlutterBinding.ensureInitialized();
    }
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    // Crashlytics: only collect in release; debug builds skip the network noise.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await Supabase.initialize(
      url: 'https://wtjwmwisitohlzyinoaf.supabase.co',
      anonKey: 'sb_publishable_WY9c8ogY4iVKHU7sFT5slw_oUoQFAl8',
    );
    runApp(const ProviderScope(child: MyPdfApp()));
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
    );
  }
}
