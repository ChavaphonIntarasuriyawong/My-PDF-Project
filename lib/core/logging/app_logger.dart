// Centralized structured logger for MyPDF.
//
// Wraps `package:logger` with project conventions:
// - Tag is short uppercase ALL_CAPS_SNAKE (e.g. AUTH, OCR, TTS, LIBRARY).
// - Pretty output in debug builds, compact in release.
// - `error()` mirrors to Crashlytics on non-web platforms so production
//   exceptions surface in the dashboard alongside breadcrumbs.
//
// Static API by design — logger is global and stateless. No Riverpod.
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: kReleaseMode
        ? SimplePrinter(printTime: true, colors: false)
        : PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 100,
            colors: true,
            printEmojis: false,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
    level: kReleaseMode ? Level.info : Level.debug,
  );

  static String _fmt(String tag, String message) => '[$tag] $message';

  static void debug(String tag, String message, {Object? error}) {
    _logger.d(_fmt(tag, message), error: error);
  }

  static void info(String tag, String message) {
    _logger.i(_fmt(tag, message));
  }

  static void warn(
    String tag,
    String message, {
    Object? error,
    StackTrace? st,
  }) {
    _logger.w(_fmt(tag, message), error: error, stackTrace: st);
  }

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? st,
  }) {
    _logger.e(_fmt(tag, message), error: error, stackTrace: st);
    if (!kIsWeb && error != null) {
      // Best-effort Crashlytics mirror — never let logging crash the app.
      try {
        FirebaseCrashlytics.instance.recordError(
          error,
          st,
          reason: _fmt(tag, message),
        );
      } catch (_) {
        // Swallow: Crashlytics may not be initialised in tests.
      }
    }
  }
}
