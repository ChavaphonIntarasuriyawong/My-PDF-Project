// Component-level golden — GradientButton.
//
// Why component-level rather than full LoginScreen: full-screen goldens depend
// on the Inter font asset + post-frame plugin probes (biometric, Firebase
// listeners). Component-level goldens give deterministic pixel diffs without
// pulling those side effects.
//
// Regenerate: flutter test --update-goldens test/golden/gradient_button_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/theme/app_theme.dart';
import 'package:my_pdf/shared/widgets/gradient_button.dart';

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    );

void main() {
  group('GradientButton goldens', () {
    testWidgets('idle', (tester) async {
      await tester.pumpWidget(
        _harness(GradientButton(label: 'Sign In', onPressed: () {})),
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_idle.png'),
      );
    });

    testWidgets('loading', (tester) async {
      await tester.pumpWidget(
        _harness(
          GradientButton(label: 'Sign In', loading: true, onPressed: () {}),
        ),
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_loading.png'),
      );
    });

    testWidgets('disabled', (tester) async {
      await tester.pumpWidget(
        _harness(const GradientButton(label: 'Sign In', onPressed: null)),
      );
      await expectLater(
        find.byType(GradientButton),
        matchesGoldenFile('goldens/gradient_button_disabled.png'),
      );
    });
  });
}
