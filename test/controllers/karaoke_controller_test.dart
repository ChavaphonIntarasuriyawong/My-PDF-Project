import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/reader/presentation/controllers/karaoke_controller.dart';

void main() {
  group('KaraokeState', () {
    test('default state is idle / hidden / no span', () {
      const s = KaraokeState();
      expect(s.fullText, '');
      expect(s.currentStart, -1);
      expect(s.currentEnd, -1);
      expect(s.isVisible, isFalse);
      expect(s.isSpeaking, isFalse);
      expect(s.fallbackSentenceMode, isFalse);
      expect(s.baseOffset, 0);
      expect(s.hasActiveSpan, isFalse);
    });

    test('hasActiveSpan true only when end > start and start >= 0', () {
      expect(const KaraokeState(currentStart: 0, currentEnd: 1).hasActiveSpan,
          isTrue);
      expect(const KaraokeState(currentStart: 5, currentEnd: 10).hasActiveSpan,
          isTrue);
      expect(const KaraokeState(currentStart: -1, currentEnd: 5).hasActiveSpan,
          isFalse);
      expect(const KaraokeState(currentStart: 5, currentEnd: 5).hasActiveSpan,
          isFalse);
      expect(const KaraokeState(currentStart: 5, currentEnd: 4).hasActiveSpan,
          isFalse);
    });

    test('copyWith preserves untouched fields and overrides given ones', () {
      const s = KaraokeState(
        fullText: 'hello world',
        currentStart: 0,
        currentEnd: 5,
        isVisible: true,
        isSpeaking: true,
        fallbackSentenceMode: true,
        baseOffset: 7,
      );
      final s2 = s.copyWith(currentStart: 6, currentEnd: 11);
      expect(s2.fullText, 'hello world');
      expect(s2.isVisible, isTrue);
      expect(s2.isSpeaking, isTrue);
      expect(s2.fallbackSentenceMode, isTrue);
      expect(s2.baseOffset, 7);
      expect(s2.currentStart, 6);
      expect(s2.currentEnd, 11);
    });
  });

  group('KaraokeController', () {
    late ProviderContainer container;
    late KaraokeController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(karaokeControllerProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('starts with default state', () {
      final s = container.read(karaokeControllerProvider);
      expect(s.fullText, '');
      expect(s.isSpeaking, isFalse);
      expect(s.isVisible, isFalse);
    });

    test('onTtsStart captures fullText and flips isSpeaking on', () {
      controller.onTtsStart('hello world');
      final s = container.read(karaokeControllerProvider);
      expect(s.fullText, 'hello world');
      expect(s.isSpeaking, isTrue);
      expect(s.fallbackSentenceMode, isFalse);
      expect(s.baseOffset, 0);
      expect(s.currentStart, -1);
      expect(s.currentEnd, -1);
    });

    test('onTtsStart preserves visibility flag (does not auto-close pane)', () {
      controller.show();
      expect(container.read(karaokeControllerProvider).isVisible, isTrue);
      controller.onTtsStart('a b c');
      expect(container.read(karaokeControllerProvider).isVisible, isTrue);
    });

    test('onTtsStart resets fallback mode on each new utterance', () {
      controller.onTtsStart('x');
      controller.enableFallbackMode();
      expect(container.read(karaokeControllerProvider).fallbackSentenceMode,
          isTrue);
      controller.onTtsStart('y');
      expect(container.read(karaokeControllerProvider).fallbackSentenceMode,
          isFalse);
    });

    test('onTtsStart with baseOffset stores offset for re-anchoring', () {
      controller.onTtsStart('the rest of the page', baseOffset: 12);
      expect(container.read(karaokeControllerProvider).baseOffset, 12);
    });

    test('onProgress updates currentStart/currentEnd while speaking', () {
      controller.onTtsStart('hello world');
      controller.onProgress('hello world', 0, 5, 'hello');
      final s = container.read(karaokeControllerProvider);
      expect(s.currentStart, 0);
      expect(s.currentEnd, 5);
      expect(s.hasActiveSpan, isTrue);
    });

    test('onProgress is a no-op when not speaking', () {
      // Never called onTtsStart, so isSpeaking is false.
      controller.onProgress('hello', 0, 5, 'hello');
      final s = container.read(karaokeControllerProvider);
      expect(s.currentStart, -1);
      expect(s.currentEnd, -1);
    });

    test('onProgress rejects negative start and inverted spans', () {
      controller.onTtsStart('hello');
      controller.onProgress('hello', -1, 3, 'x');
      expect(container.read(karaokeControllerProvider).currentStart, -1);
      controller.onProgress('hello', 3, 3, 'x');
      expect(container.read(karaokeControllerProvider).currentStart, -1);
      controller.onProgress('hello', 5, 2, 'x');
      expect(container.read(karaokeControllerProvider).currentStart, -1);
    });

    test('onProgress applies baseOffset re-anchor', () {
      controller.onTtsStart('the rest of the page', baseOffset: 4);
      // Engine reports relative offsets — controller adds baseOffset back.
      controller.onProgress('rest of the page', 0, 4, 'rest');
      final s = container.read(karaokeControllerProvider);
      expect(s.currentStart, 4);
      expect(s.currentEnd, 8);
    });

    test('onSentenceTick highlights sentence span when speaking', () {
      controller.onTtsStart('Sentence one. Sentence two.');
      controller.onSentenceTick(14, 27);
      final s = container.read(karaokeControllerProvider);
      expect(s.currentStart, 14);
      expect(s.currentEnd, 27);
    });

    test('onSentenceTick is a no-op when not speaking', () {
      controller.onSentenceTick(0, 10);
      expect(container.read(karaokeControllerProvider).currentStart, -1);
    });

    test('onSentenceTick rejects bad ranges', () {
      controller.onTtsStart('text');
      controller.onSentenceTick(-1, 5);
      expect(container.read(karaokeControllerProvider).currentStart, -1);
      controller.onSentenceTick(5, 5);
      expect(container.read(karaokeControllerProvider).currentStart, -1);
      controller.onSentenceTick(5, 1);
      expect(container.read(karaokeControllerProvider).currentStart, -1);
    });

    test('enableFallbackMode flips flag once and is idempotent', () {
      controller.onTtsStart('x');
      expect(container.read(karaokeControllerProvider).fallbackSentenceMode,
          isFalse);
      controller.enableFallbackMode();
      expect(container.read(karaokeControllerProvider).fallbackSentenceMode,
          isTrue);
      // Second call is a no-op (state instance unchanged).
      final before = container.read(karaokeControllerProvider);
      controller.enableFallbackMode();
      final after = container.read(karaokeControllerProvider);
      expect(identical(before, after), isTrue);
    });

    test('onTtsStop clears active span and isSpeaking but keeps visibility',
        () {
      controller.show();
      controller.onTtsStart('hello');
      controller.onProgress('hello', 0, 5, 'hello');
      controller.onTtsStop();
      final s = container.read(karaokeControllerProvider);
      expect(s.isSpeaking, isFalse);
      expect(s.currentStart, -1);
      expect(s.currentEnd, -1);
      expect(s.isVisible, isTrue, reason: 'visibility preserved across stop');
      expect(s.fullText, 'hello',
          reason: 'fullText only reset on next onTtsStart');
    });

    test('show / hide / toggleVisible drive isVisible', () {
      expect(container.read(karaokeControllerProvider).isVisible, isFalse);
      controller.show();
      expect(container.read(karaokeControllerProvider).isVisible, isTrue);
      controller.show(); // idempotent
      expect(container.read(karaokeControllerProvider).isVisible, isTrue);
      controller.hide();
      expect(container.read(karaokeControllerProvider).isVisible, isFalse);
      controller.hide(); // idempotent
      expect(container.read(karaokeControllerProvider).isVisible, isFalse);
      controller.toggleVisible();
      expect(container.read(karaokeControllerProvider).isVisible, isTrue);
      controller.toggleVisible();
      expect(container.read(karaokeControllerProvider).isVisible, isFalse);
    });

    test('full lifecycle: start → progress → stop → start clears prior text',
        () {
      controller.onTtsStart('first page text');
      controller.onProgress('first page text', 0, 5, 'first');
      expect(container.read(karaokeControllerProvider).currentStart, 0);
      controller.onTtsStop();
      controller.onTtsStart('next page');
      final s = container.read(karaokeControllerProvider);
      expect(s.fullText, 'next page');
      expect(s.currentStart, -1);
      expect(s.isSpeaking, isTrue);
      expect(s.baseOffset, 0);
    });
  });
}
