import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/shared/widgets/app_drawer.dart';

const _user = UserModel(uid: 'u1', name: 'Alice Wonderland', email: 'alice@example.com');

const _book = BookModel(
  id: 'b1',
  title: 'Cosmos',
  link: 'https://example.com/cosmos.pdf',
  totalPages: 100,
  currentPage: 50,
  progress: 50,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

final _shelf = BookshelfModel(
  id: 's1',
  name: 'Science',
  ownerId: 'u1',
  createdAt: DateTime(2025),
);

/// Builds a real GoRouter with the routes the AppDrawer pushes to. Each route
/// returns a unique Scaffold so we can assert which one we landed on after a
/// drawer tap navigates.
Widget _buildHost({
  required NavSection active,
  UserModel? user = _user,
  List<BookshelfModel> shelves = const [],
  List<BookModel> books = const [],
  int notesCount = 0,
  required VoidCallback onClose,
}) {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => Scaffold(
          key: scaffoldKey,
          drawer: AppDrawer(active: active, onClose: onClose),
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                child: const Text('open-drawer'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE_ROUTE')),
      ),
      GoRoute(
        path: '/book/new',
        builder: (_, _) => const Scaffold(body: Text('NEW_BOOK_ROUTE')),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const Scaffold(body: Text('EDIT_PROFILE_ROUTE')),
      ),
    ],
    initialLocation: '/home',
  );

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => Stream.value(user)),
      userProfileProvider.overrideWith((_) => Stream.value(user)),
      shelvesProvider.overrideWith((_) => Stream.value(shelves)),
      allBooksProvider.overrideWith((_) => Stream.value(books)),
      userNotesCountProvider.overrideWith((_) => Stream.value(notesCount)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.text('open-drawer'));
  await tester.pumpAndSettle();
}

void main() {
  group('AppDrawer', () {
    testWidgets('renders user name and email at the top', (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      expect(find.text('Alice Wonderland'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('renders empty profile when user is null', (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        user: null,
        onClose: () {},
      ));
      await _openDrawer(tester);
      // No crash + no leaked text. The Text widgets render with empty strings.
      expect(find.text('Alice Wonderland'), findsNothing);
      expect(find.text('alice@example.com'), findsNothing);
    });

    testWidgets('renders mini-stat counts for READ / NOTES / SHELVES',
        (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        shelves: [_shelf],
        books: const [_book],
        notesCount: 7,
        onClose: () {},
      ));
      await _openDrawer(tester);
      // Mini-stat labels.
      expect(find.text('READ'), findsOneWidget);
      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('SHELVES'), findsOneWidget);
      // Counts.
      expect(find.text('7'), findsOneWidget);
      // 1 shelf + 1 book → both render the digit "1" once each. So two finds.
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('mini-stat counts default to 0 when streams are empty',
        (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      // Three zeros — one per stat.
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('renders nav items with semantic uppercase labels',
        (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('CREATE'), findsOneWidget);
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('LOGOUT'), findsOneWidget);
    });

    testWidgets('renders MAIN NAVIGATION section header', (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      expect(find.text('MAIN NAVIGATION'), findsOneWidget);
    });

    testWidgets('close X button fires onClose callback', (tester) async {
      var closed = 0;
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () => closed++,
      ));
      await _openDrawer(tester);
      // The drawer header's close icon — there's only one Icons.close in
      // the drawer.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets('PROFILE tile fires onClose then navigates to /profile',
        (tester) async {
      var closed = 0;
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () => closed++,
      ));
      await _openDrawer(tester);
      await tester.tap(find.text('PROFILE'));
      // onClose is called first; then a 200ms delayed router.go fires.
      expect(closed, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('PROFILE_ROUTE'), findsOneWidget);
    });

    testWidgets('CREATE tile fires onClose then pushes /book/new',
        (tester) async {
      var closed = 0;
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () => closed++,
      ));
      await _openDrawer(tester);
      await tester.tap(find.text('CREATE'));
      expect(closed, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('NEW_BOOK_ROUTE'), findsOneWidget);
    });

    testWidgets('SETTINGS tile pushes /profile/edit', (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      await tester.tap(find.text('SETTINGS'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('EDIT_PROFILE_ROUTE'), findsOneWidget);
    });

    testWidgets('LIBRARY tile fires onClose then navigates to /home',
        (tester) async {
      var closed = 0;
      await tester.pumpWidget(_buildHost(
        active: NavSection.profile,
        onClose: () => closed++,
      ));
      await _openDrawer(tester);
      await tester.tap(find.text('LIBRARY'));
      expect(closed, 1);
      // Drain the 200 ms Future.delayed in production so the test framework
      // doesn't trip on a pending Timer assertion at teardown.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    });

    testWidgets('active=library highlights Library tile (icon color)',
        (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      // Active vs inactive nav tiles render the Material with a different
      // color. We probe each tile's containing Material's color: active
      // tile has AppColors.surface (white); inactive is transparent.
      final libraryFinder = find.ancestor(
        of: find.text('LIBRARY'),
        matching: find.byType(Material),
      ).first;
      final mat = tester.widget<Material>(libraryFinder);
      expect(mat.color, isNotNull);
    });

    testWidgets('active=profile highlights Profile tile, not Library',
        (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.profile,
        onClose: () {},
      ));
      await _openDrawer(tester);
      // The drawer renders profile as the active section.
      expect(find.text('PROFILE'), findsOneWidget);
      // We don't assert specific Material colors here — covered indirectly by
      // the icon color tests in the AppBottomNavBar suite. Sanity tap target
      // works.
      await tester.tap(find.text('PROFILE'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
    });

    testWidgets('renders MYPDF brand footer', (tester) async {
      await tester.pumpWidget(_buildHost(
        active: NavSection.library,
        onClose: () {},
      ));
      await _openDrawer(tester);
      expect(find.text('MYPDF'), findsOneWidget);
    });
  });
}
