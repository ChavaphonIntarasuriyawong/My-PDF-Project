import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:my_pdf/core/local/font_scale_notifier.dart';
import 'package:my_pdf/core/local/font_scale_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('font_scale_notifier_test_');
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

  ProviderContainer makeContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  group('FontScaleNotifier', () {
    test('initial state is defaultScale when box is empty', () {
      final c = makeContainer();
      expect(c.read(fontScaleNotifierProvider), FontScaleService.defaultScale);
    });

    test('initial state reflects a previously persisted value', () async {
      await FontScaleService().setScale(1.3);
      final c = makeContainer();
      expect(c.read(fontScaleNotifierProvider), 1.3);
    });

    test('setScale updates state', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(1.2);
      expect(c.read(fontScaleNotifierProvider), 1.2);
    });

    test('setScale persists value to Hive', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(1.15);
      final raw = Hive.box(FontScaleService.boxName).get('font_scale_factor');
      expect(raw, 1.15);
    });

    test('setScale clamps below minScale — state reflects clamped value', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(0.0);
      expect(c.read(fontScaleNotifierProvider), FontScaleService.minScale);
    });

    test('setScale clamps above maxScale — state reflects clamped value', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(99.0);
      expect(c.read(fontScaleNotifierProvider), FontScaleService.maxScale);
    });

    test('multiple setScale calls update state each time', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(1.0);
      expect(c.read(fontScaleNotifierProvider), 1.0);
      await c.read(fontScaleNotifierProvider.notifier).setScale(1.4);
      expect(c.read(fontScaleNotifierProvider), 1.4);
      await c.read(fontScaleNotifierProvider.notifier).setScale(0.9);
      expect(c.read(fontScaleNotifierProvider), 0.9);
    });

    test('state is consistent with service.scale after setScale', () async {
      final c = makeContainer();
      await c.read(fontScaleNotifierProvider.notifier).setScale(1.35);
      expect(c.read(fontScaleNotifierProvider), FontScaleService().scale);
    });
  });
}
