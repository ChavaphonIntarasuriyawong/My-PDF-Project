# MyPDF Design Tokens

Extracted from Figma: https://www.figma.com/design/TOKgyB73dnzi2TAUXAI7bi/

---

## Screens

| Flutter Route | Figma Frame | Node ID |
|---|---|---|
| `/login` | Auth - Login (Email Only) | `6:1503` |
| `/register` | Auth - Register (Email Only) | `6:1533` |
| `/home` | Library Dashboard | `6:1715` |
| `/shelf/:id` | Shelf Content | `6:2268` |
| `/book/new` | Add PDF Link (Direct URL) | `6:1582` |
| `/book/new` (error) | Add PDF Link (If error) | `6:1647` |
| `/book/:id` | (via Book Info from shelf) | — |
| `/book/:id/reading` | Read-Only PDF Viewer with Progress | `6:1944` |
| `/book/:id/reading` (full) | Full PDF Reader & Notes View | `6:1971` |
| `/book/:id/note` | Create/Edit Note - PDF Reader | `6:2050` |
| `/profile` | Profile | `6:2503` |
| `/profile/edit` | Edit Personal Information | `6:2574` |

**Modals / overlays (node IDs):**
- Creating New Shelf: `6:1859`
- Edit Shelf Name: `6:1882`
- Deleting Shelf: `6:1903`
- Deleting PDF Link: `6:1917`
- Edit PDF Link Name: `6:1444`
- Move PDF Link: `6:1465`
- Choosing Status: `6:1484`
- Modal Shelf Menu: `6:1931`
- Modal PDF Reader Menu: `6:1937`
- Floating Action Button: `6:1855`

---

## Color Palette

```dart
// AppColors
static const Color background     = Color(0xFFF8FAFB);  // page background
static const Color surface        = Color(0xFFFFFFFF);  // card/sheet
static const Color surfaceMuted   = Color(0xFFF2F4F5);  // input bg, shimmer, divider
static const Color primary        = Color(0xFF004253);  // brand teal — headings, active states, progress
static const Color primaryLight   = Color(0xFF005B71);  // gradient end
static const Color textPrimary    = Color(0xFF191C1D);  // card titles, strong labels
static const Color textSecondary  = Color(0xFF40484C);  // body text, labels
static const Color textMuted      = Color(0xFF70787D);  // placeholder
static const Color textNav        = Color(0xFF40484B);  // inactive nav labels
static const Color textDisabled   = Color(0xFFBFC8CC);  // section meta labels
static const Color progressTrack  = Color(0xFFE6E8E9);  // progress bar bg
static const Color borderSubtle   = Color(0x4DBFC8CC);  // ~0.3 opacity
static const Color borderNav      = Color(0x26BFC8CC);  // ~0.15 opacity

// Status badges
static const Color statusReadingBg   = Color(0xFFB7EAFF);
static const Color statusFinishedBg  = Color(0xFFAEFFB1);
static const Color statusOnHoldBg    = Color(0xFFFFE3A8);
static const Color statusText        = Color(0xFF004253);  // all badge text

// Error / destructive
static const Color error             = Color(0xFFBA1A1A);
static const Color errorContainer    = Color(0xFFFFDAD6);

// Icon tints
static const Color iconBlueTint      = Color(0xFFCDE7F2);

// Gradients
// Primary button: LinearGradient(44.99°, #004253 → #005B71)
```

---

## Typography

Fonts: **Manrope** (headings/numbers/buttons) + **Inter** (body/labels/captions)

```dart
// AppTypography

// --- Manrope ---
static const TextStyle displayLarge = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w800,
  fontSize: 36, height: 1.11,  // stat numbers
  color: AppColors.primary,
);
static const TextStyle headlineLarge = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w700,
  fontSize: 30, letterSpacing: -0.75, height: 1.2,
  color: AppColors.primary,
);
static const TextStyle headlineMedium = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w700,
  fontSize: 24, letterSpacing: -0.6, height: 1.33,
  color: AppColors.primary,
);
static const TextStyle titleLarge = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w700,
  fontSize: 18, letterSpacing: -0.9, height: 1.56,
  color: AppColors.primary,           // app bar logo
);
static const TextStyle titleMedium = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w700,
  fontSize: 16, height: 1.5,
  color: AppColors.textPrimary,       // card/section headings
);
static const TextStyle labelButton = TextStyle(
  fontFamily: 'Manrope', fontWeight: FontWeight.w700,
  fontSize: 16, height: 1.5,
  color: Colors.white,
);

// --- Inter ---
static const TextStyle bodyLarge = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w400,
  fontSize: 16, height: 1.5,
  color: AppColors.textSecondary,
);
static const TextStyle bodyMedium = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w400,
  fontSize: 14, height: 1.43,
  color: AppColors.textSecondary,
);
static const TextStyle bodySmall = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w400,
  fontSize: 12, height: 1.33,
  color: AppColors.textSecondary,
);
static const TextStyle labelLarge = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w500,
  fontSize: 16, height: 1.5,
  color: AppColors.textPrimary,       // list item labels
);
static const TextStyle labelMedium = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w600,
  fontSize: 16, height: 1.5,
  color: AppColors.textPrimary,       // settings row labels
);
static const TextStyle labelSmall = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w500,
  fontSize: 11, letterSpacing: 0.55, height: 1.5,
  color: AppColors.textSecondary,     // input label uppercase
);
static const TextStyle captionBold = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w700,
  fontSize: 10, height: 1.5,
  color: AppColors.primary,           // progress % text
);
static const TextStyle captionRegular = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w400,
  fontSize: 10, letterSpacing: 0.5, height: 1.5,
  color: AppColors.textSecondary,     // "Page X of Y" uppercase
);
static const TextStyle badgeLabel = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w600,
  fontSize: 10, height: 1.5,
  color: AppColors.statusText,        // status badge text
);
static const TextStyle sectionMeta = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w600,
  fontSize: 12, letterSpacing: 1.2, height: 1.33,
  color: AppColors.textDisabled,      // "ACCOUNT SETTINGS" uppercase
);
static const TextStyle greeting = TextStyle(
  fontFamily: 'Inter', fontWeight: FontWeight.w400,
  fontSize: 16, letterSpacing: 0.8, height: 1.5,
  color: AppColors.textSecondary,     // "GOOD MORNING, ..." uppercase
);
```

---

## Spacing & Layout

```
Screen horizontal padding : 24px
Section vertical gap       : 48px
Card internal padding      : 16px
Component gap (tight)      : 8px
Component gap (medium)     : 16px
Component gap (loose)      : 24px, 32px
```

---

## Border Radius

```
Page card / sheet          : 8px
Primary CTA button         : 12px
Input field                : 4px
Status badge               : 2px
Settings menu container    : 16px
Settings row               : 8px
Icon tint bg (small)       : 4px
Bottom nav active pill     : 8px
PDF cover image container  : 8px
```

---

## Elevation / Shadow

```
Auth card shadow   : 0px 8px 24px 0px rgba(25,28,29,0.04)
Primary button     : 0px 10px 15px -3px rgba(0,0,0,0.1), 0px 4px 6px -4px rgba(0,0,0,0.1)
Bottom nav shadow  : 0px -8px 12px rgba(25,28,29,0.04) (drop shadow upward)
```

---

## Components

### TopAppBar
- Background: `#f8fafb`, sticky
- Padding: 24px h / 16px v
- Logo: "MYPDF" Manrope Bold 18px `#004253`, tracking -0.9px
- Left: hamburger icon + logo text
- Divider below: `#f2f4f5` 1px line (Profile screen variant)

### BottomNavBar
- 3 tabs: Library | Create | Profile
- Background: `rgba(248,250,251,0.8)` with `backdrop-filter: blur(12px)`
- Border top: 1px `rgba(191,200,204,0.15)`
- Drop shadow: upward 0px -8px 12px rgba(25,28,29,0.04)
- Padding: 13px top / 24px bottom (safe area) / 31.61px horizontal
- Tab gap: 31.2px
- Active tab: `#004253` rounded pill (8px), white icon + white label
- Inactive tab: transparent, `#40484b` icon + label
- Nav label: Inter Medium 11px, tracking 0.55px, UPPERCASE

### PrimaryButton (CTA)
- Gradient: `LinearGradient(begin: Alignment(-0.82, -1), end: Alignment(0.82, 1), colors: [#004253, #005B71])`
- Border radius: 12px
- Padding: 16px vertical, full width
- Text: Manrope Bold 16px white, centered
- Shadow: 0px 10px 15px -3px rgba(0,0,0,0.1)

### InputField
- Background: `#f2f4f5`
- Border radius: 4px
- Padding: 16px h / 14px v
- Label: Inter Medium 11px tracking 0.55px UPPERCASE `#40484c`, positioned above input
- Placeholder: Inter Regular 16px `#70787d`

### PdfCard
- Background: white, radius 8px
- Cover image: top area ~413px tall, radius 8px, `#f2f4f5` placeholder bg
- PDF badge overlay: top-right, blur backdrop `rgba(225,227,228,0.7)`, "PDF" label
- Title: Manrope Bold 16px `#191c1d`, 16px from left/right
- Author + year: Inter Regular 12px `#40484c`
- Status badge: inline with author
- Progress row: "Page X of Y" caption + percentage bold
- Progress bar: 4px height, `#e6e8e9` track, `#004253` fill, radius 12px

### StatusBadge
- Radius: 2px
- Padding: 8px h / 2px v
- Text: Inter SemiBold 10px UPPERCASE `#004253`
- Backgrounds:
  - reading  → `#b7eaff`
  - finished → `#aeffb1`
  - on_hold  → `#ffe3a8`

### ShelfRow
- Background: white, radius 8px, padding 16px
- Icon: 21.5x16px shelf icon `#40484c`
- Label: Inter Medium 16px `#191c1d`
- Count: Inter Regular 12px `#40484c`, right-aligned
- "New Shelf" row: dashed border `rgba(191,200,204,0.3)`, padding 17px, icon + "NEW SHELF" label uppercase

### StatCard (Profile)
- Background: white, radius 8px, padding 24px
- Number: Manrope ExtraBold 36px `#004253`
- Label: Inter SemiBold 12px tracking 1.2px UPPERCASE `#40484c`

### ProfileHeader
- Name: Manrope Bold 30px `#004253`, centered
- Email: Inter Regular 14px `#40484c`, centered

### SettingsMenuGroup
- Container: `#f2f4f5` bg, radius 16px, padding 8px, gap 4px between rows
- Row: white bg, radius 8px, padding 16px
- Icon bg: 40x40 rounded 4px (blue tint `#cde7f2` for info, red `#ffdad6` for logout)
- Label: Inter SemiBold 16px `#191c1d` (logout row: `#ba1a1a`)
- Chevron: right side for navigable rows

---

## Auth Screen (Login/Register)

- Page bg: `#f8fafb`
- Card: white, radius 8px, shadow `0px 8px 24px 0px rgba(25,28,29,0.04)`, padding 32px
- No nav shell (transactional screen — "Destination Rule")
- Card centered vertically with large padding top/bottom (~193px)
- Heading: Manrope Bold 24px `#004253`
- Subtitle: Inter Regular 14px `#40484c`
- Footer link: Inter Regular 14px `#40484c` + Bold span `#004253` for action

---

## Gradient Definition (Flutter)

```dart
const LinearGradient primaryGradient = LinearGradient(
  begin: Alignment(-0.82, -1.0),
  end: Alignment(0.82, 1.0),
  colors: [Color(0xFF004253), Color(0xFF005B71)],
);
```
