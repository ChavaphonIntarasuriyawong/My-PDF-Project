import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/shared/widgets/labeled_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('LabeledTextField', () {
    testWidgets('shows label uppercased and hint', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          LabeledTextField(
            label: 'email',
            hint: 'you@example.com',
            controller: ctrl,
          ),
        ),
      );
      expect(find.text('EMAIL'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('shows error text when provided', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          LabeledTextField(
            label: 'Password',
            hint: '••••',
            controller: ctrl,
            errorText: 'Too short',
          ),
        ),
      );
      expect(find.text('Too short'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('accepts text input', (tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        _wrap(
          LabeledTextField(label: 'Name', hint: 'Your name', controller: ctrl),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Alice');
      expect(ctrl.text, 'Alice');
      ctrl.dispose();
    });
  });
}
