// Component-level golden — StatusBadge across all known states.
//
// Regenerate: flutter test --update-goldens test/golden/status_badge_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/theme/app_theme.dart';
import 'package:my_pdf/shared/widgets/status_badge.dart';

Widget _harness() => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            StatusBadge('reading'),
            SizedBox(height: 8),
            StatusBadge('finished'),
            SizedBox(height: 8),
            StatusBadge('on_hold'),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('StatusBadge — all states', (tester) async {
    await tester.pumpWidget(_harness());
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/status_badge_states.png'),
    );
  });
}
