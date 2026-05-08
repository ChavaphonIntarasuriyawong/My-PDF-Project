import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_pdf/features/auth/domain/user_model.dart';
import 'package:my_pdf/features/auth/presentation/auth_providers.dart';
import 'package:my_pdf/features/library/data/firestore_data_source.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/domain/bookshelf_model.dart';
import 'package:my_pdf/features/library/domain/note_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/features/profile/presentation/edit_profile_screen.dart';

const _user = UserModel(uid: 'u1', name: 'Alice', email: 'alice@test.com');

class _FakeDataSource implements FirestoreDataSource {
  String? savedName;

  @override
  Future<void> updateUserProfile(String uid, {String? name}) async {
    savedName = name;
  }

  @override
  Future<BookshelfModel> createShelf({
    required String name,
    required String ownerId,
  }) => throw UnimplementedError();
  @override
  Future<void> updateShelfName(String s, String n) =>
      throw UnimplementedError();
  @override
  Future<void> deleteShelf(String s) => throw UnimplementedError();
  @override
  Future<BookModel> createBook(BookModel b) => throw UnimplementedError();
  @override
  Future<String?> deleteBook(String b) => throw UnimplementedError();
  @override
  Future<void> updateReadingProgress({
    required String bookId,
    required int currentPage,
    required int totalPages,
  }) => throw UnimplementedError();
  @override
  Future<void> updateBookStatus(String b, String s) =>
      throw UnimplementedError();
  @override
  Future<void> updateBookTitle(String b, String t) =>
      throw UnimplementedError();
  @override
  Future<void> updateBookLock(
    String b, {
    required bool isLocked,
    required String? lockHash,
  }) => throw UnimplementedError();
  @override
  Future<void> moveBook(String b, String s) => throw UnimplementedError();
  @override
  Future<NoteModel?> getNoteById(String n) => throw UnimplementedError();
  @override
  Future<NoteModel> createNote({
    required String bookId,
    required String title,
    required String content,
  }) => throw UnimplementedError();
  @override
  Future<void> updateNote(
    String noteId, {
    required String title,
    required String content,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteNote(String noteId) => throw UnimplementedError();
  @override
  Future<void> deleteNotes(List<String> noteIds) async {}
  @override
  Stream<List<NoteModel>> watchNotesByBookId(String bookId) =>
      const Stream.empty();
  @override
  Stream<List<BookshelfModel>> watchShelves(String o) => const Stream.empty();
  @override
  Stream<List<BookModel>> watchBooks(String o) => const Stream.empty();
  @override
  Stream<List<BookModel>> watchBooksByShelf({
    required String shelfId,
    required String ownerId,
  }) => const Stream.empty();
  @override
  Stream<BookModel?> watchBook(String b) => const Stream.empty();
  @override
  Stream<int> watchUserNotesCount(List<String> bookIds) => Stream.value(0);
}

Widget _buildScreen(_FakeDataSource ds) {
  final router = GoRouter(
    initialLocation: '/profile/edit',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('Profile')),
        routes: [
          GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => Stream.value(_user)),
      userProfileProvider.overrideWith((_) => Stream.value(_user)),
      firestoreDataSourceProvider.overrideWithValue(ds),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('EditProfileScreen (5.7)', () {
    testWidgets('shows Edit Profile title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('Edit Profile'), findsOneWidget);
    });

    testWidgets('pre-fills username field with current name', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.controller?.text, 'Alice');
    });

    testWidgets('shows email as read-only', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeDataSource()));
      await tester.pump();
      expect(find.text('alice@test.com'), findsOneWidget);
    });

    testWidgets('does not save with empty name', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(ds.savedName, isNull);
    });

    testWidgets('saves name and shows snackbar', (tester) async {
      final ds = _FakeDataSource();
      await tester.pumpWidget(_buildScreen(ds));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(ds.savedName, 'Bob');
      expect(find.text('Profile updated'), findsOneWidget);
    });
  });
}
