# LIFE MANAGER – OFFICIAL DESIGN SYSTEM RULES

## 🔑 1. Core Brand Colors

**Primary Accent (Gold)** – use only for important actions
`#CDAF56`

**Light Mode:**
- Soft Light Background: `#F9F7F2`
- Surface (Cards): `#FFFFFF`

**Dark Mode:**
- Background Gradient: `#2A2D3A` → `#212529` → `#1A1D23`
- Surface (Cards): `#2D3139` (Dark Gray)
- Bottom Nav: `#212529` (Charcoal)

### Color Palette:
**Light Mode:**
- Primary: `#CDAF56` (Gold)
- Primary Variant: `#E1C877`
- Background: `#F9F7F2`
- Surface: `#FFFFFF`
- Text Primary: `#1E1E1E`
- Text Secondary: `#6E6E6E`

**Dark Mode:**
- Primary: `#CDAF56` (Gold)
- Background Top: `#2A2D3A`
- Background Middle: `#212529`
- Background Bottom: `#1A1D23`
- Surface (Cards): `#2D3139`
- Border: `#3E4148`
- Text Primary: `#FFFFFF`
- Text Secondary: `#BDBDBD`

### 🚫 DARK MODE RULE:
**NO PURPLE COLORS IN DARK MODE!**
- Use dark gray (`#2D3139`) for all cards
- Use charcoal (`#212529`) for background elements
- Use gray borders (`#3E4148`)
- Only gold (`#CDAF56`) for accents

## 🧠 2. Design Philosophy

Cursor must follow these principles:

✔ Minimal & Modern — no clutter  
✔ Use spacious layouts (padding 16–24px between sections)  
✔ Light gradients → premium feel  
✔ Rounded corners → 16px or more  
✔ Use subtle shadows, not heavy ones  
✔ Buttons and icons use gold only when important  
✔ Cards feel floating (elevation + clean space around them)

## 📏 3. UI Spacing Rules

| Element | Padding/Margin |
|---------|----------------|
| Screen Edge | 20–24 px |
| Card Internal Padding | 16 px |
| Between Cards | 12–16 px |
| Button Internal Padding | 14 px vertical / 22 px horizontal |
| App Bar Height | 56 px |

## 🧾 4. Typography Rules

Use modern clean text. Do not use fancy or cursive fonts.

Example config:
- `headlineLarge` → 28-32px / Bold
- `titleMedium` → 18px / Medium
- `bodyMedium` → 15-16px / Regular
- `labelSmall` → 12px / Medium (buttons, tags)

Font suggestions:
- Inter
- Roboto
- Poppins (light use)

## 📦 5. Card Style Guide

```dart
CardTheme:
  color: #FFFFFF
  elevation: 3
  shape: RoundedRectangleBorder(16px)
  margin: EdgeInsets.all(16)
  padding: EdgeInsets.all(16)
```

## 🟨 6. Button Style

Primary buttons = gold only  
Secondary buttons = outline / subtle

```dart
ElevatedButtonTheme:
  backgroundColor: #CDAF56
  padding: EdgeInsets.symmetric(vertical:14, horizontal:22)
  shape: RoundedRectangleBorder(16px)
  textStyle: titleMedium
```

## ⬇️ 7. Bottom Navigation Rules

Background color = `#301934` (dark)  
Active icon = `#CDAF56`  
Inactive icons = `#C9C9C9`  
Label MUST be visible  
Rounded indicator under active tab = YES

Example Flutter config:
```dart
BottomNavigationBarThemeData(
  backgroundColor: Color(0xFF301934),
  selectedItemColor: Color(0xFFCDAF56),
  unselectedItemColor: Colors.grey,
  showUnselectedLabels: true,
  type: BottomNavigationBarType.fixed,
)
```

## 🧩 8. Layout Structure

Each mini-app follows this page structure:

```
Scaffold
 ├─ AppBar (title + icon)
 ├─ Body (cards, lists, charts)
 └─ BottomNavigationBar (shared across all apps)
```

## 💡 9. Screens Must Feel Like This

Think:

```
[Gradient Background]
    [Floating Card]
        Title
        Info
        GOLD BUTTON
```

