import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/font_scale_service.dart';

/// Hive setup mirrors ocr_cache_service_test.dart:
/// `Hive.initFlutter` requires path_provider which is unavailable in unit
/// tests, so we use `Hive.init(<temp dir>)` and clean up in `tearDownAll`.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('font_scale_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    if (Hive.isBoxOpen(FontScaleService.boxName)) {
      await Hive.box(FontScaleService.boxName).clear();
    } else {
      await Hive.openBox(FontScaleService.boxName);
    }
  });

  group('FontScaleService', () {
    test('scale returns defaultScale when box is empty', () {
      expect(FontScaleService().scale, FontScaleService.defaultScale);
    });

    test('setScale persists value that scale then returns', () async {
      final svc = FontScaleService();
      await svc.setScale(1.25);
      expect(svc.scale, 1.25);
    });

    test('scale clamps stored value below minScale up to minScale', () async {
      await Hive.box(FontScaleService.boxName).put('font_scale_factor', 0.1);
      expect(FontScaleService().scale, FontScaleService.minScale);
    });

    test('scale clamps stored value above maxScale down to maxScale', () async {
      await Hive.box(FontScaleService.boxName).put('font_scale_factor', 9.9);
      expect(FontScaleService().scale, FontScaleService.maxScale);
    });

    test('setScale clamps value below minScale before writing', () async {
      final svc = FontScaleService();
      await svc.setScale(0.0);
      expect(svc.scale, FontScaleService.minScale);
    });

    test('setScale clamps value above maxScale before writing', () async {
      final svc = FontScaleService();
      await svc.setScale(99.0);
      expect(svc.scale, FontScaleService.maxScale);
    });

    test('scale returns defaultScale when stored value is not a num', () async {
      await Hive.box(
        FontScaleService.boxName,
      ).put('font_scale_factor', 'not-a-number');
      expect(FontScaleService().scale, FontScaleService.defaultScale);
    });

    test(
      'scale accepts any value within the valid range without clamping',
      () async {
        final svc = FontScaleService();
        for (final v in [
          FontScaleService.minScale,
          1.0,
          1.2,
          FontScaleService.maxScale,
        ]) {
          await svc.setScale(v);
          expect(svc.scale, v);
        }
      },
    );

    test('setScale overwrites a previous value', () async {
      final svc = FontScaleService();
      await svc.setScale(1.1);
      await svc.setScale(1.4);
      expect(svc.scale, 1.4);
    });

    test(
      'scale writes to the shared app_prefs box, not a separate box',
      () async {
        final svc = FontScaleService();
        await svc.setScale(1.3);
        final raw = Hive.box(FontScaleService.boxName).get('font_scale_factor');
        expect(raw, 1.3);
      },
    );

    test(
      'writing scale does not disturb unrelated keys in app_prefs',
      () async {
        final box = Hive.box(FontScaleService.boxName);
        await box.put('recent_book_ids', <String>['b1']);
        final svc = FontScaleService();
        await svc.setScale(1.2);
        expect(box.get('recent_book_ids'), <String>['b1']);
      },
    );
  });
}
