# CLAUDE.md — MyPDF Project Blueprint

> **Read this file completely before writing any code.**
> This is the single source of truth for all agents working on this project.

---

## 📱 Project Overview

| Field | Value |
|---|---|
| **App Name** | MyPDF |
| **Type** | Flutter + Firebase + Supabase mobile app |
| **Platform** | Android (primary) |
| **Purpose** | PDF reading progress tracker — users save PDF links, organize into bookshelves, track reading progress manually, and write notes |

---

## 🎨 Step 0: Read Figma Design FIRST

Before writing any code, use the **Figma MCP tool** to extract the design:

```
File URL : https://www.figma.com/design/TOKgyB73dnzi2TAUXAI7bi/Untitled?node-id=0-1&m=dev&t=f9VdgzTHPmdXtUOT-1
```

### Screen Node IDs (fetch each one with get_design_context)

| Screen | Node ID |
|---|---|
| Login | `17:126` |
| Register | `17:156` |
| Library Dashboard (Home) | `17:412` |
| Shelf Content | `17:823` |
| Add PDF Link | `17:211` |
| PDF Reader (Read-Only + Progress) | `17:636` |
| Profile | `17:1190` |
| Edit Personal Info | `17:1261` |
| Side Menu | `17:926` |

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
| Auth | Firebase Auth |
| Database | Firestore |
| PDF File Storage | Supabase Storage (`pdfs` bucket) |
| Local Cache | Hive (offline-first support) |
| PDF Viewer | `flutter_pdfview` — mobile only, renders PDF from URL/file |
| PDF Text Extraction | `flutter_pdf_text` — extract text content from PDF |
| Text-to-Speech | `flutter_tts` — read PDF text aloud |
| Crash Reporting | Firebase Crashlytics |

> **Firebase Storage is NOT used.** All PDF file uploads go to Supabase Storage.
> **No avatar feature.** Profile has no photo/avatar.

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
│   │   └── presentation/ ← HomeScreen, ShelfContentScreen, NewBookScreen, BookInfoScreen
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
- **ZERO** `import 'package:supabase_...'` in `domain/`
- Domain uses only: `Either`, `Failure`, plain Dart models
- All Firebase/Supabase logic lives in `data/` layer only

---

## 📋 Screens (9 total)

| Screen | Route | Feature |
|---|---|---|
| Login | `/login` | Sign in with email/password |
| Register | `/register` | Create new account |
| Home | `/home` | List all bookshelves + books |
| Bookshelf Content | `/shelf/:id` | View books inside a shelf |
| New Book | `/book/new` | Add book with link or upload PDF |
| Book Info | `/book/:id` | View book detail + progress |
| Reading | `/book/:id/reading` | PDF viewer + progress tracking |
| Note | `/book/:id/note` | View/edit note for this book |
| Profile | `/profile` | View user info + stats |
| Edit Profile | `/profile/edit` | Update name only (no avatar) |

---

## 🔥 Backend — Firestore Structure

### Collections

```
users/{uid}
  - name: string
  - email: string

bookshelves/{shelfId}
  - name: string
  - ownerId: string (uid)
  - createdAt: timestamp

books/{bookId}
  - title: string
  - link: string          ← URL to PDF (user pastes link OR Supabase public URL)
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

## ☁️ Supabase Storage — PDF Files

```
Bucket : pdfs   (public)
Path   : {uid}/{timestamp}.pdf
```

- Upload: `supabase.storage.from('pdfs').uploadBinary(path, bytes)`
- Public URL: `supabase.storage.from('pdfs').getPublicUrl(path)`
- Auth rule: users can only upload/delete under their own `{uid}/` prefix

### Key Backend Logic

- **CRUD** Account, Book, Bookshelf, Note
- **PDF Upload**: file bytes → Supabase Storage → public URL → stored as `link` in Firestore
- **Reading Progress**: user inputs `currentPage` → app calculates `progress = currentPage / totalPages * 100`
- **Auto-save last page**: save `currentPage` + `lastReadAt` on every update
- **Auto-jump**: when opening a book, navigate to `lastReadAt` page automatically

---

## 🧱 Implementation Order

Follow this order exactly — do not skip ahead:

```
1. Read Figma → save design_tokens.md
2. Set up Flutter project structure + theme (AppColors, AppTypography from Figma)
3. Firebase setup (Auth, Firestore, Crashlytics) + Supabase setup (Storage)
4. Auth flow: Login + Register screens → Firebase Auth
5. Home + Bookshelf screens → Firestore CRUD (Bookshelf, Book)
6. New Book screen → URL link OR file upload (Supabase) → save to Firestore
7. Book Info screen → view book + progress display
8. Reading screen → PDF viewer + progress calculation
9. Note screen → create/edit note per book
10. Profile + Edit Profile screens
11. Polish: loading states, error handling, empty states
```

---

## ✅ Definition of Done (per screen)

- [ ] Matches Figma design (colors, fonts, spacing)
- [ ] Riverpod state management wired
- [ ] Firebase/Supabase operations working
- [ ] Error states handled (show snackbar/modal)
- [ ] Loading states shown (shimmer or CircularProgressIndicator)
- [ ] GoRouter navigation correct

---

## 🚫 Common Mistakes — Avoid These

- Do NOT use `setState` — use Riverpod only
- Do NOT put Firebase/Supabase calls directly in widgets — go through repository
- Do NOT hardcode colors/fonts — use `AppColors` and `AppTypography`
- Do NOT start coding before reading Figma design tokens
- Do NOT use `Navigator.push` — use GoRouter only
- Do NOT use Firebase Storage — PDFs go to Supabase Storage only
- Do NOT add avatar/photo features — profile has name + email only
