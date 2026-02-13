# LIFE MANAGER — COMPREHENSIVE UI DESIGN GUIDE

> Use this guide whenever you transform or build any page.
> Every rule here is derived from the Finance Dashboard — the reference design.
> Goal: **Modern, clean, fast, attractive, consistent across light & dark themes.**

---

## TABLE OF CONTENTS

1. [Design Philosophy](#1-design-philosophy)
2. [Color System](#2-color-system)
3. [Dark & Light Theme Patterns](#3-dark--light-theme-patterns)
4. [Typography](#4-typography)
5. [Layout & Spacing](#5-layout--spacing)
6. [Card & Container Design](#6-card--container-design)
7. [Buttons & Actions](#7-buttons--actions)
8. [Icons & Iconography](#8-icons--iconography)
9. [Lists & Transactions](#9-lists--transactions)
10. [Accordions & Expandable Sections](#10-accordions--expandable-sections)
11. [Inputs & Forms](#11-inputs--forms) *(22 subsections)*
    - Form Layout Rules, Group Cards, Section/Field Labels
    - Standard InputDecoration, Full TextField, Hero Amount Input
    - Rich Dropdown, Simple Dropdown, Date/Time Pickers
    - Switch/Toggle, Segmented Selector, Checkbox, Radio
    - Slider, Choice/Filter Chips, Search Field
    - Multi-Line Text Area, Validation & Errors
    - Save/Submit Button, Complete Form Page Structure
12. [Dialogs & Bottom Sheets](#12-dialogs--bottom-sheets)
13. [Charts & Data Visualization](#13-charts--data-visualization)
14. [Animations & Transitions](#14-animations--transitions)
15. [Performance Rules](#15-performance-rules)
16. [Anti-Patterns (Never Do This)](#16-anti-patterns-never-do-this)
17. [Quick Reference Cheat Sheet](#17-quick-reference-cheat-sheet)

---

## 1. DESIGN PHILOSOPHY

| Principle | Meaning |
|-----------|---------|
| **Minimal & Modern** | No clutter. Every pixel earns its place. White space is a feature. |
| **Monochromatic + Gold** | Keep the palette tight. Gold is the ONLY accent color. |
| **Elevated, Not Bordered** | Use subtle shadows (light) or subtle opacity (dark) instead of borders. |
| **Fast & Lightweight** | No heavy gradients, no excessive animations, no runtime `withOpacity()`. |
| **Consistent Duality** | Every element must look great in BOTH light and dark themes. |
| **Hierarchy Through Weight** | Use font weight and size to create hierarchy, not color variety. |

### The Golden Rule
> **Gold (`#CDAF56`) is reserved for primary actions, selected states, and important accents. Overusing gold cheapens the design. When in doubt, use neutral colors.**

---

## 2. COLOR SYSTEM

### 2.1 Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `primaryGold` | `#CDAF56` | Primary actions, FABs, selected tabs, important accents |
| `primaryGoldVariant` | `#E1C877` | Hover states, lighter gold accents |

**Code references:**
- `AppColorSchemes.primaryGold` or `AppColors.gold`
- `AppColorSchemes.primaryGoldVariant`

### 2.2 Pre-Computed Gold Opacities (use these instead of `withOpacity()`)

| Token | Hex | Opacity | Usage |
|-------|-----|---------|-------|
| `AppColors.goldOpacity02` | `#33CDAF56` | 20% | Subtle gold tint backgrounds |
| `AppColors.goldOpacity03` | `#4DCDAF56` | 30% | Selected item backgrounds |
| `AppColors.goldOpacity05` | `#80CDAF56` | 50% | Prominent gold overlays |

### 2.3 Light Theme Colors

| Token | Hex | Usage |
|-------|-----|-------|
| Page background | `#F5F5F7` | Main scaffold background (subtle warm grey) |
| Card / container | `#FFFFFF` | All cards, containers, list items |
| Text primary | `#1E1E1E` (or `Colors.black87`) | Headings, primary labels |
| Text secondary | `Colors.black54` | Subtitles, descriptions, secondary info |
| Text tertiary | `Colors.black38` | Timestamps, hints, least important text |
| Divider | `Colors.black12` | Thin separators |
| Icon default | `Colors.black45` | Non-accent icons |

### 2.4 Dark Theme Colors

| Token | Hex | Usage |
|-------|-----|-------|
| Page background | Gradient: `#2A2D3A` → `#212529` → `#1A1D23` | Use `DarkGradient.wrap()` |
| Card / container | `Colors.white.withOpacity(0.04)` | All cards, containers |
| Text primary | `Colors.white` or `#E5E5E5` | Headings, primary labels |
| Text secondary | `Colors.white70` | Subtitles, descriptions |
| Text tertiary | `Colors.white38` | Timestamps, hints |
| Divider | `Colors.white10` | Thin separators |
| Icon default | `Colors.white54` | Non-accent icons |

### 2.5 Semantic Colors

| Token | Hex | Usage |
|-------|-----|-------|
| Success / Income | `#4CAF50` | Positive amounts, success states |
| Warning | `#FFA726` | Warnings, pending states |
| Error / Expense | `#EF5350` | Negative amounts, errors, destructive actions |
| Info | `#2196F3` | Informational badges |

### 2.6 ABSOLUTE COLOR RULES

```
NEVER use purple in dark mode.
NEVER use random colors — stick to this palette.
NEVER use Colors.grey directly — use the specific tokens above.
NEVER hard-code hex colors in UI files — use AppColors or AppColorSchemes.
NEVER use withOpacity() at runtime in build methods — use pre-computed constants.
```

---

## 3. DARK & LIGHT THEME PATTERNS

### 3.1 Theme Detection

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
```

### 3.2 Page Background

```dart
// In build() or _buildContent():
Scaffold(
  backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
  body: isDark ? DarkGradient.wrap(child: content) : content,
)
```

### 3.3 Card/Container Pattern (THE CORE PATTERN)

This is the single most important pattern. Use it for every card, container, and list item.

```dart
Container(
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.04)  // Subtle glass effect
        : Colors.white,                    // Clean white card
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  // ... content
)
```

**Key insight:** Dark mode uses transparency for depth. Light mode uses white + subtle shadow for elevation.

### 3.4 Semantic Tint Containers

For containers that represent a specific category (income, expense, status):

```dart
// Light theme: subtle color tint
// Dark theme: subtle white overlay
Container(
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.04)
        : semanticColor.withOpacity(0.04),  // e.g., Colors.green.withOpacity(0.04)
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

### 3.5 Selected/Active State

```dart
Container(
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.06)         // Slightly brighter
        : accentColor.withOpacity(0.06),          // Subtle tint
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isDark
          ? const Color(0xFFCDAF56).withOpacity(0.3)  // Gold hint
          : accentColor.withOpacity(0.2),
    ),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: accentColor.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

### 3.6 Text Color Mapping

| Purpose | Dark Theme | Light Theme |
|---------|-----------|-------------|
| Page title / heading | `Colors.white` | `Colors.black87` |
| Card title | `Colors.white` | `Colors.black87` |
| Card subtitle | `Colors.white70` | `Colors.black54` |
| Description / body | `Colors.white54` | `Colors.black45` |
| Timestamp / hint | `Colors.white38` | `Colors.black38` |
| Amount (positive) | `Color(0xFF4CAF50)` | `Color(0xFF4CAF50)` |
| Amount (negative) | `Color(0xFFEF5350)` | `Color(0xFFEF5350)` |

**Pattern:**

```dart
Text(
  'Card Title',
  style: TextStyle(
    color: isDark ? Colors.white : Colors.black87,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
)
```

---

## 4. TYPOGRAPHY

### 4.1 Font Family

- **Primary:** Inter (via `google_fonts`)
- **Fallback:** System default

### 4.2 Type Scale

| Role | Size | Weight | Letter Spacing | Usage |
|------|------|--------|---------------|-------|
| Display | 28-32px | w700 (Bold) | -0.5 | Page titles, large numbers |
| Title | 18-20px | w600 (SemiBold) | -0.3 | Section headers, card titles |
| Subtitle | 15-16px | w500 (Medium) | 0 | Card subtitles, secondary headers |
| Body | 14-15px | w400 (Regular) | 0 | Regular text, descriptions |
| Label | 12-13px | w500 (Medium) | 0.1 | Tags, badges, timestamps, button text |
| Caption | 10-11px | w400 (Regular) | 0.2 | Fine print, helper text |

### 4.3 Number Typography

For financial amounts and important numbers:

```dart
Text(
  '£1,234.56',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: isDark ? Colors.white : Colors.black87,
  ),
)
```

### 4.4 Text Overflow

ALWAYS handle text overflow. Never let text clip or cause RenderFlex errors.

```dart
// For single-line text:
Text(
  'Long transaction name',
  overflow: TextOverflow.ellipsis,
  maxLines: 1,
)

// For multi-line descriptions:
Text(
  'Description...',
  overflow: TextOverflow.ellipsis,
  maxLines: 2,
)

// For row layouts with flexible text:
Row(
  children: [
    Expanded(
      child: Text(
        'Transaction name',
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
    Text('£50.00'),  // Fixed-width amount
  ],
)
```

---

## 5. LAYOUT & SPACING

### 5.1 Spacing Constants

| Element | Value | Notes |
|---------|-------|-------|
| Screen horizontal padding | 20px | `EdgeInsets.symmetric(horizontal: 20)` |
| Section gap (vertical) | 16-20px | `SizedBox(height: 16)` between sections |
| Card internal padding | 16px | All sides |
| Between cards | 12px | Vertical gap |
| Between inline items | 8-12px | Horizontal gap in rows |
| Icon-to-text gap | 8px | Inside buttons, list items |
| Compact list item padding | `EdgeInsets.symmetric(horizontal: 16, vertical: 12)` | Transaction rows |

### 5.2 Border Radius

| Element | Radius |
|---------|--------|
| Cards, containers | 16px |
| Buttons | 16px |
| Input fields | 16px |
| Small chips / badges | 8-12px |
| Circular icons | 50% (use `CircleBorder` or large radius) |
| Bottom sheets | 24px (top only) |

### 5.3 Page Structure

```
Scaffold (background: light grey or transparent for dark)
├── AppBar (transparent, no elevation)
└── Body
    └── SingleChildScrollView / ListView
        ├── SizedBox(height: 8)           // Top breathing room
        ├── Hero Card (balance, summary)   // Primary info
        ├── SizedBox(height: 16)
        ├── Quick Actions Row              // Horizontal scroll or grid
        ├── SizedBox(height: 16)
        ├── Section Title + Content        // Repeatable pattern
        ├── SizedBox(height: 16)
        ├── List / Grid of items
        ├── SizedBox(height: 16)
        └── SizedBox(height: 100)          // Bottom safe area
```

### 5.4 Responsive Grid

For quick action buttons or category grids:

```dart
GridView.count(
  crossAxisCount: 4,          // 4 items per row
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  children: [...],
)
```

---

## 6. CARD & CONTAINER DESIGN

### 6.1 Standard Card

```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Title row
      Row(
        children: [
          Icon(Icons.icon, size: 20, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 8),
          Text('Section Title', style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          )),
        ],
      ),
      // Content...
    ],
  ),
)
```

### 6.2 Hero / Summary Card

For the main card at the top of a page (balance, stats):

```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Column(
    children: [
      Text('Total Balance', style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white54 : Colors.black45,
      )),
      const SizedBox(height: 4),
      Text('£12,345.67', style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: isDark ? Colors.white : Colors.black87,
      )),
    ],
  ),
)
```

### 6.3 Stat Chip / Summary Chip

Small inline stat indicators:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.04)
        : semanticColor.withOpacity(0.04),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark
              ? semanticColor.withOpacity(0.2)
              : semanticColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: semanticColor),
      ),
      const SizedBox(width: 8),
      Text(value, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: semanticColor,
      )),
    ],
  ),
)
```

### 6.4 Empty State

When there is no data to display:

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.inbox_rounded,
        size: 48,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
      const SizedBox(height: 12),
      Text(
        'No transactions yet',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Tap + to add your first transaction',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white24 : Colors.black26,
        ),
      ),
    ],
  ),
)
```

---

## 7. BUTTONS & ACTIONS

### 7.1 Primary Button (Gold)

Use sparingly — only for the MAIN action on a screen.

```dart
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFCDAF56),
    foregroundColor: const Color(0xFF1E1E1E),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w600)),
)
```

### 7.2 Secondary / Outline Button

For secondary actions:

```dart
OutlinedButton(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: isDark ? Colors.white70 : Colors.black54,
    side: BorderSide(
      color: isDark ? Colors.white24 : Colors.black12,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  child: const Text('Cancel'),
)
```

### 7.3 Quick Action Button (Icon + Label)

For grid/row of quick actions:

```dart
GestureDetector(
  onTap: () {},
  child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isDark ? null : [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFCDAF56).withOpacity(0.15)
                : const Color(0xFFCDAF56).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.add, size: 22, color: const Color(0xFFCDAF56)),
        ),
        const SizedBox(height: 8),
        Text('Add', style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white70 : const Color(0xFF2A2A2A),
        )),
      ],
    ),
  ),
)
```

### 7.4 Text Button / Link

```dart
TextButton(
  onPressed: () {},
  child: Text(
    'View All',
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: const Color(0xFFCDAF56),
    ),
  ),
)
```

### 7.5 Destructive Button

```dart
TextButton(
  onPressed: () {},
  child: Text(
    'Delete',
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: const Color(0xFFEF5350),
    ),
  ),
)
```

### 7.6 FAB (Floating Action Button)

```dart
FloatingActionButton(
  backgroundColor: const Color(0xFFCDAF56),
  foregroundColor: const Color(0xFF1E1E1E),
  elevation: 4,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  onPressed: () {},
  child: const Icon(Icons.add),
)
```

---

## 8. ICONS & ICONOGRAPHY

### 8.1 Icon Rules

- Use `_rounded` variants of Material Icons (e.g., `Icons.add_rounded`)
- Default size: **20-22px** for inline, **24px** for action buttons, **48px** for empty states
- Color: follow the text color hierarchy (see Section 3.6)
- NEVER use colored icons randomly — icons inherit their parent's semantic color

### 8.2 Icon Container (for category icons, action icons)

```dart
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: isDark
        ? categoryColor.withOpacity(0.2)
        : categoryColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Icon(
    categoryIcon,
    size: 20,
    color: categoryColor,
  ),
)
```

### 8.3 Circular Avatar Icon

For user avatars or large category representations:

```dart
CircleAvatar(
  radius: 20,
  backgroundColor: isDark
      ? categoryColor.withOpacity(0.2)
      : categoryColor.withOpacity(0.1),
  child: Icon(
    categoryIcon,
    size: 20,
    color: categoryColor,
  ),
)
```

---

## 9. LISTS & TRANSACTIONS

### 9.1 Transaction List Item

The standard pattern for any list item (transactions, habits, tasks):

```dart
Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Row(
    children: [
      // Leading: Category icon
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? categoryColor.withOpacity(0.2)
              : categoryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(categoryIcon, size: 20, color: categoryColor),
      ),
      const SizedBox(width: 12),
      // Middle: Title + subtitle
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction Name', style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            )),
            const SizedBox(height: 2),
            Text('Category · 2:30 PM', style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            )),
          ],
        ),
      ),
      // Trailing: Amount
      Text(
        '+£50.00',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isIncome ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
        ),
      ),
    ],
  ),
)
```

### 9.2 Grouped List with Date Header

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // Date header
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text('Today, Feb 8', style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.black45,
      )),
    ),
    // Transaction items
    ...transactions.map((t) => _buildTransactionItem(t)),
  ],
)
```

### 9.3 Dividers

Use sparingly. Prefer spacing over dividers.

```dart
Divider(
  height: 1,
  thickness: 0.5,
  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
)
```

---

## 10. ACCORDIONS & EXPANDABLE SECTIONS

### 10.1 Standard Accordion

```dart
GestureDetector(
  onTap: () => setState(() => _isExpanded = !_isExpanded),
  child: Container(
    decoration: BoxDecoration(
      color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: isDark ? null : [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        // Header (always visible)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.section_icon, size: 20,
                color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Section Title', style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                )),
              ),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
        // Expandable content
        if (_isExpanded) ...[
          Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ],
      ],
    ),
  ),
)
```

### 10.2 Accordion Animation

For smooth expansion, use `AnimatedCrossFade` or `AnimatedSize`:

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  child: _isExpanded ? expandedContent : const SizedBox.shrink(),
)
```

---

## 11. INPUTS & FORMS

> Forms are where users spend the most time. They must feel premium, fast, and intuitive.
> Every input follows a strict visual language: subtle background, thin border, gold focus ring.

### 11.1 Form Layout Rules

| Rule | Value |
|------|-------|
| Gap between fields | 20px (`SizedBox(height: 20)`) |
| Field group padding | 20px all sides |
| Field group border radius | 24px |
| Individual field border radius | 16px |
| Content padding inside fields | 16px horizontal, 16px vertical |
| Label-to-field gap | 10px |
| Always use | `crossAxisAlignment: CrossAxisAlignment.start` |

### 11.2 Form Field Container (Group Card)

Wrap related fields in a section card:

```dart
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.02),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionLabel('SECTION NAME'),  // Gold uppercase label
      const SizedBox(height: 20),
      // ...fields go here...
    ],
  ),
)
```

### 11.3 Section Label (Gold Uppercase)

Used at the top of every form field group:

```dart
Text(
  'SECTION NAME',
  style: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: Color(0xFFCDAF56),
    letterSpacing: 1.2,
  ),
)
```

### 11.4 Field Label (Above Each Input)

```dart
Text(
  'FIELD NAME',
  style: TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    color: isDark ? Colors.white38 : Colors.black38,
    letterSpacing: 1,
  ),
)
```

### 11.5 The Standard Input Decoration

This is the **universal InputDecoration** used for ALL text fields, dropdowns, and form fields:

```dart
InputDecoration(
  hintText: 'Placeholder...',
  hintStyle: TextStyle(
    color: isDark ? Colors.white10 : Colors.black12,
  ),
  prefixIcon: Icon(Icons.icon_rounded, size: 20, color: const Color(0xFFCDAF56)),
  filled: true,
  fillColor: isDark
      ? Colors.white.withOpacity(0.02)
      : Colors.black.withOpacity(0.01),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(
      color: Color(0xFFCDAF56),
      width: 1.5,
    ),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(
      color: Color(0xFFEF5350),
      width: 1.5,
    ),
  ),
)
```

**Key points:**
- `fillColor`: Near-invisible fill — `0.02` opacity in dark, `0.01` in light
- `enabledBorder`: Thin, near-invisible border — `0.05` opacity
- `focusedBorder`: Gold ring — `#CDAF56` at 1.5px width
- `errorBorder`: Red ring — `#EF5350` at 1.5px width
- `prefixIcon` color: Always gold (`#CDAF56`)
- `hintStyle` color: Very faint — `Colors.white10` dark / `Colors.black12` light

### 11.6 Full Text Field Pattern

Complete text field with label:

```dart
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  required bool isDark,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Field label
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      // Text field
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFFCDAF56),
              width: 1.5,
            ),
          ),
        ),
      ),
    ],
  );
}
```

### 11.7 Large Amount Input (Hero Input)

For primary numeric fields like transaction amounts — center-aligned, large font:

```dart
Container(
  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.02),
    borderRadius: BorderRadius.circular(32),
    border: Border.all(color: typeColor.withOpacity(0.2), width: 1.5),
  ),
  child: Column(
    children: [
      Text(
        'ENTER AMOUNT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: typeColor.withOpacity(0.7),
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          letterSpacing: -2,
        ),
        decoration: InputDecoration(
          prefixText: '£ ',
          prefixStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: typeColor.withOpacity(0.6),
          ),
          border: InputBorder.none,
          hintText: '0.00',
          hintStyle: TextStyle(
            color: isDark ? Colors.white12 : Colors.grey[300],
          ),
        ),
      ),
    ],
  ),
)
```

**Key points:**
- Border color matches the semantic type (red for expense, green for income, gold for transfer)
- Huge font (52px) for the amount — this is the hero element
- No standard input decoration — uses `InputBorder.none`
- Currency prefix is smaller (24px) and tinted

### 11.8 Dropdown (Full Pattern with Rich Items)

For dropdowns with icons and color indicators (categories, accounts):

```dart
Widget _buildDropdown({
  required String label,
  required List<Item> items,
  required Item? selectedItem,
  required Function(Item?) onChanged,
  required IconData prefixIcon,
  required bool isDark,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Field label
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<Item>(
        value: selectedItem,
        isExpanded: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFFCDAF56)),
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.02)
              : Colors.black.withOpacity(0.01),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item,
          child: Row(
            children: [
              // Item icon with color background
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 12),
              // Item name
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Optional trailing info (e.g., account balance)
              if (item.trailingText != null)
                Text(
                  item.trailingText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                ),
            ],
          ),
        )).toList(),
        onChanged: onChanged,
      ),
    ],
  );
}
```

**Key points:**
- `dropdownColor`: `#1A1D23` (dark) / `Colors.white` (light) — match the deepest dark tone
- `isExpanded: true` — always, prevents overflow
- `icon`: Use `keyboard_arrow_down_rounded`, not the default triangle
- Each dropdown item has an icon with colored background chip
- Trailing text (optional) for secondary info like balance
- Use `Expanded` + `overflow: TextOverflow.ellipsis` for item names

### 11.9 Simple Dropdown (Text-Only Items)

For basic dropdowns without icons:

```dart
DropdownButtonFormField<String>(
  value: selectedValue,
  isExpanded: true,
  icon: Icon(
    Icons.keyboard_arrow_down_rounded,
    color: isDark ? Colors.white38 : Colors.black38,
  ),
  dropdownColor: isDark ? const Color(0xFF1A1D23) : Colors.white,
  decoration: InputDecoration(
    labelText: 'Label',
    labelStyle: TextStyle(
      color: isDark ? Colors.white38 : Colors.black38,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: isDark
        ? Colors.white.withOpacity(0.02)
        : Colors.black.withOpacity(0.01),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
      ),
    ),
  ),
  items: options.map((o) => DropdownMenuItem(
    value: o,
    child: Text(o, style: TextStyle(
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    )),
  )).toList(),
  onChanged: (val) {},
)
```

### 11.10 Date & Time Picker Tiles

Tappable tiles that open system date/time pickers:

```dart
Widget _buildDateTimeTile({
  required String label,
  required String value,
  required IconData icon,
  required VoidCallback onTap,
  required bool isDark,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Field label
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white38 : Colors.black38,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 10),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.black.withOpacity(0.01),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFCDAF56)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
```

**Date & Time picker side by side:**

```dart
Row(
  children: [
    Expanded(
      child: _buildDateTimeTile(
        label: 'Date',
        value: DateFormat('MMM dd, yyyy').format(selectedDate),
        icon: Icons.calendar_today_rounded,
        onTap: () => _selectDate(context),
        isDark: isDark,
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: _buildDateTimeTile(
        label: 'Time',
        value: selectedTime.format(context),
        icon: Icons.access_time_rounded,
        onTap: () => _selectTime(context),
        isDark: isDark,
      ),
    ),
  ],
)
```

### 11.11 Date & Time Picker Theme Overrides

When calling `showDatePicker` or `showTimePicker`, theme them to match:

```dart
Future<void> _selectDate(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: isDark
              ? ColorScheme.dark(
                  primary: const Color(0xFFCDAF56),
                  onPrimary: Colors.black,
                  surface: const Color(0xFF2D3139),
                  onSurface: Colors.white,
                )
              : ColorScheme.light(
                  primary: const Color(0xFFCDAF56),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: const Color(0xFF1E1E1E),
                ),
        ),
        child: child!,
      );
    },
  );
  if (picked != null) setState(() => _selectedDate = picked);
}
```

### 11.12 Switch / Toggle (Modern Pattern)

Use `SwitchListTile` wrapped in a styled container:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.02)
        : Colors.black.withOpacity(0.01),
    borderRadius: BorderRadius.circular(16),
  ),
  child: SwitchListTile(
    title: Text(
      'Is Recurring',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
    ),
    subtitle: Text(
      'Repeat automatically',
      style: TextStyle(
        fontSize: 11,
        color: isDark ? Colors.white24 : Colors.black26,
      ),
    ),
    secondary: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFCDAF56).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.repeat_rounded, color: Color(0xFFCDAF56), size: 18),
    ),
    value: isEnabled,
    onChanged: (val) {
      HapticFeedback.lightImpact();
      onChanged(val);
    },
    activeColor: const Color(0xFFCDAF56),
    activeTrackColor: const Color(0xFFCDAF56).withOpacity(0.3),
    inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400],
    inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200],
    contentPadding: EdgeInsets.zero,
  ),
)
```

**Simple toggle (no container):**

```dart
Switch(
  value: isEnabled,
  onChanged: (v) => HapticFeedback.lightImpact(),
  activeColor: const Color(0xFFCDAF56),
  activeTrackColor: const Color(0xFFCDAF56).withOpacity(0.3),
  inactiveThumbColor: isDark ? Colors.white24 : Colors.grey[400],
  inactiveTrackColor: isDark ? Colors.white10 : Colors.grey[200],
)
```

### 11.13 Segmented / Type Selector

For mutually exclusive options (e.g., Expense / Income / Transfer):

```dart
Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.03)
        : Colors.black.withOpacity(0.02),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.05),
    ),
  ),
  child: Row(
    children: options.map((option) {
      final isSelected = selectedOption == option.value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(option.value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? option.color : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: option.color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] : [],
            ),
            child: Column(
              children: [
                Icon(
                  option.icon,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white24 : Colors.grey[400]),
                  size: 20,
                ),
                const SizedBox(height: 6),
                Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.grey[500]),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  ),
)
```

**Key points:**
- Each segment has its own semantic color (red, green, blue, gold)
- Selected segment gets: filled color + shadow + white text
- Unselected: transparent + faint text
- Use `AnimatedContainer` for smooth transitions (200ms)
- Always add `HapticFeedback.lightImpact()` on tap

### 11.14 Checkbox

```dart
Checkbox(
  value: isChecked,
  onChanged: (val) {
    HapticFeedback.lightImpact();
    onChanged(val);
  },
  activeColor: const Color(0xFFCDAF56),
  checkColor: const Color(0xFF1E1E1E),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  side: BorderSide(
    color: isDark ? Colors.white24 : Colors.black26,
    width: 1.5,
  ),
)
```

**Checkbox with label (list tile):**

```dart
CheckboxListTile(
  value: isChecked,
  onChanged: (val) {
    HapticFeedback.lightImpact();
    onChanged(val);
  },
  title: Text(label, style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white : Colors.black87,
  )),
  subtitle: subtitle != null ? Text(subtitle, style: TextStyle(
    fontSize: 12,
    color: isDark ? Colors.white38 : Colors.black38,
  )) : null,
  activeColor: const Color(0xFFCDAF56),
  checkColor: const Color(0xFF1E1E1E),
  controlAffinity: ListTileControlAffinity.leading,
  contentPadding: EdgeInsets.zero,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
)
```

### 11.15 Radio Buttons

```dart
RadioListTile<String>(
  value: optionValue,
  groupValue: selectedValue,
  onChanged: (val) {
    HapticFeedback.lightImpact();
    onChanged(val);
  },
  title: Text(label, style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white : Colors.black87,
  )),
  activeColor: const Color(0xFFCDAF56),
  contentPadding: EdgeInsets.zero,
)
```

### 11.16 Slider

```dart
SliderTheme(
  data: SliderThemeData(
    activeTrackColor: const Color(0xFFCDAF56),
    inactiveTrackColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
    thumbColor: const Color(0xFFCDAF56),
    overlayColor: const Color(0xFFCDAF56).withOpacity(0.1),
    trackHeight: 4,
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
  ),
  child: Slider(
    value: currentValue,
    min: 0,
    max: 100,
    onChanged: (val) => setState(() => currentValue = val),
  ),
)
```

### 11.17 Choice Chips / Filter Chips

For multi-select or filter options:

```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: options.map((option) {
    final isSelected = selectedOptions.contains(option);
    return ChoiceChip(
      label: Text(option.label),
      selected: isSelected,
      onSelected: (val) {
        HapticFeedback.lightImpact();
        onToggle(option, val);
      },
      selectedColor: const Color(0xFFCDAF56).withOpacity(0.2),
      backgroundColor: isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.02),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? const Color(0xFFCDAF56)
            : (isDark ? Colors.white54 : Colors.black54),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? const Color(0xFFCDAF56).withOpacity(0.5)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }).toList(),
)
```

### 11.18 Search Field

For inline search bars:

```dart
Container(
  decoration: BoxDecoration(
    color: isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: TextField(
    controller: _searchController,
    style: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    ),
    decoration: InputDecoration(
      hintText: 'Search...',
      hintStyle: TextStyle(
        color: isDark ? Colors.white24 : Colors.black26,
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        size: 20,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.close_rounded, size: 18,
                color: isDark ? Colors.white38 : Colors.black38),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            )
          : null,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  ),
)
```

### 11.19 Multi-Line Text Area (Notes / Description)

```dart
// Use the standard _buildTextField with maxLines: 3-5
_buildTextField(
  controller: _notesController,
  label: 'Notes',
  hint: 'Optional notes...',
  icon: Icons.notes_rounded,
  isDark: isDark,
  maxLines: 3,
)
```

### 11.20 Form Validation & Error Display

```dart
TextFormField(
  controller: controller,
  validator: (val) {
    if (val == null || val.isEmpty) return 'This field is required';
    return null;
  },
  style: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    color: isDark ? Colors.white : Colors.black87,
  ),
  decoration: InputDecoration(
    // ...same standard decoration...
    errorStyle: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Color(0xFFEF5350),
    ),
  ),
)
```

**Required field indicator:**

```dart
Row(
  children: [
    Text('AMOUNT', style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: isDark ? Colors.white38 : Colors.black38,
      letterSpacing: 1,
    )),
    const SizedBox(width: 4),
    const Text('*', style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Color(0xFFEF5350),
    )),
  ],
)
```

### 11.21 Save / Submit Button (Full Width)

Always at the bottom of forms:

```dart
SizedBox(
  width: double.infinity,
  height: 64,
  child: ElevatedButton(
    onPressed: _isSaving ? null : _save,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFCDAF56),
      disabledBackgroundColor: const Color(0xFFCDAF56).withOpacity(0.5),
      foregroundColor: const Color(0xFF1E1E1E),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    child: _isSaving
        ? const SizedBox(
            height: 24, width: 24,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 3,
            ),
          )
        : const Text(
            'SAVE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
  ),
)
```

**Key points:**
- Full width, 64px height
- Gold background, dark text
- Disabled state: 50% opacity gold
- Loading state: shows `CircularProgressIndicator` (black, 3px stroke)
- Text: uppercase, bold, letter-spacing
- Border radius: 20px (slightly rounder than cards)

### 11.22 Complete Form Page Structure

Put it all together:

```
Scaffold
├── AppBar (transparent, centered title)
└── Body
    └── SingleChildScrollView
        └── Padding (horizontal: 20)
            ├── SizedBox(height: 16)
            ├── Hero Amount Input (if financial)
            ├── SizedBox(height: 24)
            ├── Type Selector (if applicable)
            ├── SizedBox(height: 24)
            ├── Form Group Card 1
            │   ├── Section Label (gold)
            │   ├── Dropdown / Text Field
            │   └── Dropdown / Text Field
            ├── SizedBox(height: 20)
            ├── Form Group Card 2 (Date & Time)
            │   ├── Section Label
            │   └── Row [Date Tile, Time Tile]
            ├── SizedBox(height: 20)
            ├── Form Group Card 3 (Additional)
            │   ├── Section Label
            │   ├── Notes TextField
            │   └── Switch Toggle
            ├── SizedBox(height: 32)
            ├── Save Button (full width)
            └── SizedBox(height: 32)
```

---

## 12. DIALOGS & BOTTOM SHEETS

### 12.1 Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        // Content...
      ],
    ),
  ),
)
```

### 12.2 Alert Dialog

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    backgroundColor: isDark ? const Color(0xFF2D3139) : Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text('Confirm Delete', style: TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontWeight: FontWeight.w600,
    )),
    content: Text('Are you sure?', style: TextStyle(
      color: isDark ? Colors.white70 : Colors.black54,
    )),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel', style: TextStyle(
          color: isDark ? Colors.white54 : Colors.black45,
        )),
      ),
      ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEF5350),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Delete'),
      ),
    ],
  ),
)
```

---

## 13. CHARTS & DATA VISUALIZATION

### 13.1 Chart Colors

Use a muted palette that works on both themes:

```dart
static const chartColors = [
  Color(0xFFCDAF56),  // Gold (primary)
  Color(0xFF4CAF50),  // Green
  Color(0xFF2196F3),  // Blue
  Color(0xFFFF7043),  // Orange
  Color(0xFF9C27B0),  // Purple
  Color(0xFF00BCD4),  // Cyan
  Color(0xFFE91E63),  // Pink
  Color(0xFF8BC34A),  // Light green
];
```

### 13.2 Chart Container

```dart
Container(
  height: 200,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: isDark ? null : [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: chart,
)
```

---

## 14. ANIMATIONS & TRANSITIONS

### 14.1 Rules

- Keep all animations **under 300ms**
- Use `Curves.easeInOut` for most transitions
- Never animate on every frame — only on state changes
- Prefer `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSize` over manual controllers
- For page transitions, use `MaterialPageRoute` (default) or `CupertinoPageRoute`

### 14.2 Standard Durations

| Type | Duration | Curve |
|------|----------|-------|
| Expand / collapse | 200ms | `Curves.easeInOut` |
| Fade in | 150ms | `Curves.easeIn` |
| Slide transition | 250ms | `Curves.easeInOut` |
| Button press feedback | 100ms | `Curves.easeOut` |

### 14.3 Haptic Feedback

Use for important interactions:

```dart
HapticFeedback.lightImpact();   // Tap, select
HapticFeedback.mediumImpact();  // Confirm, submit
HapticFeedback.heavyImpact();   // Delete, destructive
```

---

## 15. PERFORMANCE RULES

### 15.1 Color Performance

**CRITICAL: Never use `withOpacity()` in `build()` on hot paths.**

```dart
// BAD — creates new Color object every build
color: Colors.black.withOpacity(0.04)

// GOOD — pre-computed constant
color: AppColors.blackOpacity005
```

For commonly used opacity values, add them to `AppColors`:

```dart
// In app_colors.dart:
static const Color whiteOpacity004 = Color(0x0AFFFFFF);  // 4%
static const Color whiteOpacity006 = Color(0x0FFFFFFF);  // 6%
static const Color blackOpacity004 = Color(0x0A000000);   // 4%
```

### 15.2 Widget Performance

```dart
// ALWAYS use const constructors
const SizedBox(height: 16),
const EdgeInsets.all(16),
const BorderRadius.all(Radius.circular(16)),

// Use const widgets
const Icon(Icons.add, size: 20),

// Use keys for list items
ListView.builder(
  itemBuilder: (ctx, i) => TransactionItem(key: ValueKey(items[i].id), ...),
)
```

### 15.3 Build Method Rules

```dart
// NEVER do heavy work in build()
// BAD:
Widget build(BuildContext context) {
  final sorted = items.toList()..sort();  // Sorting every build!
  return ListView(...);
}

// GOOD:
// Sort in provider/service, not in build
Widget build(BuildContext context) {
  final sorted = ref.watch(sortedItemsProvider);
  return ListView.builder(...);
}
```

### 15.4 Image & Asset Performance

- Use `const` for asset references
- Prefer SVG for icons over PNG
- Cache network images with `cached_network_image`
- Set explicit `width`/`height` on all images

### 15.5 List Performance

```dart
// For long lists (50+ items), ALWAYS use ListView.builder
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => buildItem(items[index]),
)

// NEVER use Column with many children for scrollable content
// BAD:
SingleChildScrollView(
  child: Column(children: items.map(buildItem).toList()),
)
```

---

## 16. ANTI-PATTERNS (NEVER DO THIS)

### Colors
- **NEVER** use hard-coded hex colors in UI files (use `AppColors` or `AppColorSchemes`)
- **NEVER** use purple in dark mode
- **NEVER** use `Colors.grey` directly — use specific opacity tokens
- **NEVER** use random accent colors — only gold for emphasis
- **NEVER** use heavy gradients on cards — use flat color + shadow

### Layout
- **NEVER** use `Expanded` inside `SingleChildScrollView`
- **NEVER** nest `ListView` inside `ListView` without `shrinkWrap: true` + `NeverScrollableScrollPhysics()`
- **NEVER** skip `overflow: TextOverflow.ellipsis` on dynamic text
- **NEVER** use fixed heights for text containers (text scales with accessibility)

### Performance
- **NEVER** call `withOpacity()` in `build()` on hot rebuild paths
- **NEVER** sort, filter, or compute in `build()` — use providers
- **NEVER** use `Column` for long lists — use `ListView.builder`
- **NEVER** load large assets synchronously

### Theme
- **NEVER** forget to handle both themes — every widget must check `isDark`
- **NEVER** use `Theme.of(context).colorScheme.background` — it may not match our custom background
- **NEVER** hard-code light or dark colors without the `isDark` check

### UX
- **NEVER** leave empty states without a message and icon
- **NEVER** allow user actions without feedback (haptic, visual, or snackbar)
- **NEVER** use more than one gold button per screen section

---

## 17. QUICK REFERENCE CHEAT SHEET

### Copy-Paste Patterns

**Theme check:**
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
```

**Standard card:**
```dart
decoration: BoxDecoration(
  color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: isDark ? null : [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ],
)
```

**Page scaffold:**
```dart
backgroundColor: isDark ? Colors.transparent : const Color(0xFFF5F5F7),
body: isDark ? DarkGradient.wrap(child: content) : content,
```

**Primary text:**
```dart
color: isDark ? Colors.white : Colors.black87,
```

**Secondary text:**
```dart
color: isDark ? Colors.white54 : Colors.black45,
```

**Tertiary text:**
```dart
color: isDark ? Colors.white38 : Colors.black38,
```

**Divider:**
```dart
color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
```

**Gold accent:**
```dart
color: const Color(0xFFCDAF56),
```

---

## FILE REFERENCE

| File | Purpose |
|------|---------|
| `lib/core/theme/color_schemes.dart` | Material 3 color schemes (light + dark) |
| `lib/core/theme/app_theme.dart` | ThemeData configuration |
| `lib/core/theme/widgets_theme.dart` | Component theme overrides |
| `lib/core/theme/typography.dart` | Text style definitions |
| `lib/core/theme/dark_gradient.dart` | Dark mode gradient background |
| `lib/core/constants/app_colors.dart` | Pre-computed color constants |
| `lib/features/finance/presentation/screens/finances_screen.dart` | **Reference implementation** |

---

> **When transforming any page, open this guide first. Follow the patterns exactly.
> The Finance Dashboard is the gold standard — match its quality on every screen.**
