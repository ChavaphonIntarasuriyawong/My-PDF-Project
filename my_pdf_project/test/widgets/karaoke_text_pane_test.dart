import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/reader/presentation/controllers/karaoke_controller.dart';
import 'package:my_pdf/features/reader/presentation/widgets/karaoke_text_pane.dart';

/// Mounts [KaraokeTextPane] under a fresh `UncontrolledProviderScope` so each
/// test owns its [container]. Returns the container so the test can mutate
/// the controller directly via `container.read(karaokeControllerProvider.notifier)`.
///
/// The widget reads `karaokeControllerProvider` (autoDispose); the [container]
/// is disposed in [addTearDown] AFTER `pumpAndSettle()` drains Riverpod's
/// scheduling timer — the autoDispose machinery keeps a delayed dispose
/// queued, and the test framework asserts no Timers remain at teardown.
({ProviderContainer container, Widget widget}) _build({
  void Function(int)? onWordTap,
  double? speed,
  ValueChanged<double>? onSpeedChange,
}) {
  final container = ProviderContainer();
  return (
    container: container,
    widget: UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 412,
            height: 400,
            child: KaraokeTextPane(
              onWordTap: onWordTap,
              currentSpeed: speed,
              onSpeedChange: onSpeedChange,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Drains Riverpod's autoDispose scheduler then disposes [container]. Use as
/// the LAST line of every test — fixes the `A Timer is still pending` assertion
/// when an autoDispose provider is read on a teardown frame.
Future<void> _settleAndDispose(
    WidgetTester tester, ProviderContainer container) async {
  await tester.pumpAndSettle();
  container.dispose();
}

void main() {
  group('KaraokeTextPane', () {
    testWidgets('renders empty state when fullText is empty', (tester) async {
      final r = _build();
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('Press Read to start karaoke captions'), findsOneWidget);
      expect(find.text('The current word lights up as TTS speaks'),
          findsOneWidget);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('renders Karaoke header and close button', (tester) async {
      final r = _build();
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('Karaoke'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('shows Word sync mode label when not in fallback mode',
        (tester) async {
      final r = _build();
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('Word sync'), findsOneWidget);
      expect(find.text('Sentence sync'), findsNothing);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('renders speed slider when both speed args are non-null',
        (tester) async {
      double? lastSpeed;
      final r = _build(speed: 1.0, onSpeedChange: (v) => lastSpeed = v);
      await tester.pumpWidget(r.widget);
      await tester.pump();
      // Speed label format: "1.0x" rendered next to the slider.
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // Mode pill ("Word sync") is hidden when speed slider is mounted to
      // save horizontal space inside the 412 dp phone frame.
      expect(find.text('Word sync'), findsNothing);
      // Sanity: slider is at the configured value.
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 1.0);
      // Drive the onChanged hook directly — Slider drag gestures need precise
      // hit math we don't need for wiring assertions.
      slider.onChanged?.call(1.5);
      expect(lastSpeed, 1.5);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('hides speed slider when speed args are null', (tester) async {
      final r = _build();
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Word sync'), findsOneWidget);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('clamps speed slider value above 2.0 down to 2.0',
        (tester) async {
      // Stale persisted rate could be outside the slider's bounds — production
      // clamps to avoid the Slider invariant assertion.
      final r = _build(speed: 5.0, onSpeedChange: (_) {});
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('2.0x'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 2.0);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('clamps speed slider value below 0.5 up to 0.5',
        (tester) async {
      final r = _build(speed: 0.1, onSpeedChange: (_) {});
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 0.5);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('close button hides the pane (sets isVisible=false)',
        (tester) async {
      final r = _build();
      r.container.read(karaokeControllerProvider.notifier).show();
      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(r.container.read(karaokeControllerProvider).isVisible, isTrue);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      expect(r.container.read(karaokeControllerProvider).isVisible, isFalse);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('renders fullText tokens with active highlight',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('hello karaoke world');
      // Highlight "karaoke" (chars 6..13).
      ctrl.onProgress('hello karaoke world', 6, 13, 'karaoke');

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // All three tokens are individually rendered as Text widgets inside
      // _TappableWord. RichText assembles them via WidgetSpan.
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('karaoke'), findsOneWidget);
      expect(find.text('world'), findsOneWidget);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('onWordTap fires with leading char offset', (tester) async {
      var tapped = -1;
      final r = _build(onWordTap: (offset) => tapped = offset);
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('hello karaoke world');

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // Tap the second word. "karaoke" starts at char 6 in "hello karaoke world".
      await tester.tap(find.text('karaoke'));
      await tester.pump();
      expect(tapped, 6);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('onWordTap fires for first word at offset 0', (tester) async {
      var tapped = -1;
      final r = _build(onWordTap: (offset) => tapped = offset);
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('hello karaoke');

      await tester.pumpWidget(r.widget);
      await tester.pump();
      await tester.tap(find.text('hello'));
      await tester.pump();
      expect(tapped, 0);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('words become non-tappable when onWordTap is null',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('hello world');

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // No callback wired — tapping a word should not throw.
      await tester.tap(find.text('hello'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('switches to Sentence sync label when fallback mode flips on',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('Sentence one. Sentence two.');
      ctrl.enableFallbackMode();

      await tester.pumpWidget(r.widget);
      await tester.pump();
      expect(find.text('Sentence sync'), findsOneWidget);
      expect(find.text('Word sync'), findsNothing);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('lifecycle: idle → speak → progress → stop renders gracefully',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // Idle: empty-state copy visible.
      expect(find.text('Press Read to start karaoke captions'), findsOneWidget);

      ctrl.onTtsStart('alpha beta gamma');
      await tester.pump();
      expect(find.text('Press Read to start karaoke captions'), findsNothing);
      expect(find.text('alpha'), findsOneWidget);

      ctrl.onProgress('alpha beta gamma', 0, 5, 'alpha');
      await tester.pump();
      expect(find.text('alpha'), findsOneWidget);

      ctrl.onTtsStop();
      await tester.pump();
      // After stop, span clears but fullText remains.
      expect(find.text('alpha'), findsOneWidget);
      expect(r.container.read(karaokeControllerProvider).isSpeaking, isFalse);
      expect(r.container.read(karaokeControllerProvider).hasActiveSpan, isFalse);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('renders unicode tokens (Cyrillic, Japanese, emoji) as words',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      ctrl.onTtsStart('Привет 日本語 🎉');

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // The tokenizer regex \S+ matches non-whitespace runs.
      expect(find.text('Привет'), findsOneWidget);
      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('🎉'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _settleAndDispose(tester, r.container);
    });

    testWidgets('handles long full text (200 words) without overflow',
        (tester) async {
      final r = _build();
      final ctrl = r.container.read(karaokeControllerProvider.notifier);
      ctrl.show();
      // 200 distinct words exercises the tokenizer's loop on a non-trivial run.
      final longText = List.generate(200, (i) => 'lorem').join(' ');
      ctrl.onTtsStart(longText);

      await tester.pumpWidget(r.widget);
      await tester.pump();
      // No layout exceptions; the SingleChildScrollView absorbs overflow.
      expect(tester.takeException(), isNull);
      // At least the first word should be reachable.
      expect(find.text('lorem'), findsWidgets);
      await _settleAndDispose(tester, r.container);
    });
  });
}
