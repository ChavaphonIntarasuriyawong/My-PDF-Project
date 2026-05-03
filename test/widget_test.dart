import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal smoke test that verifies the test runner itself can mount a
/// `MaterialApp`. The real coverage lives under test/{models, controllers,
/// widgets, screens, core_local, reader}. Keep this file alive (rather than
/// deleted) so `flutter test test/widget_test.dart` still works.
void main() {
  testWidgets('MaterialApp boots without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('boot'))),
    );
    expect(find.text('boot'), findsOneWidget);
  });
}
