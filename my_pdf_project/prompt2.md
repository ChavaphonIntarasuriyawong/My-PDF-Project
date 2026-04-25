# CLAUDE.md — MyPDF Project Blueprint

> **Read this file completely before writing any code.**
> This is the single source of truth for all agents working on this project.

---

## 📱 Project Overview

| Field | Value |
|---|---|
| **App Name** | MyPDF |
| **Type** | Flutter + Firebase mobile app |
| **Platform** | Android (primary) |
| **Purpose** | PDF reading progress tracker — users save PDF links, organize into bookshelves, track reading progress manually, and write notes |

---

## 🎨 Step 0: Read Figma Design FIRST

Before writing any code, use the **Figma MCP tool** to extract the design:

```
File URL : https://www.figma.com/design/TOKgyB73dnzi2TAUXAI7bi/Untitled?node-id=0-1&m=dev&t=fovuyN9wdcz9eZYY-1
```

### Screen Node IDs (fetch each one with get_design_context)

| Screen | Node ID |
|---|---|
| Login | `6:1503` |
| Register | `6:1533` |
| Library Dashboard (Home) | `6:1715` |
| Shelf Content | `6:2268` |
| Add PDF Link | `6:1582` |
| PDF Reader (Read-Only + Progress) | `6:1944` |
| PDF Reader + Notes View | `6:1971` |
| Create/Edit Note | `6:2050` |
| Profile | `6:2503` |
| Edit Personal Info | `6:2574` |
| Side Menu | `6:2371` |

### Modals

| Modal | Node ID |
|---|---|
| Creating New Shelf | `6:1859` |
| Edit Shelf Name | `6:1882` |
| Delete Shelf | `6:1903` |
| Edit PDF Link Name | `6:1444` |
| Move PDF Link | `6:1465` |
| Choosing Status | `6:1484` |
| Delete PDF Link | `6:1917` |

Extract and save as `design_tokens.md`:
1. Color palette — exact hex values
2. Typography — font family, sizes, weights for each text style
3. All reusable components (buttons, cards, inputs, bottom nav, modals)
4. Spacing and padding patterns

**Do NOT write any code until `design_tokens.md` is complete.**

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (latest stable) |
| State Management | Riverpod 2.x with `@riverpod` code generation |
| Navigation | GoRouter with auth guard |
| Backend | Firebase Auth + Firestore + Firebase Storage |
| Local Cache | Hive (offline-first support) |
| PDF Viewer | `flutter_pdfview` — mobile only, renders PDF from URL/file |
| PDF Text Extraction | `flutter_pdf_text` — extract text content from PDF |
| Text-to-Speech | `flutter_tts` — read PDF text aloud |
| Crash Reporting | Firebase Crashlytics |

---

## 🏛️ Architecture — Clean Architecture (NON-NEGOTIABLE)

```
lib/
├── core/
│   ├── theme/          ← AppColors, AppTypography  (from Figma tokens)
│   ├── constants/      ← AppRoutes, AppStrings
│   ├── errors/         ← Failure, AppException
│   └── utils/          ← validators, extensions
├── features/
│   ├── auth/
│   │   ├── data/       ← FirebaseAuthDataSource, AuthRepositoryImpl
│   │   ├── domain/     ← AuthRepository (abstract), LoginUseCase, RegisterUseCase
│   │   └── presentation/ ← LoginScreen, RegisterScreen, AuthController
│   ├── library/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/ ← HomeScreen, BookshelfContentScreen, NewBookScreen, BookInfoScreen
│   ├── reader/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/ ← ReadingScreen, NoteScreen
│   └── profile/
│       ├── data/
│       ├── domain/
│       └── presentation/ ← ProfileScreen, EditProfileScreen
└── shared/
    └── widgets/        ← PdfCard, StatusBadge, BottomNavBar, AppModal
```

### ⚠️ Domain Layer Rules
- **ZERO** `import 'package:flutter/...'` in `domain/`
- **ZERO** `import 'package:firebase_...'` in `domain/`
- Domain uses only: `Either`, `Failure`, plain Dart models
- All Firebase logic lives in `data/` layer only

---

## 📋 Screens (10 total)

| Screen | Route | Feature |
|---|---|---|
| Login | `/login` | Sign in with email/password |
| Register | `/register` | Create new account |
| Home | `/home` | List all bookshelves + books |
| Bookshelf Content | `/shelf/:id` | View books inside a shelf |
| New Book | `/book/new` | Add book with link + metadata |
| Book Info | `/book/:id` | View book detail + progress |
| Reading | `/book/:id/reading` | Update current page manually |
| Note | `/book/:id/note` | View/edit note for this book |
| Profile | `/profile` | View user info |
| Edit Profile | `/profile/edit` | Update name, avatar |

---

## 🔥 Backend — Firestore Structure

### Collections

```
users/{uid}
  - name: string
  - email: string
  - avatarUrl: string

bookshelves/{shelfId}
  - name: string
  - ownerId: string (uid)
  - createdAt: timestamp

books/{bookId}
  - title: string
  - link: string          ← URL to PDF (user pastes link)
  - coverUrl: string
  - totalPages: int
  - currentPage: int
  - progress: double      ← currentPage / totalPages * 100
  - status: string        ← "reading" | "on_hold" | "finished"
  - shelfId: string
  - ownerId: string
  - lastReadAt: timestamp ← for auto-jump

notes/{noteId}
  - bookId: string
  - content: string       ← short freeform note for the whole book
  - updatedAt: timestamp
```

### Key Backend Logic

- **CRUD** Account, Book, Bookshelf, Note
- **Reading Progress**: user inputs `currentPage` → app calculates `progress = currentPage / totalPages * 100`
- **Auto-save last page**: save `currentPage` + `lastReadAt` on every update
- **Auto-jump**: when opening a book, navigate to `lastReadAt` page automatically

---

## 🧱 Implementation Order

Follow this order exactly — do not skip ahead:

```
1. Read Figma → save design_tokens.md
2. Set up Flutter project structure + theme (AppColors, AppTypography from Figma)
3. Firebase setup (Auth, Firestore, Crashlytics)
4. Auth flow: Login + Register screens → Firebase Auth
5. Home + Bookshelf screens → Firestore CRUD (Bookshelf, Book)
6. New Book + Book Info screens → Add/view book + progress display
7. Reading screen → manual page input + progress calculation
8. Note screen → create/edit note per book
9. Profile + Edit Profile screens
10. Polish: loading states, error handling, empty states
```

---

## ✅ Definition of Done (per screen)

- [ ] Matches Figma design (colors, fonts, spacing)
- [ ] Riverpod state management wired
- [ ] Firebase operations working
- [ ] Error states handled (show snackbar/modal)
- [ ] Loading states shown (shimmer or CircularProgressIndicator)
- [ ] GoRouter navigation correct

---

## 🚫 Common Mistakes — Avoid These

- Do NOT use `setState` — use Riverpod only
- Do NOT put Firebase calls directly in widgets — go through repository
- Do NOT hardcode colors/fonts — use `AppColors` and `AppTypography`
- Do NOT start coding before reading Figma design tokens
- Do NOT use `Navigator.push` — use GoRouter only
