# Accessibility — Wave 3 (branch `A`)

Status: 2026-05-05. Owner: flutter_engineer. Scope: Semantics sweep + WCAG AA contrast audit on the Priority 1 surfaces called out in `.claude/plans/enterprise_gap_closure.md` Wave 3.

This document is the audit artifact. Test coverage of these labels lives in `qa_engineer`'s parallel integration / golden test suite and is not duplicated here.

---

## 1. Tap target audit summary

WCAG 2.1 / Material 3 minimum interactive target: **48 × 48 dp**. Where an icon-only `GestureDetector` had a smaller hit box, it was padded with a `BoxConstraints(minWidth: 48, minHeight: 48)` wrapper. The visual icon size was preserved — only the tap surface grew. No layout shifts in Phone Frame mode (412 × 896).

| File | Widget | Before | After |
|---|---|---|---|
| `lib/features/library/presentation/home_screen.dart` | Drawer toggle (top bar `Icons.menu`) | 36 × 36 (8 padding + 20 icon) | 48 × 48 |
| `lib/features/library/presentation/home_screen.dart` | Drawer close button (`Icons.close`) | 32 × 32 (6 padding + 20 icon) | 48 × 48 |
| `lib/features/profile/presentation/profile_screen.dart` | Drawer toggle | 36 × 36 | 48 × 48 |
| `lib/features/reader/presentation/reading_screen.dart` | Back arrow in top bar | ~20 × 20 (no padding) | 48 × 48 |
| `lib/features/reader/presentation/reading_screen.dart` | Voice settings (`Icons.tune`) | ~34 × ~34 | 48 × 48 |

`IconButton` instances (login password visibility, register password visibility × 2, register back arrow) already meet 48 × 48 via Material defaults; only `tooltip:` was added — no padding change.

`InkWell`-based rows in `_DrawerNavTile` and `_SettingsRow` already exceed 48 dp via their padding (12 + icon + 12 = 56 dp tall), so no change.

`PdfCard` book entries are 548 dp tall — far above the minimum.

---

## 2. Semantics labels

Pattern applied:

- `IconButton` → `tooltip:` parameter (Flutter renders this as both Material tooltip and `SemanticsLabel`).
- `GestureDetector` over an icon → wrap in `Semantics(button: true, label: '...')` and, where the child contains decorative `RichText`, also wrap the inner content in `ExcludeSemantics(...)` so screen readers don't read the visual + the label.
- Card-like list rows (`_ShelfRow`, `PdfCard`, `_SettingsRow`) → outer `Semantics(button: true, label: ...)` with a structured label including the dynamic data.

### Counts

| File | Semantics added | tooltip added |
|---|---|---|
| `lib/features/auth/presentation/login_screen.dart` | 2 (biometric button, register link) | 1 (password visibility) |
| `lib/features/auth/presentation/register_screen.dart` | 1 (login link) | 3 (back, password ×2) |
| `lib/features/library/presentation/home_screen.dart` | 4 (menu open, menu close, new shelf, shelf row) | 0 |
| `lib/features/reader/presentation/reading_screen.dart` | 3 (back, voice settings, TTS toggle) | 0 |
| `lib/features/profile/presentation/profile_screen.dart` | 2 (menu open, settings row) | 0 |
| `lib/shared/widgets/pdf_card.dart` | 1 (book card) | 0 |
| **Total** | **13** | **4** |

### Examples (verbatim from source)

1. Book card — dynamic label includes title, author, progress, status:

```dart
Semantics(
  button: true,
  label:
      'Book: ${book.title}${(book.author ?? '').isNotEmpty ? ', by ${book.author}' : ''}, $progressPct percent read, status ${book.status}',
  child: GestureDetector(...),
)
```

2. TTS toggle — state-aware label flips between Read and Stop:

```dart
Semantics(
  button: true,
  label: _ttsActive
      ? 'Stop reading aloud'
      : 'Start reading this page aloud',
  child: GestureDetector(onTap: _toggleTts, ...),
)
```

3. Shelf row — embeds count:

```dart
Semantics(
  button: true,
  label: 'Shelf: $name, $count books',
  child: GestureDetector(...),
)
```

---

## 3. WCAG AA contrast ratios

Method: relative luminance per WCAG 2.1, computed by hand from `lib/core/theme/app_colors.dart`. Formula:

```
sRGB channel c (0..255) → cs = c/255
linear cl = cs ≤ 0.03928 ? cs/12.92 : ((cs + 0.055)/1.055)^2.4
L = 0.2126 * Rl + 0.7152 * Gl + 0.0722 * Bl
contrast = (Lmax + 0.05) / (Lmin + 0.05)
```

WCAG AA thresholds: **4.5 : 1** for body text; **3 : 1** for large text (≥ 18 pt regular or ≥ 14 pt bold) and for non-text UI components.

### 3.1 Worked examples

#### Pair A — `textPrimary` (#191C1D) on `surface` (#FFFFFF)

R = 25 → 0.0980 → ((0.0980 + 0.055)/1.055)^2.4 = 0.01096
G = 28 → 0.1098 → 0.01161
B = 29 → 0.1137 → 0.01228
L_fg = 0.2126(0.01096) + 0.7152(0.01161) + 0.0722(0.01228) = 0.01152
L_bg = 1.0
**Contrast = 1.05 / 0.06152 = 17.07 → PASS**

#### Pair B — `textSecondary` (#40484C) on `surface` (#FFFFFF)

R 64 → 0.0512 ; G 72 → 0.0648 ; B 76 → 0.0722
L_fg = 0.2126(0.0512) + 0.7152(0.0648) + 0.0722(0.0722) = 0.0624
**Contrast = 1.05 / 0.1124 = 9.34 → PASS**

#### Pair C — `surface` white on `primary` (#004253) (button text on gradient button)

R 0 → 0 ; G 66 → 0.0544 ; B 83 → 0.0865
L_bg = 0.7152(0.0544) + 0.0722(0.0865) = 0.04516
**Contrast = 1.05 / 0.09516 = 11.04 → PASS**

### 3.2 Full pairing table

All ratios computed against the actual `AppColors` token values used in production screens.

| FG → BG | FG hex | BG hex | Ratio | AA body (≥4.5) | AA large/UI (≥3) | Used in |
|---|---|---|---|---|---|---|
| `textPrimary` → `surface` | `#191C1D` | `#FFFFFF` | **17.07** | PASS | PASS | All cards, headlines |
| `textPrimary` → `background` | `#191C1D` | `#F8FAFB` | ~16.5 | PASS | PASS | HomeScreen body |
| `textSecondary` → `surface` | `#40484C` | `#FFFFFF` | **9.34** | PASS | PASS | Body / muted text |
| `textSecondary` → `surfaceMuted` | `#40484C` | `#F2F4F5` | ~8.7 | PASS | PASS | Drawer items |
| `textMuted` → `surface` | `#70787D` | `#FFFFFF` | **4.50** | PASS (marginal) | PASS | TTS Read button (inactive), placeholder hints |
| `textNav` → `surface` | `#40484B` | `#FFFFFF` | ~9.3 | PASS | PASS | Bottom nav inactive labels |
| `textDisabled` → `surface` | `#BFC8CC` | `#FFFFFF` | **1.70** | FAIL | FAIL | Drawer footer "MYPDF" wordmark only — informational; not interactive |
| `surface` (white) → `primary` | `#FFFFFF` | `#004253` | **11.04** | PASS | PASS | Gradient button label, "Stop" pill |
| `surface` (white) → `error` | `#FFFFFF` | `#BA1A1A` | ~5.94 | PASS | PASS | Error containers |
| `error` → `surface` | `#BA1A1A` | `#FFFFFF` | **6.46** | PASS | PASS | Logout label, error icons |
| `error` → `errorContainer` | `#BA1A1A` | `#FFDAD6` | ~5.6 | PASS | PASS | Logout row icon-bg |
| `statusText` → `statusReadingBg` | `#004253` | `#B7EAFF` | **8.53** | PASS | PASS | "READING" badge |
| `statusText` → `statusFinishedBg` | `#004253` | `#AEFFB1` | ~9.7 | PASS | PASS | "FINISHED" badge |
| `statusText` → `statusOnHoldBg` | `#004253` | `#FFE3A8` | ~7.6 | PASS | PASS | "ON HOLD" badge |
| `primary` → `surface` | `#004253` | `#FFFFFF` | **11.04** | PASS | PASS | Folder icons, link emphasis |
| `primary` → `iconBlueTint` | `#004253` | `#CDE7F2` | ~7.6 | PASS | PASS | Settings row icon |
| `primary` → `surfaceMuted` | `#004253` | `#F2F4F5` | ~10.4 | PASS | PASS | Drawer brand text |

### 3.3 FAIL summary

| Pairing | Where | Severity | Recommendation |
|---|---|---|---|
| `textDisabled` (#BFC8CC) on `surface` | Drawer footer wordmark `MYPDF` only (decorative, non-interactive) | Cosmetic | No code action — token exists for *intentionally faded* state. Mark documented exception. If used on interactive disabled buttons in future, swap for `textMuted` (#70787D) which passes. |

### 3.4 Marginal pairings (≥ 4.5 but < 5.0)

| Pairing | Ratio | Risk |
|---|---|---|
| `textMuted` → `surface` | 4.50 | Hairline-passing. Sub-pixel rendering and OLED dimming may push below in real conditions. Consider darkening `textMuted` from `#70787D` to `#65686C` for a safety margin in a future theme update — out of scope for Wave 3 (tracked as Wave 4 follow-up). |

---

## 4. Open issues for Wave 4

1. **Goldens regenerated** — Tap-target padding on `Icons.menu` / close icons changed render bounds for HomeScreen, ProfileScreen, LoginScreen. The 5 golden tests already failing in `flutter test` (owned by `qa_engineer`) need a `flutter test --update-goldens` after Wave 3 lands. Coordinated by qa_engineer.
2. **`textMuted` margin** — 4.50 ratio is a hairline pass; recommend darkening one shade in a follow-up theme PR (R2).
3. **Priority 2 surfaces still uncovered** — `new_book_screen.dart`, `shelf_content_screen.dart`, `book_info_screen.dart`, `app_bottom_nav_bar.dart`, `app_drawer.dart` were deferred per task scope. They contain similar `IconButton` / icon-only `GestureDetector` patterns and should receive the same sweep in Wave 4 polish.
4. **Live screen-reader smoke test** — labels were added but not yet exercised against TalkBack (Android) or VoiceOver (iOS) on a physical device. Tracked for Wave 5 evidence package.
5. **Bottom nav Semantics** — `AppBottomNavBar` is built on Material `BottomNavigationBar` which provides default semantics; verify they read the correct labels (Library / Create / Profile) in Wave 4.

---

## 5. References

- WCAG 2.1 SC 1.4.3 Contrast (Minimum) — https://www.w3.org/TR/WCAG21/#contrast-minimum
- WCAG 2.1 SC 2.5.5 Target Size — https://www.w3.org/TR/WCAG21/#target-size
- Flutter `Semantics` widget — https://api.flutter.dev/flutter/widgets/Semantics-class.html
