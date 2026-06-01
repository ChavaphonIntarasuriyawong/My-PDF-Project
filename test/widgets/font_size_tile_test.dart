import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/core/local/font_scale_notifier.dart';
import 'package:my_pdf/core/local/font_scale_service.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/profile/presentation/profile_screen.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

// Notifier stub — no Hive needed in widget tests.
class _StubFontScaleNotifier extends FontScaleNotifier {
  final double initial;
  _StubFontScaleNotifier({this.initial = FontScaleService.defaultScale});

  @override
  double build() => initial;
}

Widget _buildScreen({double initialScale = FontScaleService.defaultScale}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/book/new',
        builder: (_, _) => const Scaffold(body: Text('New')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const Scaffold(body: Text('Edit')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userProfileProvider.overrideWith((_) => Stream.value(_user)),
      allBooksProvider.overrideWith((_) => Stream.value(const [])),
      shelvesProvider.overrideWith((_) => Stream.value(const [])),
      authStateProvider.overrideWith((_) => Stream.value(_user)),
      fontScaleNotifierProvider.overrideWith(
        () => _StubFontScaleNotifier(initial: initialScale),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('_FontSizeTile (via ProfileScreen)', () {
    testWidgets('Font Size label is present', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Font Size'), findsOneWidget);
    });

    testWidgets('Slider widget is present', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('Slider initial value matches the provider state', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(initialScale: 1.2));
      await tester.pump();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 1.2);
    });

    testWidgets('Slider min and max match FontScaleService constants', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, FontScaleService.minScale);
      expect(slider.max, FontScaleService.maxScale);
    });

    testWidgets('percentage label shows 0% at minScale', (tester) async {
      await tester.pumpWidget(
        _buildScreen(initialScale: FontScaleService.minScale),
      );
      await tester.pump();
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('percentage label shows 100% at maxScale', (tester) async {
      await tester.pumpWidget(
        _buildScreen(initialScale: FontScaleService.maxScale),
      );
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('percentage label shows 23% at defaultScale (1.0)', (
      tester,
    ) async {
      // (1.0 - 0.85) / (1.50 - 0.85) * 100 = 23%
      await tester.pumpWidget(
        _buildScreen(initialScale: FontScaleService.defaultScale),
      );
      await tester.pump();
      expect(find.text('23%'), findsOneWidget);
    });

    testWidgets('small A and large A markers are present', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // Two separate Text widgets both containing 'A'.
      final aWidgets = find.text('A');
      expect(aWidgets, findsNWidgets(2));
    });

    testWidgets('Semantics label contains Font size text', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildScreen(initialScale: FontScaleService.defaultScale),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(r'Font size, \d+%')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Slider semanticFormatterCallback returns N% string', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.semanticFormatterCallback, isNotNull);
      // At minScale → 0%
      expect(
        slider.semanticFormatterCallback!(FontScaleService.minScale),
        '0%',
      );
      // At maxScale → 100%
      expect(
        slider.semanticFormatterCallback!(FontScaleService.maxScale),
        '100%',
      );
    });
  });
}
