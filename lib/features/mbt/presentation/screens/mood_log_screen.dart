import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/dark_gradient.dart';
import '../../data/models/mood.dart';
import '../../data/models/mood_entry.dart';
import '../../data/models/mood_reason.dart';
import '../../data/services/mood_api_service.dart';
import '../../mbt_module.dart';
import 'mood_settings_screen.dart';

const _gold = Color(0xFFCDAF56);
const _darkSurface = Color(0xFF2D3139);
const _darkBorder = Color(0xFF3E4148);
const _lightBg = Color(0xFFF9F7F2);

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({
    super.key,
    required this.initialDate,
    this.entryId,
  });

  /// Date used when creating a new entry (ignored in edit mode).
  final DateTime initialDate;

  /// When set, opens in edit mode for this entry.
  final String? entryId;

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen>
    with TickerProviderStateMixin {
  final MoodApiService _api = MoodApiService();
  final TextEditingController _noteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _noteExpanded = false;
  String? _error;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  List<Mood> _moods = const <Mood>[];
  List<MoodReason> _reasons = const <MoodReason>[];
  MoodEntry? _existingEntry;
  String? _selectedMoodId;
  final Set<String> _selectedReasonIds = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  Map<String, Mood> get _moodById =>
      {for (final mood in _moods) mood.id: mood};

  /// Moods ordered from highest points (good) to lowest (bad).
  List<Mood> get _sortedMoods {
    final list = List<Mood>.from(_moods);
    list.sort((a, b) => b.pointValue.compareTo(a.pointValue));
    return list;
  }

  Mood? get _selectedMood =>
      _selectedMoodId == null ? null : _moodById[_selectedMoodId!];

  List<MoodReason> get _filteredReasons {
    final mood = _selectedMood;
    if (mood == null) return const [];
    return _reasons
        .where((r) => r.type == mood.polarity && r.isActive && !r.isDeleted)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    unawaited(_initialize());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await MbtModule.init(preOpenBoxes: true);
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final moods = await _api.getMoods();
      final reasons = await _api.getReasons();

      MoodEntry? entry;
      if (widget.entryId != null) {
        entry = await _api.getMoodEntryById(widget.entryId!);
      }

      String? selectedMoodId = entry?.moodId;
      if (selectedMoodId == null ||
          !moods.any((m) => m.id == selectedMoodId)) {
        selectedMoodId = null;
      }

      // Restore multi-reason selection, keeping only still-valid IDs.
      final mood = selectedMoodId == null
          ? null
          : moods.firstWhere((m) => m.id == selectedMoodId);
      final validReasonIds = entry?.reasonIds
              .where((id) =>
                  reasons.any((r) => r.id == id && r.type == mood?.polarity))
              .toSet() ??
          <String>{};

      if (!mounted) return;
      setState(() {
        _moods = moods;
        _reasons = reasons;
        _existingEntry = entry;
        _selectedMoodId = selectedMoodId;
        _selectedReasonIds
          ..clear()
          ..addAll(validReasonIds);
        _noteController.text = entry?.customNote ?? '';
        _noteExpanded = (entry?.customNote ?? '').trim().isNotEmpty;
        if (entry != null) {
          _selectedDate = DateTime(
            entry.loggedAt.year,
            entry.loggedAt.month,
            entry.loggedAt.day,
          );
          _selectedTime = TimeOfDay(
            hour: entry.loggedAt.hour,
            minute: entry.loggedAt.minute,
          );
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  DateTime _buildLoggedAt() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _save() async {
    final moodId = _selectedMoodId;
    final mood = _selectedMood;
    if (moodId == null || mood == null) {
      _snack('Select a mood to continue.');
      return;
    }
    if (mood.reasonRequired && _selectedReasonIds.isEmpty) {
      _snack('This mood requires at least one reason.');
      return;
    }
    setState(() => _saving = true);
    try {
      final loggedAt = _buildLoggedAt();
      if (_existingEntry != null) {
        await _api.updateMoodEntry(
          entryId: _existingEntry!.id,
          moodId: moodId,
          reasonIds: _selectedReasonIds.isEmpty
              ? null
              : _selectedReasonIds.toList(),
          customNote: _noteController.text,
          loggedAt: loggedAt,
        );
      } else {
        await _api.postMoodEntry(
          moodId: moodId,
          reasonIds: _selectedReasonIds.isEmpty
              ? null
              : _selectedReasonIds.toList(),
          customNote: _noteController.text,
          loggedAt: loggedAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _snack('Failed to save mood: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _goToSettings() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MoodSettingsScreen()),
    );
    if (changed == true && mounted) await _reload();
  }

  void _selectMood(Mood mood) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedMoodId = mood.id;
      // Remove any reasons that don't match the new polarity.
      _selectedReasonIds.removeWhere(
        (id) => !_reasons.any((r) => r.id == id && r.type == mood.polarity),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Scaffold(
      backgroundColor: isDark ? Colors.transparent : _lightBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _moods.isEmpty
              ? _emptyState(isDark)
              : _mainContent(isDark),
    );
    return Scaffold(
      body: isDark ? DarkGradient.wrap(child: content) : content,
    );
  }

  // =====================================================================
  // EMPTY STATE
  // =====================================================================

  Widget _emptyState(bool isDark) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('😶', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No moods created yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Head to settings to create your first mood.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white54 : Colors.black45,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _goToSettings,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create Moods'),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF1E1E1E),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // MAIN CONTENT
  // =====================================================================

  Widget _mainContent(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ---- App bar ----
          _appBar(isDark),

          // ---- Scrollable content ----
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 80,
              ),
              children: [
                const SizedBox(height: 4),

                // Hero question
                _heroQuestion(isDark),

                // Hero emoji
                const SizedBox(height: 16),
                _heroEmoji(isDark),

                // Mood selector
                const SizedBox(height: 20),
                _moodSelector(isDark),

                // Reason + Journal panel
                const SizedBox(height: 24),
                _detailsPanel(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // APP BAR
  // =====================================================================

  Widget _appBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 24,
                color: isDark ? Colors.white70 : const Color(0xFF1E1E1E)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          // Date chip
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() => _selectedDate =
                    DateTime(picked.year, picked.month, picked.day));
                if (widget.entryId != null) unawaited(_reload());
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14,
                      color: isDark ? _gold : const Color(0xFF6E6E6E)),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEE, MMM d').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Time chip
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: _gold,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && mounted) {
                setState(() => _selectedTime = picked);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14,
                      color: isDark ? _gold : const Color(0xFF6E6E6E)),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_selectedTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                size: 22, color: isDark ? Colors.white38 : Colors.black38),
            onPressed: _goToSettings,
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // HERO QUESTION
  // =====================================================================

  Widget _heroQuestion(bool isDark) {
    final mood = _selectedMood;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        mood == null ? 'How are you feeling?' : mood.name,
        key: ValueKey(mood?.id ?? '__none__'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: mood == null ? 26 : 28,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          letterSpacing: -0.8,
        ),
      ),
    );
  }

  // =====================================================================
  // HERO EMOJI — concentric rings + large emoji
  // =====================================================================

  Widget _heroEmoji(bool isDark) {
    final mood = _selectedMood;
    final moodColor = mood != null ? Color(mood.colorValue) : _gold;
    final hasEmoji = mood?.emojiCodePoint != null;

    final heroChild = mood == null
        ? Icon(Icons.add_reaction_outlined,
            size: 48,
            color: isDark ? Colors.white12 : Colors.black12)
        : hasEmoji
            ? Text(mood.emojiCharacter,
                style: const TextStyle(fontSize: 58))
            : Icon(mood.icon, size: 50, color: moodColor);

    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          final p = _pulseAnim.value;
          return SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                if (mood != null)
                  Transform.scale(
                    scale: p,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: moodColor.withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                // Middle ring
                if (mood != null)
                  Transform.scale(
                    scale: 1.0 + (p - 0.94) * 0.6,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: moodColor.withValues(alpha: 0.10),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                // Glow circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: mood != null
                        ? moodColor.withValues(alpha: isDark ? 0.14 : 0.08)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.02)),
                    boxShadow: mood != null
                        ? [
                            BoxShadow(
                              color: moodColor.withValues(alpha: 0.12),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: heroChild,
      ),
    );
  }

  // =====================================================================
  // MOOD SELECTOR — adaptive: wraps if <=5, scrolls if >5
  // =====================================================================

  Widget _moodSelector(bool isDark) {
    final sorted = _sortedMoods;
    if (sorted.length <= 5) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
              sorted.map((m) => _moodItem(isDark, m)).toList(),
        ),
      );
    }

    // Scrollable for 6+ moods — centers content and scrolls
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 20),
        itemBuilder: (_, i) => _moodItem(isDark, sorted[i]),
      ),
    );
  }

  Widget _moodItem(bool isDark, Mood mood) {
    final isSelected = _selectedMoodId == mood.id;
    final moodColor = Color(mood.colorValue);

    return GestureDetector(
      onTap: () => _selectMood(mood),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isSelected ? 52 : 44,
              height: isSelected ? 52 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? moodColor.withValues(alpha: isDark ? 0.20 : 0.10)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? moodColor
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: moodColor.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: mood.emojiCodePoint != null
                      ? Text(mood.emojiCharacter,
                          style: TextStyle(
                              fontSize: isSelected ? 24 : 20))
                      : Icon(mood.icon,
                          size: isSelected ? 24 : 20,
                          color: isSelected
                              ? moodColor
                              : (isDark
                                  ? Colors.white38
                                  : Colors.black38)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mood.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // DETAILS PANEL — reason + journal in a card
  // =====================================================================

  Widget _detailsPanel(bool isDark) {
    final mood = _selectedMood;
    final reasons = _filteredReasons;
    final reasonRequired = mood?.reasonRequired ?? false;
    final hasNote = _noteController.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: _darkBorder) : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Reason section ----
          if (_selectedMoodId != null && reasons.isNotEmpty) ...[
            _reasonSection(isDark, reasonRequired, reasons),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDark ? _darkBorder : Colors.black.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 20),
          ],

          if (_selectedMoodId != null &&
              reasonRequired &&
              reasons.isEmpty) ...[
            _reasonWarning(isDark),
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDark ? _darkBorder : Colors.black.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 20),
          ],

          // ---- Journal section ----
          _journalSection(isDark, hasNote),

          if (_error != null && _error!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600)),
          ],

          // ---- Save button inside card ----
          const SizedBox(height: 24),
          _saveButton(isDark),
        ],
      ),
    );
  }

  // =====================================================================
  // REASON — horizontal scrollable chips
  // =====================================================================

  Widget _reasonSection(
      bool isDark, bool required, List<MoodReason> reasons) {
    final selCount = _selectedReasonIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.question_mark_rounded,
                size: 18,
                color: isDark ? Colors.white30 : Colors.black26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'What made you feel this way?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                ),
              ),
            ),
            // Selection count badge
            if (selCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$selCount selected',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _gold,
                  ),
                ),
              )
            else if (required)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF5350),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select all that apply',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white30 : Colors.black38,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: reasons.map((r) => _reasonChip(isDark, r)).toList(),
        ),
      ],
    );
  }

  Widget _reasonChip(bool isDark, MoodReason reason) {
    final isSelected = _selectedReasonIds.contains(reason.id);
    final accent = Color(reason.colorValue);
    final hasIcon = reason.hasUserIcon;
    final hasEmoji = reason.emojiCharacter.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isSelected) {
            _selectedReasonIds.remove(reason.id);
          } else {
            _selectedReasonIds.add(reason.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF5F5F7)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: isSelected
                  ? Icon(Icons.check_box_rounded,
                      key: const ValueKey('check'), size: 16, color: accent)
                  : Icon(Icons.check_box_outline_blank_rounded,
                      key: const ValueKey('box'),
                      size: 16,
                      color: isDark ? Colors.white24 : Colors.black26),
            ),
            const SizedBox(width: 8),
            if (hasIcon)
              Icon(reason.icon, size: 16, color: accent)
            else if (hasEmoji)
              Text(reason.emojiCharacter, style: const TextStyle(fontSize: 16))
            else
              Icon(Icons.help_outline_rounded, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              reason.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                    : (isDark ? Colors.white54 : const Color(0xFF6E6E6E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonWarning(bool isDark) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEF5350).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFEF5350)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'This mood needs a reason. Add one in settings.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        TextButton(
          onPressed: _goToSettings,
          style: TextButton.styleFrom(
            foregroundColor: _gold,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Add',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  // =====================================================================
  // JOURNAL — tappable to expand, clean
  // =====================================================================

  Widget _journalSection(bool isDark, bool hasNote) {
    if (!_noteExpanded && !hasNote) {
      return GestureDetector(
        onTap: () => setState(() => _noteExpanded = true),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, size: 18, color: _gold),
            ),
            const SizedBox(width: 12),
            Text(
              'Add a note...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, size: 18, color: _gold),
            ),
            const SizedBox(width: 12),
            Text(
              'Note',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
            const Spacer(),
            if (!hasNote)
              GestureDetector(
                onTap: () => setState(() => _noteExpanded = false),
                child: Icon(Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white24 : Colors.black26),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          autofocus: !hasNote,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
          ),
          decoration: InputDecoration(
            hintText: 'What happened today?',
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF9F7F2),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _gold, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================================
  // SAVE BUTTON
  // =====================================================================

  Widget _saveButton(bool isDark) {
    final canSave = _selectedMoodId != null && !_saving;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedOpacity(
        opacity: _selectedMoodId != null ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 250),
        child: FilledButton(
          onPressed: canSave ? _save : null,
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: const Color(0xFF1E1E1E),
            disabledBackgroundColor: _gold.withValues(alpha: 0.25),
            disabledForegroundColor:
                const Color(0xFF1E1E1E).withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFF1E1E1E)),
                )
              : Text(
                  _existingEntry == null ? 'Save Mood' : 'Update Mood',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return t.period == DayPeriod.am ? '$h:$m AM' : '$h:$m PM';
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
