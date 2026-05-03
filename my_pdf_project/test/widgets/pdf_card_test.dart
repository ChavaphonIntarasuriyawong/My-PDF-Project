import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pdf/features/library/domain/book_model.dart';
import 'package:my_pdf/features/library/presentation/library_providers.dart';
import 'package:my_pdf/shared/widgets/pdf_card.dart';

const _readingBook = BookModel(
  id: 'b1',
  title: 'The Pragmatic Programmer',
  link: 'https://example.com/pdf.pdf',
  totalPages: 320,
  currentPage: 80,
  progress: 25,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
  author: 'Andrew Hunt',
  year: 1999,
);

const _finishedBook = BookModel(
  id: 'b2',
  title: 'Clean Code',
  link: 'https://example.com/clean.pdf',
  totalPages: 100,
  currentPage: 100,
  progress: 100,
  status: 'finished',
  shelfId: 's1',
  ownerId: 'u1',
);

const _emptyLinkBook = BookModel(
  id: 'b3',
  title: 'Local Draft',
  link: '',
  totalPages: 0,
  currentPage: 0,
  progress: 0,
  status: 'on_hold',
  shelfId: 's1',
  ownerId: 'u1',
);

const _zeroPagesBook = BookModel(
  id: 'b4',
  title: 'Empty PDF',
  link: 'https://example.com/zero.pdf',
  totalPages: 0,
  currentPage: 0,
  progress: 0,
  status: 'reading',
  shelfId: 's1',
  ownerId: 'u1',
);

/// Wraps [card] in a ProviderScope + MaterialApp with a stub for the
/// `pdfThumbnailProvider` family so widget tests don't try to spin up
/// Hive / file system / network calls. Default override returns null bytes,
/// which renders the placeholder cover (no spinner, no real Image.memory).
Widget _wrap(Widget card, {Uint8List? thumbBytes}) {
  return ProviderScope(
    overrides: [
      pdfThumbnailProvider.overrideWith((ref, url) async => thumbBytes),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 280, height: 380, child: card),
      ),
    ),
  );
}

void main() {
  group('PdfCard', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('The Pragmatic Programmer'), findsOneWidget);
    });

    testWidgets('renders author and year joined by bullet', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('Andrew Hunt • 1999'), findsOneWidget);
    });

    testWidgets('hides author/year row when both are null', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _finishedBook)));
      await tester.pump();
      // Title row alone — no bullet.
      expect(find.textContaining(' • '), findsNothing);
    });

    testWidgets('renders status badge for the book status', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('READING'), findsOneWidget);

      await tester.pumpWidget(_wrap(const PdfCard(book: _finishedBook)));
      await tester.pump();
      expect(find.text('FINISHED'), findsOneWidget);
    });

    testWidgets('renders PAGE x OF y line', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('PAGE 80 OF 320'), findsOneWidget);
    });

    testWidgets('renders PDF badge in the cover stack', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('renders progress percentage rounded to int %', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('100% progress for finished book', (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _finishedBook)));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('LinearProgressIndicator value matches currentPage / totalPages',
        (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(progress.value, closeTo(80 / 320, 0.0001));
    });

    testWidgets('LinearProgressIndicator handles totalPages = 0 gracefully',
        (tester) async {
      // Production code: `book.totalPages > 0 ? currentPage / totalPages : 0`
      // — guards against div-by-zero. Lock that in so a future "improvement"
      // doesn't introduce a NaN.
      await tester.pumpWidget(_wrap(const PdfCard(book: _zeroPagesBook)));
      await tester.pump();
      final progress = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(progress.value, 0.0);
    });

    testWidgets('onTap callback fires on card tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        PdfCard(book: _readingBook, onTap: () => taps++),
      ));
      await tester.pump();
      // Tap on the title — anywhere inside the GestureDetector should work.
      await tester.tap(find.text('The Pragmatic Programmer'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onTap is null-safe — no callback wired = no crash',
        (tester) async {
      await tester.pumpWidget(_wrap(const PdfCard(book: _readingBook)));
      await tester.pump();
      // Tap on the title — should not throw even with null onTap.
      await tester.tap(find.text('The Pragmatic Programmer'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('skips thumbnail provider read when link is empty',
        (tester) async {
      // Don't override pdfThumbnailProvider — production code should not call
      // it when book.link is empty. If the override-free read crashed, this
      // test would surface the regression.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 380,
                child: const PdfCard(book: _emptyLinkBook),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Local Draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows spinner while thumbnail is loading', (tester) async {
      // Override with a pending Future that never resolves to keep us in
      // loading state. Use a Completer that we never complete.
      final pending = Completer<Uint8List?>();
      addTearDown(() {
        // Avoid pending-future leak warnings from the test harness.
        if (!pending.isCompleted) pending.complete(null);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pdfThumbnailProvider.overrideWith((ref, url) => pending.future),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                height: 380,
                child: const PdfCard(book: _readingBook),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Cover placeholder shows a CircularProgressIndicator while loading.
      // Distinguish from the LinearProgressIndicator (book progress bar).
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders unicode title without crashing', (tester) async {
      const unicode = BookModel(
        id: 'b9',
        title: '日本語のタイトル • 漢字',
        link: 'https://example.com/jp.pdf',
        totalPages: 100,
        currentPage: 50,
        progress: 50,
        status: 'reading',
        shelfId: 's1',
        ownerId: 'u1',
      );
      await tester.pumpWidget(_wrap(const PdfCard(book: unicode)));
      await tester.pump();
      expect(find.text('日本語のタイトル • 漢字'), findsOneWidget);
    });

    testWidgets('long titles ellipsize over 2 lines (does not overflow)',
        (tester) async {
      const long = BookModel(
        id: 'b10',
        title:
            'A Very Long Title That Will Definitely Overflow Two Lines Of Text Inside The Card',
        link: 'https://example.com/long.pdf',
        totalPages: 100,
        currentPage: 50,
        progress: 50,
        status: 'reading',
        shelfId: 's1',
        ownerId: 'u1',
      );
      await tester.pumpWidget(_wrap(const PdfCard(book: long)));
      await tester.pump();
      // Text widget's maxLines + ellipsis settings are wired correctly.
      final text = tester.widget<Text>(find.text(long.title));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      // No overflow exceptions.
      expect(tester.takeException(), isNull);
    });
  });
}
