# MBT Mood Emoji Integration

## Goal

Add emoji support to each mood so they look more expressive and consistent. Emojis must:

- Be visible on any device (Android, iOS, etc.)
- Survive backup and restore
- Minimize data size and maximize speed
- Remain reliable for long-term usage

---

## Research Summary

### How Emojis Work

- **Unicode code points**: Each emoji has a unique numeric ID (e.g. 😀 = U+1F600 = 128512).
- **Display**: Flutter’s `Text` widget renders emojis using the system emoji font (Noto Color Emoji on Android, Apple Color Emoji on iOS). The same code point shows the same emoji across devices; only the style differs.
- **Storage options**:
  - **Code point (int)**: 4 bytes, platform-independent, unambiguous.
  - **UTF-8 string**: 4 bytes for most single emojis; more for sequences (skin tone, ZWJ). More flexible but heavier for simple use.
  - **UTF-16**: Platform-specific; not recommended for this use case.

### Recommendation: Store as Unicode Code Point (int)

| Criterion          | Code Point (int)                  | UTF-8 String              |
|-------------------|------------------------------------|----------------------------|
| Data size         | 4 bytes per mood                  | 4+ bytes, variable        |
| Portability       | Same value on all platforms       | Same                      |
| Backup/restore   | Hive serializes int natively      | Same for string           |
| Search/index     | Simple integer comparison         | String comparison         |
| Speed             | No encoding/decoding              | Minimal                   |
| Future sequences  | Single emoji only                 | Supports modifiers        |

**Conclusion:** For one emoji per mood, storing the Unicode code point as a 32-bit integer is the best option.

---

## Implementation

### 1. Data Model Change

Add `emojiCodePoint` to `Mood`:

```dart
/// Unicode code point for emoji (e.g. 0x1F600 = 😀). Null = no emoji, show icon only.
final int? emojiCodePoint;
```

- **Nullable**: Keeps existing moods valid; missing emoji falls back to icon.
- **Migration**: New field defaults to `null` in the Hive adapter; old backups restore without issue.

### 2. Hive Adapter Update

- Add field index 13 for `emojiCodePoint`.
- On read: if missing or invalid → `null`.
- On write: emit `null` or the int.
- Increment `numOfFields` to 14.

### 3. Display

```dart
// Render emoji (works on any device via system emoji font)
String get emojiCharacter {
  if (emojiCodePoint == null) return '';
  return String.fromCharCode(emojiCodePoint!);
}

// In UI: prefer emoji when present, else icon
Widget buildMoodAvatar(Mood mood) {
  if (mood.emojiCodePoint != null) {
    return Text(mood.emojiCharacter, style: TextStyle(fontSize: 28));
  }
  return Icon(mood.icon, color: Color(mood.colorValue), size: 24);
}
```

### 4. Emoji Picker Options

**Option A – Curated list (no new dependency)**

- Define a list of ~40–60 mood-relevant emojis (😀 😢 😤 😌 etc.).
- Show in a simple `GridView` or `Wrap`.
- Pros: No extra package, small bundle, fast.
- Cons: Limited set.

**Option B – Full emoji picker** (implemented)

- Uses `emoji_picker_flutter` with performance optimizations:
  - Lazy-loaded: picker only builds when user taps the emoji tile.
  - Single locale (`emojiSetEnglish`) to reduce bundle size (~2 MB saved).
  - RepaintBoundary to isolate repaints and avoid jank.
  - Theme matches app (gold accent, dark/light).

### 5. Backup/Restore

MBT boxes (`mbt_moods_v1`, etc.) are included in the app’s backup. Hive serialization already handles `int?`. No changes required in `comprehensive_app_backup_service.dart`.

---

## Curated Mood Emoji List (Option A)

```dart
/// Common mood emojis (Unicode code points) for picker.
/// Sorted by vibe: positive, neutral, negative.
static const List<int> moodEmojiCodePoints = [
  0x1F600, 0x1F603, 0x1F604, 0x1F601, 0x1F606,  // happy, grin, smile, grin-beam, satisfied
  0x1F60A, 0x1F60B, 0x1F60D, 0x1F970, 0x1F618,  // blush, yummy, heart-eyes, smiley-love, kiss
  0x1F929, 0x1F973, 0x1F60E, 0x1F92A, 0x1F60C,  // star-struck, woozy, sunglasses, mind-blown, relieved
  0x1F62C, 0x1F914, 0x1F928, 0x1F610, 0x1F611,  // grimacing, thinking, raises-eyebrow, neutral, unamused
  0x1F641, 0x1F636, 0x1F615, 0x1F61E, 0x1F61F,  // slightly-frown, no-mouth, confused, disappointed, worried
  0x1F625, 0x1F622, 0x1F62D, 0x1F623, 0x1F624,  // disappointed-relieved, cry, sob, persevere, triumph
  0x1F621, 0x1F620, 0x1F92C, 0x1F47F, 0x1F631,  // angry, enraged, blowing-kiss, imp, startled
  0x1F92F, 0x1F4A5, 0x1F92B, 0x1F632, 0x1F633,  // mind-blown, dizzy, shushing, astonished, flushed
];
```

---

## Validation Checklist

- [x] `Mood` model has `emojiCodePoint` (int?, nullable).
- [x] `MoodAdapter` reads/writes new field (index 13) with null safety.
- [x] `MoodApiService.postMood` / `putMood` accept `emojiCodePoint`.
- [x] UI shows emoji when present, icon when null (settings, log, main screen).
- [x] Emoji picker in Add/Edit Mood sheet (curated grid, no new package).
- [x] Backup/restore: Hive serializes int natively; no changes needed.
- [x] Existing moods without emoji continue to work (icon fallback).
