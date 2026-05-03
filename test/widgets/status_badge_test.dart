import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/core/theme/app_colors.dart';
import 'package:my_pdf/shared/widgets/status_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StatusBadge', () {
    testWidgets('reading → shows READING with correct bg', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge('reading')));
      expect(find.text('READING'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.statusReadingBg);
    });

    testWidgets('finished → shows FINISHED', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge('finished')));
      expect(find.text('FINISHED'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.statusFinishedBg);
    });

    testWidgets('on_hold → shows ON HOLD', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge('on_hold')));
      expect(find.text('ON HOLD'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.statusOnHoldBg);
    });

    testWidgets('unknown status → shows raw value uppercased', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge('archived')));
      expect(find.text('ARCHIVED'), findsOneWidget);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.surfaceMuted);
    });
  });
}
