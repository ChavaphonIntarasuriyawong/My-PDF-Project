import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/shared/widgets/gradient_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('GradientButton', () {
    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(_wrap(
        GradientButton(label: 'Sign In', onPressed: () {}),
      ));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator when loading=true', (tester) async {
      await tester.pumpWidget(_wrap(
        GradientButton(label: 'Sign In', loading: true, onPressed: () {}),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('onPressed fires when not loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        GradientButton(label: 'Go', onPressed: () => tapped = true),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('disabled when onPressed=null', (tester) async {
      await tester.pumpWidget(_wrap(
        const GradientButton(label: 'Go', onPressed: null),
      ));
      final btn = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(btn.onPressed, isNull);
    });
  });
}
