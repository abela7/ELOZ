/// Curated emoji code points for mood picker. Stored as Unicode code points
/// for portability (visible on any device, survives backup/restore).
///
/// Order: positive → neutral → negative.
const List<int> moodEmojiCodePoints = [
  // Happy, joyful
  0x1F600, 0x1F603, 0x1F604, 0x1F601, 0x1F606,
  0x1F60A, 0x1F60B, 0x1F60D, 0x1F970, 0x1F618,
  0x1F929, 0x1F973, 0x1F60E, 0x1F92A, 0x1F60C,
  // Neutral, thinking
  0x1F62C, 0x1F914, 0x1F928, 0x1F610, 0x1F611,
  0x1F641, 0x1F636, 0x1F615, 0x1F61E, 0x1F61F,
  // Sad, worried, tired
  0x1F625, 0x1F622, 0x1F62D, 0x1F623, 0x1F624,
  0x1F621, 0x1F620, 0x1F92C, 0x1F47F, 0x1F631,
  0x1F92F, 0x1F4A5, 0x1F92B, 0x1F632, 0x1F633,
];

/// Converts code point to display string. Handles invalid values safely.
/// Supports supplementary plane (U+10000..U+10FFFF) via surrogate pairs;
/// [String.fromCharCode] alone only handles BMP (≤U+FFFF) and breaks emojis.
String emojiFromCodePoint(int codePoint) {
  if (codePoint <= 0 || codePoint > 0x10FFFF) return '';
  if (codePoint <= 0xFFFF) return String.fromCharCode(codePoint);
  final high = 0xD800 + ((codePoint - 0x10000) >> 10);
  final low = 0xDC00 + ((codePoint - 0x10000) & 0x3FF);
  return String.fromCharCodes([high, low]);
}

/// Extracts primary Unicode code point from emoji string (e.g. from picker).
/// Multi-codepoint emojis (skin tone, ZWJ) use the base/first rune for storage.
int? emojiStringToCodePoint(String emoji) {
  if (emoji.isEmpty) return null;
  final runes = emoji.runes;
  if (runes.isEmpty) return null;
  final first = runes.first;
  if (first <= 0 || first > 0x10FFFF) return null;
  return first;
}
