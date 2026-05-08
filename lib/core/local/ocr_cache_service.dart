import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Hive-backed cache for OCR'd page text so a scanned PDF only ever
/// pays the recognition cost once per page.
///
/// Keys are schema-versioned (`ocr_v1_{bookId}_{pageIndex}`, 0-based) so
/// future engine changes can ship a new namespace without colliding with old
/// values. Cache writes are best-effort: failures are logged via
/// `debugPrint` and never bubble up to the UI — TTS continues to work even
/// if persistence breaks.
class OcrCacheService {
  static const String boxName = 'app_prefs';
  static const String _prefix = 'ocr_v1_';

  Box get _box => Hive.box(boxName);

  String _key(String bookId, int pageIndex) => '$_prefix${bookId}_$pageIndex';

  /// Synchronous read — returns `null` if no cache entry exists.
  String? get(String bookId, int pageIndex) {
    final value = _box.get(_key(bookId, pageIndex));
    return value is String ? value : null;
  }

  /// Persist OCR text for a page. Best-effort: write failures are swallowed.
  Future<void> put(String bookId, int pageIndex, String text) async {
    try {
      await _box.put(_key(bookId, pageIndex), text);
    } catch (e) {
      debugPrint('OcrCacheService.put failed for $bookId page $pageIndex: $e');
    }
  }

  /// Drop every cached page for [bookId]. Called from `LibraryController.deleteBook`
  /// so cascading deletes leave no orphan entries.
  Future<void> purgeBook(String bookId) async {
    try {
      final prefix = '$_prefix${bookId}_';
      final keys = _box.keys
          .whereType<String>()
          .where((k) => k.startsWith(prefix))
          .toList();
      if (keys.isEmpty) return;
      await _box.deleteAll(keys);
    } catch (e) {
      debugPrint('OcrCacheService.purgeBook failed for $bookId: $e');
    }
  }

  /// Admin/debug helper — wipes every `ocr_v1_*` key in the box.
  Future<void> purgeAll() async {
    try {
      final keys = _box.keys
          .whereType<String>()
          .where((k) => k.startsWith(_prefix))
          .toList();
      if (keys.isEmpty) return;
      await _box.deleteAll(keys);
    } catch (e) {
      debugPrint('OcrCacheService.purgeAll failed: $e');
    }
  }
}
