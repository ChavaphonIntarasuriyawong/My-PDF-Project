import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/shared/widgets/app_bottom_nav_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: child,
      ),
    );

void main() {
  group('AppBottomNavBar', () {
    testWidgets('renders Library, Create, and Profile tabs', (tester) async {
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (_) {}),
      ));
      // Labels are uppercased per design tokens (toUpperCase() in NavItem).
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('CREATE'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('Create tab is highlighted (Figma 17:535 spec)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (_) {}),
      ));
      // The widget hardcodes Create as the always-active tab. Library / Profile
      // tabs render with the inactive (secondary) text color, while Create
      // gets white-on-primary. We probe by comparing the colors of the
      // three label Texts.
      final create = tester.widget<Text>(find.text('CREATE'));
      final library = tester.widget<Text>(find.text('LIBRARY'));
      final profile = tester.widget<Text>(find.text('PROFILE'));
      expect(create.style?.color, Colors.white);
      // Library + profile should NOT be white (they use AppColors.textNav).
      expect(library.style?.color, isNot(Colors.white));
      expect(profile.style?.color, isNot(Colors.white));
    });

    testWidgets('onTap fires NavTab.library when Library tab tapped',
        (tester) async {
      NavTab? tapped;
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (t) => tapped = t),
      ));
      await tester.tap(find.text('LIBRARY'));
      await tester.pump();
      expect(tapped, NavTab.library);
    });

    testWidgets('onTap fires NavTab.create when Create tab tapped',
        (tester) async {
      NavTab? tapped;
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (t) => tapped = t),
      ));
      await tester.tap(find.text('CREATE'));
      await tester.pump();
      expect(tapped, NavTab.create);
    });

    testWidgets('onTap fires NavTab.profile when Profile tab tapped',
        (tester) async {
      NavTab? tapped;
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (t) => tapped = t),
      ));
      await tester.tap(find.text('PROFILE'));
      await tester.pump();
      expect(tapped, NavTab.profile);
    });

    testWidgets('multiple taps fire onTap each time', (tester) async {
      final taps = <NavTab>[];
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: taps.add),
      ));
      await tester.tap(find.text('LIBRARY'));
      await tester.tap(find.text('PROFILE'));
      await tester.tap(find.text('LIBRARY'));
      await tester.pump();
      expect(taps, [NavTab.library, NavTab.profile, NavTab.library]);
    });

    testWidgets('exactly three nav items rendered', (tester) async {
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (_) {}),
      ));
      // Three InkWell-tappable areas (one per tab).
      expect(find.byType(InkWell), findsNWidgets(3));
    });

    testWidgets('renders inside a SafeArea (avoids gesture-bar overlap)',
        (tester) async {
      // The bar wraps its content in SafeArea(top: false). Verify the
      // SafeArea is present so the gesture bar isn't a tap-target hazard.
      await tester.pumpWidget(_wrap(
        AppBottomNavBar(onTap: (_) {}),
      ));
      expect(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.byType(SafeArea),
        ),
        findsOneWidget,
      );
    });
  });
}
