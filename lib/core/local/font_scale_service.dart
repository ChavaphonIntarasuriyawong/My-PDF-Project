import 'package:hive/hive.dart';

/// Persists the user's preferred in-app font scale factor.
/// Key [_key] lives in the shared [boxName] (`app_prefs`) box alongside
/// [RecentBooksService] and [OcrCacheService] keys.
class FontScaleService {
  static const String boxName = 'app_prefs';
  static const String _key = 'font_scale_factor';

  static const double minScale = 0.85;
  static const double maxScale = 1.50;
  static const double defaultScale = 1.0;

  Box get _box => Hive.box(boxName);

  /// Returns the persisted scale clamped to the valid range.
  double get scale {
    final value = _box.get(_key, defaultValue: defaultScale);
    if (value is! num) return defaultScale;
    return value.toDouble().clamp(minScale, maxScale);
  }

  /// Clamps [value] to the valid range and persists it.
  Future<void> setScale(double value) async {
    await _box.put(_key, value.clamp(minScale, maxScale));
  }
}
