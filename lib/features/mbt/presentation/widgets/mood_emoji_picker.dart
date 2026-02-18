import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/mood_emoji_options.dart';

/// Sentinel meaning "user explicitly chose no emoji" (clear selection).
const int kEmojiClearSentinel = -1;

/// Shows the full emoji picker in a bottom sheet. Lazy-loaded for performance.
/// Returns: selected code point (>0), [kEmojiClearSentinel] for "No emoji", null if dismissed.
Future<int?> showMoodEmojiPicker(
  BuildContext context, {
  required bool isDark,
  int? selectedCodePoint,
}) async {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MoodEmojiPickerSheet(
      isDark: isDark,
      selectedCodePoint: selectedCodePoint,
    ),
  );
}

class _MoodEmojiPickerSheet extends StatefulWidget {
  const _MoodEmojiPickerSheet({
    required this.isDark,
    this.selectedCodePoint,
  });

  final bool isDark;
  final int? selectedCodePoint;

  @override
  State<_MoodEmojiPickerSheet> createState() => _MoodEmojiPickerSheetState();
}

class _MoodEmojiPickerSheetState extends State<_MoodEmojiPickerSheet> {
  late final TextEditingController _dummyController;

  @override
  void initState() {
    super.initState();
    _dummyController = TextEditingController();
  }

  @override
  void dispose() {
    _dummyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF2D3139) : const Color(0xFFF2F2F2);
    final cardColor = isDark ? const Color(0xFF3E4148) : Colors.white;
    final accentColor = const Color(0xFFCDAF56);

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: Column(
        children: [
          // Header: title + done button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose Emoji',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(kEmojiClearSentinel),
                  child: Text(
                    'No emoji',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(widget.selectedCodePoint),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          // Emoji picker - RepaintBoundary for performance
          Expanded(
            child: RepaintBoundary(
              child: EmojiPicker(
                textEditingController: _dummyController,
                onEmojiSelected: (category, emoji) {
                  HapticFeedback.lightImpact();
                  final codePoint = emojiStringToCodePoint(emoji.emoji);
                  if (codePoint != null) {
                    Navigator.of(context).pop(codePoint);
                  }
                },
                onBackspacePressed: null,
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  locale: const Locale('en'),
                  emojiSet: (_) => emojiSetEnglish,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    backgroundColor: bgColor,
                    recentsLimit: 14,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: bgColor,
                    indicatorColor: accentColor,
                    iconColor: isDark ? Colors.white54 : Colors.black54,
                    iconColorSelected: accentColor,
                    initCategory: Category.SMILEYS,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    showBackspaceButton: false,
                    showSearchViewButton: true,
                    backgroundColor: cardColor,
                    buttonIconColor: accentColor,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: cardColor,
                    buttonIconColor: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
